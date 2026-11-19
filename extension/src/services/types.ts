export interface ExtensionSettings {
  supabaseUrl: string;
  supabaseAnonKey: string;
  email: string;
  theme: 'system' | 'dark' | 'light';
  inboxPageTitle: string;
  showFloatingButton: boolean;
}

export type ClipMode = 'article' | 'selection' | 'bookmark' | 'screenshot';

export interface PageMetadata {
  url: string;
  title: string;
  faviconUrl?: string;
  description?: string;
  selectedText?: string;
  author?: string;
}

export interface ClipPayload {
  mode: ClipMode;
  url: string;
  title: string;
  comment?: string;
  tags?: string[];
  contentMarkdown?: string;
  targetPageId?: string; // null / empty means default Inbox
  screenshotDataUrl?: string;
}

export interface DraftFlowPage {
  id: string;
  title: string;
  parent_id: string | null;
  database_id?: string | null;
  icon: string | null;
  order_key: string;
  properties?: string | null;
  created_at: number;
  trashed_at: string | null;
}

export interface AppFlowyBlockData {
  type: string;
  data: Record<string, unknown>;
}

export interface DraftFlowBlock {
  id: string;
  page_id: string;
  parent_id: string | null;
  type: string;
  content: string; // JSON string of AppFlowyBlockData
  order_key: string;
  trashed_at: string | null;
  trash_batch_id: string | null;
}

export interface PendingSyncEvent {
  operation_id: string;
  device_id: string;
  entity_type: 'pages' | 'blocks' | 'databases' | 'database_columns';
  entity_id: string;
  action: 'UPSERT' | 'DELETE';
  payload: Record<string, unknown>;
  base_seq: number;
  seen_seq: number;
}
