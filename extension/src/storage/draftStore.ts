import { ExtensionSettings, DraftFlowPage } from '../services/types';

const SETTINGS_KEY = 'draftflow_settings';
const SCRATCHPAD_DRAFT_KEY = 'draftflow_scratchpad_draft';
const PAGES_CACHE_KEY = 'draftflow_pages_cache';

export const DEFAULT_SETTINGS: ExtensionSettings = {
  supabaseUrl: '',
  supabaseAnonKey: '',
  email: '',
  theme: 'system',
  inboxPageTitle: 'Входящие / Web Clips',
  showFloatingButton: true,
};

export async function getSettings(): Promise<ExtensionSettings> {
  const result = await chrome.storage.local.get([SETTINGS_KEY]);
  return { ...DEFAULT_SETTINGS, ...(result[SETTINGS_KEY] || {}) };
}

export async function saveSettings(settings: Partial<ExtensionSettings>): Promise<void> {
  const current = await getSettings();
  await chrome.storage.local.set({ [SETTINGS_KEY]: { ...current, ...settings } });
}

export async function getScratchpadDraft(): Promise<string> {
  const result = await chrome.storage.local.get([SCRATCHPAD_DRAFT_KEY]);
  return (result[SCRATCHPAD_DRAFT_KEY] as string) || '';
}

export async function saveScratchpadDraft(text: string): Promise<void> {
  await chrome.storage.local.set({ [SCRATCHPAD_DRAFT_KEY]: text });
}

export async function getCachedPages(): Promise<DraftFlowPage[]> {
  const result = await chrome.storage.local.get([PAGES_CACHE_KEY]);
  return (result[PAGES_CACHE_KEY] as DraftFlowPage[]) || [];
}

export async function setCachedPages(pages: DraftFlowPage[]): Promise<void> {
  await chrome.storage.local.set({ [PAGES_CACHE_KEY]: pages });
}

export function applyTheme(theme: 'system' | 'dark' | 'light'): void {
  const isDark =
    theme === 'dark' ||
    (theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);

  if (isDark) {
    document.documentElement.classList.add('dark');
  } else {
    document.documentElement.classList.remove('dark');
  }
}
