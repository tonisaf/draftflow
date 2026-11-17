-- Apply to the SAME Supabase project as Tasks Here. Tasks tables/RPCs are untouched.
-- Protocol v2: idempotent operations, per-entity CAS, and structural delete guards.
begin;
create table if not exists public.notes_sync_events (
  seq_id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  operation_id text not null,
  device_id text not null,
  entity_type text not null check (entity_type in ('pages','blocks','databases','database_columns')),
  entity_id text not null,
  action text not null check (action in ('UPSERT','DELETE')),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  created_at timestamptz not null default now(),
  unique (user_id, operation_id)
);
create index if not exists notes_sync_events_user_seq on public.notes_sync_events(user_id, seq_id);
create index if not exists notes_sync_events_entity_seq on public.notes_sync_events(user_id, entity_type, entity_id, seq_id desc);
alter table public.notes_sync_events enable row level security;
drop policy if exists notes_read_own_events on public.notes_sync_events;
create policy notes_read_own_events on public.notes_sync_events
  for select to authenticated using (user_id = auth.uid());
revoke all on public.notes_sync_events from anon, authenticated;
grant select on public.notes_sync_events to authenticated;

create or replace function public.notes_sync_push_v2(p_device_id text, p_events jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  e jsonb;
  prior public.notes_sync_events%rowtype;
  latest public.notes_sync_events%rowtype;
  parent_type text;
  parent_id text;
  refs jsonb;
  ref jsonb;
  parent public.notes_sync_events%rowtype;
  seen bigint;
  base bigint;
  expected text[];
begin
  if uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_device_id is null or length(p_device_id) not between 1 and 128 then
    raise exception 'Invalid device ID' using errcode = '22023';
  end if;
  if p_events is null or jsonb_typeof(p_events) <> 'array' then
    raise exception 'Expected event array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_events) not between 1 and 100 or octet_length(p_events::text) > 4194304 then
    raise exception 'Invalid batch size' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('notes-sync:' || uid::text, 0));
  for e in select value from jsonb_array_elements(p_events) loop
    if jsonb_typeof(e) <> 'object'
      or coalesce(length(e->>'operation_id'),0) not between 1 and 128
      or coalesce(length(e->>'entity_id'),0) not between 1 and 128
      or coalesce(e->>'entity_type','') not in ('pages','blocks','databases','database_columns')
      or coalesce(e->>'action','') not in ('UPSERT','DELETE')
      or jsonb_typeof(e->'payload') is distinct from 'object'
      or (e->'payload'->>'id') is distinct from (e->>'entity_id')
      or coalesce(e->>'base_seq','') !~ '^[0-9]{1,18}$'
      or coalesce(e->>'seen_seq','') !~ '^[0-9]{1,18}$' then
      raise exception 'Invalid event' using errcode = '22023';
    end if;
    expected := case e->>'entity_type'
      when 'pages' then array['id','title','parent_id','icon','cover','order_key','database_id','properties','created_at','trashed_at','trash_batch_id']
      when 'blocks' then array['id','page_id','parent_id','type','content','order_key','trashed_at','trash_batch_id']
      when 'databases' then array['id','title','icon','parent_page_id','created_at','trashed_at','trash_batch_id']
      when 'database_columns' then array['id','database_id','name','type','options','width','order_key','created_at']
    end;
    if not (e->'payload' ?& expected) or
      (select count(*) from jsonb_object_keys(e->'payload')) <> cardinality(expected) then
      raise exception 'Invalid payload shape' using errcode='22023';
    end if;
    base := (e->>'base_seq')::bigint;
    seen := (e->>'seen_seq')::bigint;
    if seen > coalesce((select max(seq_id) from public.notes_sync_events where user_id=uid),0) then
      raise exception 'Invalid cursor' using errcode='22023';
    end if;
    select * into prior from public.notes_sync_events
      where user_id=uid and operation_id=e->>'operation_id';
    if found then
      if prior.device_id <> p_device_id or prior.entity_type <> e->>'entity_type'
        or prior.entity_id <> e->>'entity_id' or prior.action <> e->>'action'
        or prior.payload <> e->'payload' then
        raise exception 'Operation ID reused' using errcode = '22023';
      end if;
      continue;
    end if;
    select * into latest from public.notes_sync_events
      where user_id=uid and entity_type=e->>'entity_type' and entity_id=e->>'entity_id'
      order by seq_id desc limit 1;
    if coalesce(latest.seq_id,0) <> base then
      raise exception 'notes_sync_conflict' using errcode='PT409',
        detail=jsonb_build_object('entity_type',e->>'entity_type','entity_id',e->>'entity_id')::text;
    end if;
    if e->>'action'='UPSERT' then
      refs := '[]'::jsonb;
      case e->>'entity_type'
        when 'pages' then refs := jsonb_build_array(
          jsonb_build_array('pages',e->'payload'->>'parent_id'),
          jsonb_build_array('databases',e->'payload'->>'database_id'));
        when 'blocks' then refs := jsonb_build_array(
          jsonb_build_array('pages',e->'payload'->>'page_id'),
          jsonb_build_array('blocks',e->'payload'->>'parent_id'));
        when 'databases' then refs := jsonb_build_array(jsonb_build_array('pages',e->'payload'->>'parent_page_id'));
        when 'database_columns' then refs := jsonb_build_array(jsonb_build_array('databases',e->'payload'->>'database_id'));
        else null;
      end case;
      for ref in select value from jsonb_array_elements(refs) loop
        parent_type := ref->>0; parent_id := ref->>1;
        if parent_id is null then continue; end if;
        select * into parent from public.notes_sync_events
          where user_id=uid and entity_type=parent_type and entity_id=parent_id order by seq_id desc limit 1;
        if parent.seq_id is null or parent.action='DELETE' then
          raise exception 'notes_sync_parent_deleted' using errcode='PT409',
            detail=jsonb_build_object('entity_type',e->>'entity_type','entity_id',e->>'entity_id')::text;
        end if;
      end loop;
    end if;
    -- Reject deletion if another device changed any owned descendant since the
    -- deleting device last read the journal. CTE uses UNION to terminate cycles.
    if e->>'action'='DELETE' and e->>'entity_type' in ('pages','databases','blocks') then
      if exists (
        with recursive heads as (
          select distinct on (entity_type,entity_id) * from public.notes_sync_events
          where user_id=uid order by entity_type,entity_id,seq_id desc
        ), owned(kind,id) as (
          select e->>'entity_type', e->>'entity_id'
          union
          select h.entity_type,h.entity_id from heads h join owned o on
            (o.kind='pages' and ((h.entity_type='pages' and h.payload->>'parent_id'=o.id)
              or (h.entity_type='blocks' and h.payload->>'page_id'=o.id)
              or (h.entity_type='databases' and h.payload->>'parent_page_id'=o.id)))
            or (o.kind='databases' and ((h.entity_type='pages' and h.payload->>'database_id'=o.id)
              or (h.entity_type='database_columns' and h.payload->>'database_id'=o.id)))
            or (o.kind='blocks' and h.entity_type='blocks' and h.payload->>'parent_id'=o.id)
        ) select 1 from heads h join owned o on h.entity_type=o.kind and h.entity_id=o.id
          where h.action='UPSERT' and h.seq_id>seen and h.device_id<>p_device_id
          and not (h.entity_type=e->>'entity_type' and h.entity_id=e->>'entity_id')
      ) then
        raise exception 'notes_sync_delete_conflict' using errcode='PT409',
          detail=jsonb_build_object('entity_type',e->>'entity_type','entity_id',e->>'entity_id')::text;
      end if;
    end if;
    insert into public.notes_sync_events
      (user_id,operation_id,device_id,entity_type,entity_id,action,payload)
    values (uid,e->>'operation_id',p_device_id,e->>'entity_type',e->>'entity_id',e->>'action',e->'payload');
  end loop;
end $$;
revoke all on function public.notes_sync_push_v2(text,jsonb) from public, anon;
grant execute on function public.notes_sync_push_v2(text,jsonb) to authenticated;
-- Retire v1 if an earlier foundation script was applied: it bypasses CAS.
do $$ begin
  if to_regprocedure('public.notes_sync_push(text,jsonb)') is not null then
    execute 'revoke all on function public.notes_sync_push(text,jsonb) from public, anon, authenticated';
  end if;
end $$;
notify pgrst, 'reload schema';
commit;
