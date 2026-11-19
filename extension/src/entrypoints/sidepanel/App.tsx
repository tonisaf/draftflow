import React, { useState, useEffect, useMemo } from 'react';
import {
  Search,
  RefreshCw,
  Settings,
  ArrowLeft,
  Clock,
  Plus,
  Loader2,
  Copy,
  Check,
  Folder,
  FileText,
  X,
  ExternalLink,
} from 'lucide-react';
import { DraftFlowPage } from '@/services/types';
import { fetchRemotePages } from '@/services/syncEngine';
import { getSupabaseClient } from '@/services/supabase';
import BlockRenderer, { ParsedBlock } from '@/components/BlockRenderer';
import NewNoteModal from '@/components/NewNoteModal';

export default function App() {
  const [pages, setPages] = useState<DraftFlowPage[]>([]);
  const [search, setSearch] = useState('');
  const [activeFilter, setActiveFilter] = useState<'all' | 'inbox' | 'root'>('all');
  const [loading, setLoading] = useState(false);
  const [showNewModal, setShowNewModal] = useState(false);

  // Selected Page State
  const [selectedPage, setSelectedPage] = useState<DraftFlowPage | null>(null);
  const [blocks, setBlocks] = useState<ParsedBlock[]>([]);
  const [loadingContent, setLoadingContent] = useState(false);
  const [copiedMarkdown, setCopiedMarkdown] = useState(false);

  useEffect(() => {
    loadPages();
  }, []);

  async function loadPages() {
    setLoading(true);
    try {
      const data = await fetchRemotePages();
      setPages(data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }

  async function openPage(page: DraftFlowPage) {
    setSelectedPage(page);
    setLoadingContent(true);
    setBlocks([]);

    try {
      const client = await getSupabaseClient();
      if (!client) {
        setLoadingContent(false);
        return;
      }

      // Fetch blocks for this page
      const { data, error } = await client
        .from('notes_sync_events')
        .select('entity_id, action, payload')
        .eq('entity_type', 'blocks')
        .order('seq_id', { ascending: true });

      if (error || !data) {
        setLoadingContent(false);
        return;
      }

      const blocksMap = new Map<string, ParsedBlock>();
      for (const row of data) {
        const payload = row.payload as Record<string, unknown>;
        if (payload.page_id === page.id) {
          if (row.action === 'DELETE' || payload.trashed_at) {
            blocksMap.delete(row.entity_id);
          } else {
            let parsedData = {};
            try {
              const contentJson = JSON.parse(payload.content as string);
              parsedData = contentJson.data || {};
            } catch {}

            blocksMap.set(row.entity_id, {
              id: payload.id as string,
              type: payload.type as string,
              data: parsedData,
              order_key: (payload.order_key as string) || 'a0',
            });
          }
        }
      }

      const sorted = Array.from(blocksMap.values()).sort((a, b) =>
        a.order_key.localeCompare(b.order_key)
      );

      setBlocks(sorted);
    } catch (err) {
      console.error(err);
    } finally {
      setLoadingContent(false);
    }
  }

  function handleCopyPageMarkdown() {
    if (!selectedPage) return;

    const lines: string[] = [`# ${selectedPage.title}\n`];
    for (const b of blocks) {
      if (b.type === 'heading') {
        const level = b.data.level || 1;
        const text = b.data.delta?.map((d: any) => d.insert || '').join('') || '';
        lines.push(`${'#'.repeat(level)} ${text}`);
      } else if (b.type === 'quote') {
        const text = b.data.delta?.map((d: any) => d.insert || '').join('') || '';
        lines.push(`> ${text}`);
      } else if (b.type === 'code') {
        const text = b.data.delta?.map((d: any) => d.insert || '').join('') || '';
        lines.push(`\`\`\`${b.data.language || ''}\n${text}\n\`\`\``);
      } else if (b.type === 'bulleted_list') {
        const text = b.data.delta?.map((d: any) => d.insert || '').join('') || '';
        lines.push(`- ${text}`);
      } else if (b.type === 'todo_list') {
        const check = b.data.check ? '[x]' : '[ ]';
        const text = b.data.delta?.map((d: any) => d.insert || '').join('') || '';
        lines.push(`- ${check} ${text}`);
      } else if (b.type === 'image' && b.data.url) {
        lines.push(`![](${b.data.url})`);
      } else {
        const text = b.data.delta?.map((d: any) => d.insert || '').join('') || '';
        lines.push(text);
      }
    }

    navigator.clipboard.writeText(lines.join('\n\n'));
    setCopiedMarkdown(true);
    setTimeout(() => setCopiedMarkdown(false), 1500);
  }

  // Filter & Search
  const filteredPages = useMemo(() => {
    return pages.filter((p) => {
      const matchesSearch =
        search.trim() === '' ||
        p.title.toLowerCase().includes(search.toLowerCase());

      if (!matchesSearch) return false;

      if (activeFilter === 'inbox') {
        return (
          p.title.toLowerCase().includes('входящие') ||
          p.title.toLowerCase().includes('inbox') ||
          p.icon === '📥'
        );
      }

      if (activeFilter === 'root') {
        return p.parent_id === null;
      }

      return true;
    });
  }, [pages, search, activeFilter]);

  return (
    <div className="flex flex-col h-full bg-df-surface-light dark:bg-df-surface-dark text-df-text-light dark:text-df-text-dark font-sans select-none">
      {/* Modern Desktop Glass Header */}
      <header className="glass-panel sticky top-0 z-10 flex items-center justify-between px-3 py-2.5 border-b border-df-divider-light dark:border-df-divider-dark shrink-0">
        <div className="flex items-center gap-2 min-w-0">
          {selectedPage ? (
            <button
              onClick={() => setSelectedPage(null)}
              className="p-1 hover:bg-black/5 dark:hover:bg-white/10 rounded-inner transition shrink-0 text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark"
              title="Назад к списку"
            >
              <ArrowLeft className="w-4 h-4" />
            </button>
          ) : (
            <img src="/icon-32.png" alt="DraftFlow" className="w-5 h-5 rounded-inner shadow-sm shrink-0" />
          )}
          <span className="font-semibold text-xs truncate">
            {selectedPage ? selectedPage.title : 'DraftFlow'}
          </span>
        </div>

        <div className="flex items-center gap-1 shrink-0">
          {selectedPage ? (
            <button
              onClick={handleCopyPageMarkdown}
              title="Скопировать страницу в Markdown"
              className="p-1.5 rounded-inner hover:bg-black/5 dark:hover:bg-white/10 text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark transition"
            >
              {copiedMarkdown ? (
                <Check className="w-3.5 h-3.5 text-emerald-500" />
              ) : (
                <Copy className="w-3.5 h-3.5" />
              )}
            </button>
          ) : (
            <button
              onClick={() => setShowNewModal(true)}
              title="Создать новую заметку"
              className="px-2 py-1 rounded-control bg-accent hover:bg-accent-hover active:scale-[0.98] text-white transition flex items-center gap-1 text-[11px] font-medium shadow-card"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Заметка</span>
            </button>
          )}

          <button
            onClick={loadPages}
            disabled={loading}
            title="Обновить"
            className="p-1.5 rounded-inner hover:bg-black/5 dark:hover:bg-white/10 text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark transition"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          </button>
          <button
            onClick={() => chrome.runtime.openOptionsPage()}
            title="Параметры"
            className="p-1.5 rounded-inner hover:bg-black/5 dark:hover:bg-white/10 text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark transition"
          >
            <Settings className="w-3.5 h-3.5" />
          </button>
        </div>
      </header>

      {/* Main Content Area */}
      {selectedPage ? (
        /* Rich Page Viewer */
        <div className="flex-1 overflow-y-auto px-4 py-3 space-y-3">
          <div className="flex items-start gap-2.5 border-b border-df-divider-light dark:border-df-divider-dark pb-3">
            <span className="text-2xl shrink-0 mt-0.5">{selectedPage.icon || '📄'}</span>
            <div className="min-w-0 flex-1">
              <h1 className="text-sm font-bold leading-tight break-words text-df-text-light dark:text-df-text-dark">
                {selectedPage.title}
              </h1>
              <div className="text-[10px] text-df-muted-light dark:text-df-muted-dark mt-1 flex items-center gap-1.5 font-mono">
                <Clock className="w-2.5 h-2.5" />
                <span>
                  {new Date(selectedPage.created_at * 1000).toLocaleString('ru-RU', {
                    day: 'numeric',
                    month: 'short',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                  })}
                </span>
              </div>
            </div>
          </div>

          {loadingContent ? (
            <div className="flex flex-col items-center justify-center py-20 text-df-muted-light dark:text-df-muted-dark gap-2">
              <Loader2 className="w-6 h-6 animate-spin text-accent" />
              <span className="text-xs">Загрузка блоков...</span>
            </div>
          ) : blocks.length === 0 ? (
            <div className="text-center py-16 text-xs text-df-muted-light dark:text-df-muted-dark">
              (В этой заметке пока нет содержимого)
            </div>
          ) : (
            <div className="space-y-0.5 select-text pb-8">
              {blocks.map((b) => (
                <BlockRenderer key={b.id} block={b} />
              ))}
            </div>
          )}
        </div>
      ) : (
        /* Page List & Search View */
        <div className="flex-1 flex flex-col overflow-hidden">
          {/* Search Box */}
          <div className="p-2.5 border-b border-df-divider-light dark:border-df-divider-dark space-y-2 shrink-0 bg-df-surfaceSubtle-light/50 dark:bg-df-card-dark/20">
            <div className="relative">
              <Search className="w-3.5 h-3.5 absolute left-2.5 top-1/2 -translate-y-1/2 text-df-muted-light dark:text-df-muted-dark" />
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Поиск по заметкам..."
                className="w-full pl-8 pr-7 py-1.5 text-xs bg-df-surfaceSubtle-light dark:bg-df-surfaceSubtle-dark border border-df-divider-light dark:border-df-divider-dark rounded-control focus:outline-none focus:ring-2 focus:ring-accent/20 focus:border-accent text-df-text-light dark:text-df-text-dark"
              />
              {search && (
                <button
                  onClick={() => setSearch('')}
                  className="absolute right-2.5 top-1/2 -translate-y-1/2 text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark"
                >
                  <X className="w-3 h-3" />
                </button>
              )}
            </div>

            {/* Filter pills */}
            <div className="flex items-center gap-1.5">
              <button
                onClick={() => setActiveFilter('all')}
                className={`px-2.5 py-0.5 rounded-inner text-[11px] font-medium transition ${
                  activeFilter === 'all'
                    ? 'bg-accent text-white shadow-sm'
                    : 'bg-df-surfaceSubtle-light dark:bg-df-surfaceSubtle-dark text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark border border-df-divider-light/60 dark:border-df-divider-dark/40'
                }`}
              >
                Все ({pages.length})
              </button>
              <button
                onClick={() => setActiveFilter('inbox')}
                className={`px-2.5 py-0.5 rounded-inner text-[11px] font-medium transition ${
                  activeFilter === 'inbox'
                    ? 'bg-accent text-white shadow-sm'
                    : 'bg-df-surfaceSubtle-light dark:bg-df-surfaceSubtle-dark text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark border border-df-divider-light/60 dark:border-df-divider-dark/40'
                }`}
              >
                📥 Входящие
              </button>
              <button
                onClick={() => setActiveFilter('root')}
                className={`px-2.5 py-0.5 rounded-inner text-[11px] font-medium transition ${
                  activeFilter === 'root'
                    ? 'bg-accent text-white shadow-sm'
                    : 'bg-df-surfaceSubtle-light dark:bg-df-surfaceSubtle-dark text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark border border-df-divider-light/60 dark:border-df-divider-dark/40'
                }`}
              >
                📁 Разделы
              </button>
            </div>
          </div>

          {/* List of Pages */}
          <div className="flex-1 overflow-y-auto px-2 py-1 space-y-0.5">
            {filteredPages.length === 0 ? (
              <div className="p-8 text-center text-xs text-df-muted-light dark:text-df-muted-dark space-y-2">
                <FileText className="w-8 h-8 text-df-faint-light dark:text-df-faint-dark mx-auto" />
                <p>{search ? 'Ничего не найдено' : 'Заметок пока нет'}</p>
              </div>
            ) : (
              filteredPages.map((page) => (
                <button
                  key={page.id}
                  onClick={() => openPage(page)}
                  className="w-full px-2.5 py-2 rounded-inner flex items-center gap-2.5 hover:bg-black/5 dark:hover:bg-white/[0.07] text-left transition-all group"
                >
                  <span className="text-base shrink-0 group-hover:scale-105 transition-transform">
                    {page.icon || '📄'}
                  </span>
                  <div className="flex-1 min-w-0">
                    <div className="text-xs font-medium truncate text-df-text-light dark:text-df-text-dark group-hover:text-accent dark:group-hover:text-blue-400 transition-colors">
                      {page.title || 'Без названия'}
                    </div>
                    <div className="text-[10px] text-df-muted-light dark:text-df-muted-dark flex items-center gap-1 mt-0.5">
                      <Clock className="w-2.5 h-2.5" />
                      <span>
                        {new Date(page.created_at * 1000).toLocaleDateString('ru-RU', {
                          day: 'numeric',
                          month: 'short',
                        })}
                      </span>
                      {page.parent_id === null && (
                        <span className="ml-1 px-1 py-0.2 bg-black/5 dark:bg-white/10 rounded-sm text-[9px] text-df-muted-light dark:text-df-muted-dark">
                          корень
                        </span>
                      )}
                    </div>
                  </div>
                </button>
              ))
            )}
          </div>
        </div>
      )}

      {/* Modal for creating a new note */}
      {showNewModal && (
        <NewNoteModal
          pages={pages}
          onClose={() => setShowNewModal(false)}
          onCreated={(newPage) => {
            setShowNewModal(false);
            setPages([newPage, ...pages]);
            openPage(newPage);
          }}
        />
      )}
    </div>
  );
}
