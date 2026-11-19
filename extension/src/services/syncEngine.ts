import { getSupabaseClient, getSession } from './supabase';
import { DraftFlowPage, DraftFlowBlock, PendingSyncEvent } from './types';
import { generateUuid, makeOrderKey } from './blockEncoder';
import { getCachedPages, setCachedPages, getSettings } from '../storage/draftStore';

const DEVICE_ID = 'draftflow-chrome-extension';

export async function fetchRemotePages(): Promise<DraftFlowPage[]> {
  const client = await getSupabaseClient();
  const session = await getSession();
  if (!client || !session) {
    return getCachedPages();
  }

  try {
    // Pull events for pages from notes_sync_events
    const { data, error } = await client
      .from('notes_sync_events')
      .select('seq_id, entity_id, action, payload')
      .eq('entity_type', 'pages')
      .order('seq_id', { ascending: true });

    if (error || !data) {
      console.warn('Failed to query notes_sync_events for pages:', error);
      return getCachedPages();
    }

    // Materialize latest state of each page (filter out deleted, trashed, or database rows like movies)
    const pageMap = new Map<string, DraftFlowPage>();
    for (const row of data) {
      const payload = row.payload as Record<string, unknown>;
      if (row.action === 'DELETE' || payload.trashed_at || payload.database_id) {
        pageMap.delete(row.entity_id);
      } else {
        pageMap.set(row.entity_id, {
          id: payload.id as string,
          title: (payload.title as string) || 'Untitled',
          parent_id: (payload.parent_id as string) || null,
          icon: (payload.icon as string) || null,
          order_key: (payload.order_key as string) || 'a0',
          created_at:
            typeof payload.created_at === 'number'
              ? payload.created_at
              : Math.floor(Date.now() / 1000),
          trashed_at: null,
        });
      }
    }

    const pages = Array.from(pageMap.values());
    await setCachedPages(pages);
    return pages;
  } catch (err) {
    console.error('Error fetching remote pages:', err);
    return getCachedPages();
  }
}

/**
 * Finds or creates the default "Inbox / Web Clips" page
 */
export async function getOrCreateInboxPage(pages: DraftFlowPage[]): Promise<DraftFlowPage> {
  const settings = await getSettings();
  const targetTitle = settings.inboxPageTitle || 'Входящие / Web Clips';

  const existing = pages.find((p) => p.title.toLowerCase() === targetTitle.toLowerCase());
  if (existing) {
    return existing;
  }

  // Create new Inbox page
  const newInbox: DraftFlowPage = {
    id: generateUuid(),
    title: targetTitle,
    parent_id: null,
    icon: '📥',
    order_key: 'a0',
    created_at: Math.floor(Date.now() / 1000),
    trashed_at: null,
  };

  await saveNewPageWithBlocks(newInbox, []);
  return newInbox;
}

export function makeInboxProperties(params: {
  type: 'article' | 'link' | 'quote' | 'screenshot' | 'note';
  url?: string;
  domain?: string;
  faviconUrl?: string;
  previewImageUrl?: string;
  excerpt?: string;
  author?: string;
}): string {
  let domain = params.domain;
  if (!domain && params.url) {
    try {
      domain = new URL(params.url).hostname.replace(/^www\./, '');
    } catch (_) {}
  }

  return JSON.stringify({
    _draftflow_inbox_item: {
      isInboxItem: true,
      type: params.type,
      url: params.url || null,
      domain: domain || null,
      faviconUrl: params.faviconUrl || null,
      previewImageUrl: params.previewImageUrl || null,
      excerpt: params.excerpt || null,
      author: params.author || null,
      isArchived: false,
      savedAt: new Date().toISOString(),
    },
  });
}

/**
 * Pushes a new page and its blocks atomically to Supabase via notes_sync_push_v2
 */
export async function saveNewPageWithBlocks(
  page: DraftFlowPage,
  blocks: DraftFlowBlock[]
): Promise<boolean> {
  const client = await getSupabaseClient();
  const session = await getSession();
  if (!client || !session) {
    throw new Error('Необходимо настроить подключение к Supabase и войти в аккаунт');
  }

  const events: PendingSyncEvent[] = [];

  // 1. Page event (Strict payload matching notes_schema.sql and Drift types)
  events.push({
    operation_id: generateUuid(),
    device_id: DEVICE_ID,
    entity_type: 'pages',
    entity_id: page.id,
    action: 'UPSERT',
    payload: {
      id: page.id,
      title: page.title,
      parent_id: page.parent_id,
      icon: page.icon,
      cover: null,
      order_key: page.order_key || 'a0',
      database_id: null,
      properties: page.properties || null,
      created_at:
        typeof page.created_at === 'number'
          ? page.created_at
          : Math.floor(Date.now() / 1000),
      trashed_at: null,
      trash_batch_id: null,
    },
    base_seq: 0,
    seen_seq: 0,
  });

  // 2. Block events (Strict payload matching notes_schema.sql)
  for (let i = 0; i < blocks.length; i++) {
    const block = blocks[i];
    events.push({
      operation_id: generateUuid(),
      device_id: DEVICE_ID,
      entity_type: 'blocks',
      entity_id: block.id,
      action: 'UPSERT',
      payload: {
        id: block.id,
        page_id: page.id,
        parent_id: block.parent_id,
        type: block.type,
        content: block.content,
        order_key: block.order_key || makeOrderKey(i),
        trashed_at: null,
        trash_batch_id: null,
      },
      base_seq: 0,
      seen_seq: 0,
    });
  }

  if (events.length === 0) {
    return true;
  }

  // 3. Push events in batches of at most 50 (notes_schema.sql limits batch to 1..100)
  const BATCH_SIZE = 50;
  for (let i = 0; i < events.length; i += BATCH_SIZE) {
    const batch = events.slice(i, i + BATCH_SIZE);
    const { error } = await client.rpc('notes_sync_push_v2', {
      p_device_id: DEVICE_ID,
      p_events: batch,
    });

    if (error) {
      console.error('notes_sync_push_v2 error:', error);
      throw new Error(`Ошибка синхронизации: ${error.message}`);
    }
  }

  // Update cached pages list
  const currentCached = await getCachedPages();
  await setCachedPages([page, ...currentCached]);

  return true;
}
