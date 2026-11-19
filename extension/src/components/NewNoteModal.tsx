import React, { useState } from 'react';
import { X, Send, Loader2, Layers, AlertCircle } from 'lucide-react';
import { DraftFlowPage } from '../services/types';
import { markdownToDraftFlowBlocks, generateUuid } from '../services/blockEncoder';
import {
  saveNewPageWithBlocks,
  getOrCreateInboxPage,
  makeInboxProperties,
} from '../services/syncEngine';

const COMMON_ICONS = ['📝', '💡', '⚡', '📌', '🚀', '🎯', '📚', '🛠️', '📄'];

export default function NewNoteModal({
  pages,
  onClose,
  onCreated,
}: {
  pages: DraftFlowPage[];
  onClose: () => void;
  onCreated: (page: DraftFlowPage) => void;
}) {
  const [title, setTitle] = useState('');
  const [icon, setIcon] = useState('📝');
  const [targetParentId, setTargetParentId] = useState('inbox');
  const [content, setContent] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;

    setSaving(true);
    setError(null);

    try {
      let parentId: string | null = null;
      let properties: string | null = null;

      if (targetParentId === 'inbox') {
        parentId = null;
        properties = makeInboxProperties({
          type: 'note',
          excerpt: content.trim().substring(0, 200),
        });
      } else {
        const found = pages.find((p) => p.id === targetParentId);
        if (found) {
          parentId = found.id;
        } else {
          parentId = null;
          properties = makeInboxProperties({
            type: 'note',
            excerpt: content.trim().substring(0, 200),
          });
        }
      }

      const pageId = generateUuid();
      const newPage: DraftFlowPage = {
        id: pageId,
        title: title.trim(),
        parent_id: parentId,
        icon,
        order_key: 'a0',
        properties,
        created_at: Math.floor(Date.now() / 1000),
        trashed_at: null,
      };

      const blocks = markdownToDraftFlowBlocks(content, pageId);
      await saveNewPageWithBlocks(newPage, blocks);

      onCreated(newPage);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-end sm:items-center justify-center p-3 animate-fade-in">
      <div className="bg-df-surface-light dark:bg-df-surface-dark border border-df-divider-light dark:border-df-divider-dark rounded-popover shadow-popover w-full max-w-sm overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-df-divider-light dark:border-df-divider-dark bg-df-surfaceSubtle-light/70 dark:bg-df-card-dark/40">
          <div className="flex items-center gap-2">
            <span className="text-base">{icon}</span>
            <span className="font-semibold text-xs text-df-text-light dark:text-df-text-dark">Новая заметка</span>
          </div>
          <button
            onClick={onClose}
            className="p-1 rounded-inner hover:bg-black/5 dark:hover:bg-white/10 text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark transition"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleCreate} className="p-4 space-y-3 overflow-y-auto flex-1">
          {/* Icon picker */}
          <div className="flex items-center gap-1.5 overflow-x-auto py-1">
            {COMMON_ICONS.map((emoji) => (
              <button
                key={emoji}
                type="button"
                onClick={() => setIcon(emoji)}
                className={`p-1.5 rounded-inner text-sm transition shrink-0 ${
                  icon === emoji
                    ? 'bg-accent/15 ring-1 ring-accent scale-105'
                    : 'hover:bg-black/5 dark:hover:bg-white/5'
                }`}
              >
                {emoji}
              </button>
            ))}
          </div>

          {/* Title */}
          <div>
            <input
              type="text"
              required
              autoFocus
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Название заметки..."
              className="w-full px-3 py-2 text-xs font-medium bg-df-surfaceSubtle-light dark:bg-df-surfaceSubtle-dark border border-df-divider-light dark:border-df-divider-dark rounded-control focus:outline-none focus:ring-2 focus:ring-accent/20 focus:border-accent text-df-text-light dark:text-df-text-dark"
            />
          </div>

          {/* Target Folder */}
          <div className="space-y-1">
            <label className="text-[11px] font-medium text-df-muted-light dark:text-df-muted-dark flex items-center gap-1">
              <Layers className="w-3 h-3 text-accent" />
              Родительская страница:
            </label>
            <select
              value={targetParentId}
              onChange={(e) => setTargetParentId(e.target.value)}
              className="w-full px-2.5 py-1.5 text-xs bg-df-surfaceSubtle-light dark:bg-df-surfaceSubtle-dark border border-df-divider-light dark:border-df-divider-dark rounded-control focus:outline-none focus:ring-2 focus:ring-accent/20 focus:border-accent text-df-text-light dark:text-df-text-dark"
            >
              <option value="inbox">📥 Входящие / Web Clips</option>
              {pages
                .filter((p) => !p.trashed_at && !p.database_id && p.title.toLowerCase() !== 'входящие / web clips')
                .map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.icon || '📄'} {p.title}
                  </option>
                ))}
            </select>
          </div>

          {/* Content */}
          <div className="space-y-1">
            <textarea
              value={content}
              onChange={(e) => setContent(e.target.value)}
              rows={6}
              placeholder="Текст заметки (поддерживается Markdown: # заголовки, - списки, > цитаты)..."
              className="w-full p-3 text-xs bg-df-surfaceSubtle-light dark:bg-df-surfaceSubtle-dark border border-df-divider-light dark:border-df-divider-dark rounded-card focus:outline-none focus:ring-2 focus:ring-accent/20 focus:border-accent font-mono resize-none text-df-text-light dark:text-df-text-dark leading-relaxed"
            />
          </div>

          {error && (
            <div className="p-2 bg-red-500/10 border border-red-500/20 text-red-500 text-xs rounded-control flex items-center gap-2">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <div className="pt-2">
            <button
              type="submit"
              disabled={saving || !title.trim()}
              className="w-full py-2.5 px-4 bg-accent hover:bg-accent-hover active:scale-[0.98] disabled:opacity-50 text-white font-medium rounded-control transition-all flex items-center justify-center gap-2 text-xs shadow-card"
            >
              {saving ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Создание...
                </>
              ) : (
                <>
                  <Send className="w-3.5 h-3.5" />
                  Создать заметку
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
