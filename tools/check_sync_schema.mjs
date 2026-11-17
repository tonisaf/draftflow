import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

// Test-only dependency: npm install --prefix build/tmp/sql-validation --ignore-scripts @electric-sql/pglite@0.5.15
const modulePath = resolve(process.argv[2] ?? 'build/tmp/sql-validation/node_modules/@electric-sql/pglite/dist/index.js');
const { PGlite } = await import(pathToFileURL(modulePath).href);
const db = new PGlite();
let passed = 0;
async function check(name, test) { await test(); passed++; console.log(`PASS ${name}`); }
async function failure(action, code) {
  try { await action(); assert.fail(`Expected ${code}`); }
  catch (e) { assert.equal(e.code, code, e.message); }
}
const alice = 'aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb';
const bob = 'bbbbbbbb-1111-2222-3333-bbbbbbbbbbbb';
async function user(id, action) {
  await db.exec('SET ROLE authenticated');
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [id]);
  try { return await action(); } finally { await db.exec('RESET ROLE'); }
}
function page(id, title) {
  return { id, title, parent_id:null, icon:null, cover:null, order_key:'a', database_id:null,
    properties:null, created_at:1700000000, trashed_at:null, trash_batch_id:null };
}
function event(id, payload, base=0, seen=0, type='pages', action='UPSERT') {
  return { operation_id:id, entity_type:type, entity_id:payload.id, action, payload, base_seq:base, seen_seq:seen };
}
async function push(device, events) {
  await db.query('select public.notes_sync_push_v2($1,$2::jsonb)', [device,JSON.stringify(events)]);
}
async function rows() { return (await db.query('select * from public.notes_sync_events order by seq_id')).rows; }
try {
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth to authenticated;
    insert into auth.users values ('${alice}'),('${bob}');`);
  const sql = await readFile(resolve('supabase/notes_schema.sql'),'utf8');
  await db.exec(sql);
  await db.exec(sql); // Re-applying must preserve data and remain valid.
  const initial = event('alice-create',page('p','Initial'));
  let first, updated;
  await check('authenticated append and CAS update', async () => user(alice,async () => {
    await push('device-a',[initial]); first=(await rows())[0].seq_id;
    await push('device-a',[event('alice-update',page('p','Changed'),first,first)]);
    const log=await rows(); updated=log.at(-1).seq_id; assert.equal(log.at(-1).payload.title,'Changed');
  }));
  await check('retry is idempotent even after a later version',async () => user(alice,async () => {
    const before=(await rows()).length; await push('device-a',[initial]); assert.equal((await rows()).length,before);
  }));
  await check('immutable operation identity',async () => user(alice,async () => {
    await failure(()=>push('device-a',[event('alice-create',page('p','Different'))]),'22023');
  }));
  await check('stale writes rejected without losing the server version',async () => user(alice,async () => {
    await failure(()=>push('device-b',[event('stale',page('p','Stale'),first,first)]),'PT409');
    assert.equal((await rows()).at(-1).payload.title,'Changed');
  }));
  await check('conflicting batch rolls back every operation',async () => user(alice,async () => {
    const before=(await rows()).length;
    await failure(()=>push('device-a',[event('new-in-batch',page('q','Temporary')),event('bad-in-batch',page('p','Stale'),0)]),'PT409');
    assert.equal((await rows()).length,before);
  }));
  await check('RLS isolates users even when entity and operation IDs collide',async () => {
    await user(bob,async () => { assert.equal((await rows()).length,0); await push('device-bob',[initial]); assert.equal((await rows()).length,1); });
    await user(alice,async () => assert.equal((await rows()).length,2));
  });
  await check('direct writes are forbidden',async () => user(alice,async () => {
    await failure(()=>db.query("delete from public.notes_sync_events"),'42501');
  }));
  await check('anonymous RPC execution is forbidden',async () => {
    await db.exec('SET ROLE anon');
    try { await failure(()=>push('anon',[initial]),'42501'); } finally { await db.exec('RESET ROLE'); }
  });
  await check('delete versus unseen child edit is rejected; reviewed deletion succeeds',async () => user(alice,async () => {
    const block={id:'block',page_id:'p',parent_id:null,type:'paragraph',content:'{}',order_key:'a',trashed_at:null,trash_batch_id:null};
    await push('device-b',[event('child-edit',block,0,updated,'blocks')]);
    const child=(await rows()).at(-1).seq_id;
    await failure(()=>push('device-a',[event('delete-stale',page('p','Changed'),updated,updated,'pages','DELETE')]),'PT409');
    await push('device-a',[event('delete-reviewed',page('p','Changed'),updated,child,'pages','DELETE')]);
    const deleted=(await rows()).at(-1).seq_id;
    await failure(()=>push('device-b',[event('orphan-edit',block,child,deleted,'blocks')]),'PT409');
    // Cleanup children remains possible after parent deletion.
    await push('device-a',[event('child-delete',block,child,deleted,'blocks','DELETE')]);
  }));
  console.log(`${passed} PostgreSQL schema checks passed.`);
} finally { await db.close(); }
