import { createClient, SupabaseClient, Session } from '@supabase/supabase-js';
import { getSettings } from '../storage/draftStore';

let cachedClient: SupabaseClient | null = null;
let lastUrl = '';
let lastKey = '';

export async function getSupabaseClient(): Promise<SupabaseClient | null> {
  const settings = await getSettings();
  const url = settings.supabaseUrl.trim();
  const key = settings.supabaseAnonKey.trim();

  if (!url || !key) {
    return null;
  }

  if (cachedClient && lastUrl === url && lastKey === key) {
    return cachedClient;
  }

  try {
    cachedClient = createClient(url, key, {
      auth: {
        persistSession: true,
        storage: {
          getItem: async (key: string) => {
            const res = await chrome.storage.local.get([key]);
            return (res[key] as string) || null;
          },
          setItem: async (key: string, value: string) => {
            await chrome.storage.local.set({ [key]: value });
          },
          removeItem: async (key: string) => {
            await chrome.storage.local.remove([key]);
          },
        },
      },
    });
    lastUrl = url;
    lastKey = key;
    return cachedClient;
  } catch (err) {
    console.error('Failed to create Supabase client:', err);
    return null;
  }
}

export async function getSession(): Promise<Session | null> {
  const client = await getSupabaseClient();
  if (!client) return null;
  const { data } = await client.auth.getSession();
  return data.session;
}

export async function uploadScreenshotToStorage(
  dataUrl: string,
  fileName: string
): Promise<string | null> {
  const client = await getSupabaseClient();
  if (!client) return null;

  try {
    // Convert base64 dataUrl to blob
    const res = await fetch(dataUrl);
    const blob = await res.blob();

    const path = `screenshots/${Date.now()}_${fileName}.webp`;
    const { data, error } = await client.storage
      .from('draftflow_media')
      .upload(path, blob, {
        contentType: 'image/webp',
        upsert: true,
      });

    if (error) {
      console.warn('Storage upload failed (bucket draftflow_media might not exist):', error);
      return null;
    }

    const { data: pubData } = client.storage.from('draftflow_media').getPublicUrl(path);
    return pubData.publicUrl;
  } catch (err) {
    console.error('Error uploading screenshot:', err);
    return null;
  }
}
