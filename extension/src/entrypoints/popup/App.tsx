import React, { useState, useEffect, useRef, useMemo } from 'react';
import {
  FileText,
  Bookmark,
  Quote,
  Camera,
  Settings,
  PanelRight,
  Send,
  Loader2,
  CheckCircle2,
  AlertCircle,
  ExternalLink,
  Edit3,
  Layers,
  Tag,
  MessageSquare,
  Sparkles,
  Inbox,
  Folder,
  ChevronDown,
  Check,
} from 'lucide-react';
import { ClipMode, PageMetadata, DraftFlowPage } from '@/services/types';
import { buildMarkdownForClip } from '@/services/readability';
import { markdownToDraftFlowBlocks, generateUuid } from '@/services/blockEncoder';
import {
  fetchRemotePages,
  getOrCreateInboxPage,
  saveNewPageWithBlocks,
  makeInboxProperties,
} from '@/services/syncEngine';
import { uploadScreenshotToStorage } from '@/services/supabase';
import {
  getScratchpadDraft,
  saveScratchpadDraft,
  getSettings,
} from '@/storage/draftStore';

export default function App() {
  const [activeTab, setActiveTab] = useState<'clipper' | 'scratchpad'>('clipper');
  const [mode, setMode] = useState<ClipMode>('article');
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Tab & Content State
  const [meta, setMeta] = useState<PageMetadata>({ url: '', title: '' });
  const [articleMd, setArticleMd] = useState('');
  const [selectedText, setSelectedText] = useState('');
  const [comment, setComment] = useState('');
  const [tagsInput, setTagsInput] = useState('');
  const [screenshotUrl, setScreenshotUrl] = useState<string | null>(null);

  // Pages & Destination
  const [pages, setPages] = useState<DraftFlowPage[]>([]);
  const [targetPageId, setTargetPageId] = useState<string>('inbox');
  const [isConfigured, setIsConfigured] = useState<boolean>(true);
  const [isFolderDropdownOpen, setIsFolderDropdownOpen] = useState(false);
  const folderDropdownRef = useRef<HTMLDivElement>(null);

  // Close dropdown on click outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (folderDropdownRef.current && !folderDropdownRef.current.contains(event.target as Node)) {
        setIsFolderDropdownOpen(false);
      }
    }
    if (isFolderDropdownOpen) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => {
        document.removeEventListener('mousedown', handleClickOutside);
      };
    }
  }, [isFolderDropdownOpen]);

  // Compute clean hierarchical folder options
  interface FolderOption {
    id: string;
    title: string;
    icon?: string | null;
    depth: number;
    isInbox?: boolean;
  }

  const folderOptions = useMemo<FolderOption[]>(() => {
    const inboxPage = pages.find(
      (p) =>
        p.title.toLowerCase().includes('входящие') ||
        p.title.toLowerCase().includes('web clips')
    );
    const inboxId = inboxPage?.id;

    // Filter out:
    // 1. Trashed pages
    // 2. Database rows (e.g. movies)
    // 3. Child clips of Inbox (individual saved web notes)
    // 4. The inbox page itself (pinned as top default option)
    const validPages = pages.filter((p) => {
      if (p.trashed_at) return false;
      if (p.database_id) return false;
      if (inboxId && p.parent_id === inboxId) return false;
      if (inboxId && p.id === inboxId) return false;
      if (p.title.toLowerCase() === 'входящие / web clips') return false;
      return true;
    });

    const pageMap = new Map(validPages.map((p) => [p.id, p]));
    const roots = validPages.filter((p) => !p.parent_id || !pageMap.has(p.parent_id));

    const result: FolderOption[] = [
      {
        id: 'inbox',
        title: 'Входящие / Web Clips',
        depth: 0,
        isInbox: true,
      },
    ];

    function appendNode(node: DraftFlowPage, depth: number) {
      result.push({
        id: node.id,
        title: node.title,
        icon: node.icon,
        depth,
      });

      const children = validPages.filter((p) => p.parent_id === node.id);
      for (const child of children) {
        appendNode(child, depth + 1);
      }
    }

    for (const root of roots) {
      appendNode(root, 0);
    }

    return result;
  }, [pages]);

  const selectedFolderOption =
    folderOptions.find((opt) => opt.id === targetPageId) || folderOptions[0];

  // Scratchpad
  const [scratchpadText, setScratchpadText] = useState('');

  useEffect(() => {
    initPopup();
  }, []);

  async function queryPageDataWithInjection(tabId: number): Promise<{
    success: boolean;
    meta?: PageMetadata;
    article?: { title: string; markdown: string; excerpt: string };
  } | null> {
    return new Promise((resolve) => {
      chrome.tabs.sendMessage(tabId, { action: 'GET_PAGE_DATA' }, async (response) => {
        if (chrome.runtime.lastError || !response?.success) {
          // Tab may not have content script injected yet. Attempt dynamic injection
          try {
            await chrome.scripting.executeScript({
              target: { tabId },
              files: ['content-scripts/content.js'],
            });
            setTimeout(() => {
              chrome.tabs.sendMessage(tabId, { action: 'GET_PAGE_DATA' }, (retryRes) => {
                if (chrome.runtime.lastError || !retryRes?.success) {
                  resolve(null);
                } else {
                  resolve(retryRes);
                }
              });
            }, 100);
          } catch (e) {
            console.warn('Cannot inject content script:', e);
            resolve(null);
          }
        } else {
          resolve(response);
        }
      });
    });
  }

  async function initPopup() {
    setLoading(true);
    const settings = await getSettings();
    if (!settings.supabaseUrl || !settings.supabaseAnonKey) {
      setIsConfigured(false);
      setLoading(false);
      return;
    }

    const draft = await getScratchpadDraft();
    setScratchpadText(draft);

    fetchRemotePages().then(setPages).catch(console.error);

    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab?.id) {
        setMeta({
          url: tab.url || '',
          title: tab.title || '',
          faviconUrl: tab.favIconUrl,
        });

        const data = await queryPageDataWithInjection(tab.id);
        if (data && data.success) {
          if (data.meta) {
            setMeta((prev) => ({
              ...prev,
              ...data.meta,
              url: data.meta?.url || prev.url,
              title: data.meta?.title || prev.title,
            }));
          }
          if (data.meta?.selectedText) {
            setSelectedText(data.meta.selectedText);
            setMode('selection');
          } else if (data.article?.markdown) {
            setArticleMd(data.article.markdown);
            setMode('article');
          } else {
            setMode('bookmark');
          }
        } else {
          setMode('bookmark');
        }
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }

  async function handleSwitchToArticle() {
    setMode('article');
    if (!articleMd) {
      setLoading(true);
      try {
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        if (tab?.id) {
          const data = await queryPageDataWithInjection(tab.id);
          if (data?.article?.markdown) {
            setArticleMd(data.article.markdown);
          }
        }
      } finally {
        setLoading(false);
      }
    }
  }

  async function handleSwitchToSelection() {
    setMode('selection');
    if (!selectedText) {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab?.id) {
        const data = await queryPageDataWithInjection(tab.id);
        if (data?.meta?.selectedText) {
          setSelectedText(data.meta.selectedText);
        }
      }
    }
  }

  async function compressScreenshot(dataUrl: string, maxWidth = 1200, quality = 0.7): Promise<string> {
    return new Promise((resolve) => {
      const img = new Image();
      img.onload = () => {
        let width = img.width;
        let height = img.height;
        if (width > maxWidth) {
          height = Math.round((height * maxWidth) / width);
          width = maxWidth;
        }
        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d');
        if (!ctx) {
          resolve(dataUrl);
          return;
        }
        ctx.drawImage(img, 0, 0, width, height);
        resolve(canvas.toDataURL('image/jpeg', quality));
      };
      img.onerror = () => resolve(dataUrl);
      img.src = dataUrl;
    });
  }

  async function handleTakeScreenshot() {
    setLoading(true);
    try {
      chrome.runtime.sendMessage({ action: 'CAPTURE_VISIBLE_TAB' }, async (res) => {
        if (res?.dataUrl) {
          setScreenshotUrl(res.dataUrl);
          setMode('screenshot');
        } else if (res?.error) {
          console.warn('Screenshot error:', res.error);
        }
        setLoading(false);
      });
    } catch (e) {
      console.error(e);
      setLoading(false);
    }
  }

  async function handleSaveClip() {
    setSaving(true);
    setError(null);

    try {
      let finalScreenshotUrl = undefined;
      if (screenshotUrl) {
        const compressed = await compressScreenshot(screenshotUrl);
        finalScreenshotUrl = (await uploadScreenshotToStorage(compressed, 'clip')) || compressed;
      }

      const tags = tagsInput
        .split(/[,\s]+/)
        .map((t) => t.trim())
        .filter(Boolean);

      const markdown = buildMarkdownForClip({
        mode,
        url: meta.url,
        title: meta.title,
        description: meta.description,
        selectedText: mode === 'selection' ? selectedText : undefined,
        articleMarkdown: mode === 'article' ? articleMd : undefined,
        comment,
        tags,
        screenshotUrl: finalScreenshotUrl,
      });

      let parentId: string | null = null;
      let properties: string | null = null;

      const inboxType =
        mode === 'article'
          ? 'article'
          : mode === 'selection'
          ? 'quote'
          : mode === 'screenshot'
          ? 'screenshot'
          : 'link';

      if (targetPageId === 'inbox') {
        parentId = null;
        properties = makeInboxProperties({
          type: inboxType,
          url: meta.url,
          faviconUrl: meta.faviconUrl,
          previewImageUrl: finalScreenshotUrl,
          excerpt: mode === 'selection' ? selectedText : meta.description,
          author: meta.author,
        });
      } else {
        const found = pages.find((p) => p.id === targetPageId);
        if (found) {
          parentId = found.id;
        } else {
          parentId = null;
          properties = makeInboxProperties({
            type: inboxType,
            url: meta.url,
            faviconUrl: meta.faviconUrl,
            previewImageUrl: finalScreenshotUrl,
            excerpt: mode === 'selection' ? selectedText : meta.description,
            author: meta.author,
          });
        }
      }

      // Generate distinct title based on capture mode
      let clipTitle = meta.title || 'Новая заметка';
      if (mode === 'selection' && selectedText) {
        const firstLine = selectedText.trim().split('\n')[0].substring(0, 50).trim();
        clipTitle = `💬 «${firstLine}»`;
      } else if (mode === 'bookmark') {
        clipTitle = `🔖 ${meta.title || 'Закладка'}`;
      } else if (mode === 'screenshot') {
        clipTitle = `📸 ${meta.title || 'Снимок экрана'}`;
      } else if (mode === 'article') {
        clipTitle = `📄 ${meta.title || 'Статья'}`;
      }

      const pageId = generateUuid();
      const clipPage: DraftFlowPage = {
        id: pageId,
        title: clipTitle,
        parent_id: parentId,
        icon: mode === 'article' ? '📄' : mode === 'selection' ? '💬' : mode === 'screenshot' ? '📸' : '🔖',
        order_key: 'a0',
        properties,
        created_at: Math.floor(Date.now() / 1000),
        trashed_at: null,
      };

      const blocks = markdownToDraftFlowBlocks(markdown, pageId);
      await saveNewPageWithBlocks(clipPage, blocks);

      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab?.id) {
        chrome.tabs.sendMessage(tab.id, {
          action: 'SHOW_TOAST',
          title: 'Сохранено в DraftFlow',
          pageTitle: clipPage.title,
        });
      }

      setSuccess(true);
      setTimeout(() => {
        window.close();
      }, 900);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  async function handleSaveScratchpad() {
    if (!scratchpadText.trim()) return;
    setSaving(true);
    setError(null);

    try {
      const pageId = generateUuid();
      const firstLine = scratchpadText.trim().split('\n')[0].substring(0, 50);
      const title = firstLine.replace(/^#+\s*/, '') || 'Быстрая заметка';

      const page: DraftFlowPage = {
        id: pageId,
        title,
        parent_id: null,
        icon: '📝',
        order_key: 'a0',
        properties: makeInboxProperties({
          type: 'note',
          excerpt: scratchpadText.trim().substring(0, 200),
        }),
        created_at: Math.floor(Date.now() / 1000),
        trashed_at: null,
      };

      const blocks = markdownToDraftFlowBlocks(scratchpadText, pageId);
      await saveNewPageWithBlocks(page, blocks);

      await saveScratchpadDraft('');
      setScratchpadText('');
      setSuccess(true);

      setTimeout(() => {
        window.close();
      }, 800);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  function handleOpenSidePanel() {
    chrome.windows.getCurrent((w) => {
      if (w.id) {
        chrome.sidePanel.open({ windowId: w.id });
        window.close();
      }
    });
  }

  function handleOpenOptions() {
    chrome.runtime.openOptionsPage();
  }

  if (!isConfigured) {
    return (
      <div className="p-6 text-center space-y-4 bg-df-surface-light dark:bg-df-surface-dark min-h-[440px] flex flex-col justify-center items-center">
        <div className="w-12 h-12 bg-amber-500/10 text-amber-500 rounded-xl flex items-center justify-center">
          <Settings className="w-6 h-6" />
        </div>
        <div className="space-y-1">
          <h2 className="text-sm font-semibold text-df-text-light dark:text-df-text-dark">Подключение к DraftFlow</h2>
          <p className="text-xs text-df-muted-light dark:text-df-muted-dark max-w-[260px] leading-relaxed">
            Укажите параметры вашего Supabase сервера в настройках расширения.
          </p>
        </div>
        <button
          onClick={handleOpenOptions}
          className="py-2 px-4 bg-accent hover:bg-accent-hover text-white text-xs font-medium rounded-lg transition-all duration-150 active:scale-[0.985] shadow-[0_1px_2px_rgba(26,115,232,0.25)] flex items-center justify-center gap-2"
        >
          <Settings className="w-3.5 h-3.5" />
          Настроить подключение
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col w-[380px] bg-white dark:bg-df-surface-dark select-none text-df-text-light dark:text-df-text-dark overflow-hidden">
      {/* Modern Desktop Glass Header */}
      <header className="glass-panel sticky top-0 z-10 flex items-center justify-between px-3.5 py-2 border-b border-black/[0.04] dark:border-white/[0.06]">
        <div className="flex items-center gap-2">
          <img src="/icon-32.png" alt="DraftFlow" className="w-4.5 h-4.5 rounded-[5px] shadow-sm" />
          <div className="flex items-center gap-1.5">
            <span className="font-semibold text-xs tracking-tight text-df-text-light dark:text-df-text-dark">DraftFlow</span>
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 ring-2 ring-emerald-500/20" title="Синхронизация активна" />
          </div>
        </div>

        {/* Action icons */}
        <div className="flex items-center gap-0.5">
          <button
            onClick={handleOpenSidePanel}
            title="Открыть боковую панель (⌥⇧S)"
            className="p-1.5 rounded-lg hover:bg-black/[0.05] dark:hover:bg-white/[0.08] text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark transition-colors duration-100 active:scale-95"
          >
            <PanelRight className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={handleOpenOptions}
            title="Параметры"
            className="p-1.5 rounded-lg hover:bg-black/[0.05] dark:hover:bg-white/[0.08] text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark transition-colors duration-100 active:scale-95"
          >
            <Settings className="w-3.5 h-3.5" />
          </button>
        </div>
      </header>

      {/* Modern Segmented Control */}
      <div className="px-3.5 pt-2 pb-0.5">
        <div className="flex bg-[#F2F3F5] dark:bg-[#26282C] p-0.5 rounded-lg">
          <button
            onClick={() => setActiveTab('clipper')}
            className={`flex-1 py-1 rounded-[6px] text-xs font-medium flex items-center justify-center gap-1.5 transition-all duration-180 ease-[cubic-bezier(0.2,0.8,0.2,1)] ${
              activeTab === 'clipper'
                ? 'bg-white dark:bg-[#1F2023] text-df-text-light dark:text-df-text-dark shadow-[0_1px_2px_rgba(0,0,0,0.06),0_1px_3px_rgba(0,0,0,0.04)]'
                : 'text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark'
            }`}
          >
            <Bookmark className="w-3.5 h-3.5" />
            Клиппер
          </button>
          <button
            onClick={() => setActiveTab('scratchpad')}
            className={`flex-1 py-1 rounded-[6px] text-xs font-medium flex items-center justify-center gap-1.5 transition-all duration-180 ease-[cubic-bezier(0.2,0.8,0.2,1)] ${
              activeTab === 'scratchpad'
                ? 'bg-white dark:bg-[#1F2023] text-df-text-light dark:text-df-text-dark shadow-[0_1px_2px_rgba(0,0,0,0.06),0_1px_3px_rgba(0,0,0,0.04)]'
                : 'text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark'
            }`}
          >
            <Edit3 className="w-3.5 h-3.5" />
            Блокнот
          </button>
        </div>
      </div>

      {/* Main Body */}
      <div className="px-3.5 py-2 space-y-2.5">
        {activeTab === 'clipper' ? (
          <>
            {/* Compact Web Context Card */}
            <div className="px-2.5 py-1.5 bg-[#F2F3F5]/80 dark:bg-[#26282C]/70 rounded-lg flex items-center gap-2.5">
              <div className="w-7 h-7 rounded-lg bg-white dark:bg-[#1E2024] flex items-center justify-center shrink-0 shadow-[0_1px_2px_rgba(0,0,0,0.06)] ring-1 ring-black/[0.06] dark:ring-white/[0.08]">
                {meta.faviconUrl ? (
                  <img
                    src={meta.faviconUrl}
                    alt=""
                    className="w-4 h-4 rounded-[3px] object-contain shrink-0"
                    onError={(e) => {
                      (e.target as HTMLElement).style.display = 'none';
                    }}
                  />
                ) : (
                  <ExternalLink className="w-3.5 h-3.5 text-df-muted-light dark:text-df-muted-dark shrink-0" />
                )}
              </div>
              <div className="flex-1 min-w-0">
                <input
                  type="text"
                  value={meta.title}
                  onChange={(e) => setMeta({ ...meta, title: e.target.value })}
                  className="w-full text-xs font-medium bg-transparent border-none p-0 focus:outline-none truncate text-df-text-light dark:text-df-text-dark"
                  placeholder="Заголовок страницы..."
                />
                <div className="text-[10px] text-df-muted-light dark:text-df-muted-dark truncate font-mono">
                  {meta.url ? new URL(meta.url).hostname.replace(/^www\./, '') : ''}
                </div>
              </div>
            </div>

            {/* Mode Segmented Control */}
            <div className="grid grid-cols-4 gap-0.5 bg-[#F2F3F5] dark:bg-[#26282C] p-0.5 rounded-lg">
              <button
                onClick={handleSwitchToArticle}
                className={`py-1 rounded-[6px] text-[11px] font-medium flex flex-col items-center gap-0.5 transition-all duration-180 ease-[cubic-bezier(0.2,0.8,0.2,1)] ${
                  mode === 'article'
                    ? 'bg-white dark:bg-[#1F2023] text-accent dark:text-blue-400 shadow-[0_1px_2px_rgba(0,0,0,0.06),0_1px_3px_rgba(0,0,0,0.04)]'
                    : 'text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark'
                }`}
              >
                <FileText className="w-3.5 h-3.5" />
                Статья
              </button>
              <button
                onClick={handleSwitchToSelection}
                className={`py-1 rounded-[6px] text-[11px] font-medium flex flex-col items-center gap-0.5 transition-all duration-180 ease-[cubic-bezier(0.2,0.8,0.2,1)] ${
                  mode === 'selection'
                    ? 'bg-white dark:bg-[#1F2023] text-accent dark:text-blue-400 shadow-[0_1px_2px_rgba(0,0,0,0.06),0_1px_3px_rgba(0,0,0,0.04)]'
                    : 'text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark'
                }`}
              >
                <Quote className="w-3.5 h-3.5" />
                Цитата
              </button>
              <button
                onClick={() => setMode('bookmark')}
                className={`py-1 rounded-[6px] text-[11px] font-medium flex flex-col items-center gap-0.5 transition-all duration-180 ease-[cubic-bezier(0.2,0.8,0.2,1)] ${
                  mode === 'bookmark'
                    ? 'bg-white dark:bg-[#1F2023] text-accent dark:text-blue-400 shadow-[0_1px_2px_rgba(0,0,0,0.06),0_1px_3px_rgba(0,0,0,0.04)]'
                    : 'text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark'
                }`}
              >
                <Bookmark className="w-3.5 h-3.5" />
                Закладка
              </button>
              <button
                onClick={handleTakeScreenshot}
                className={`py-1 rounded-[6px] text-[11px] font-medium flex flex-col items-center gap-0.5 transition-all duration-180 ease-[cubic-bezier(0.2,0.8,0.2,1)] ${
                  mode === 'screenshot'
                    ? 'bg-white dark:bg-[#1F2023] text-accent dark:text-blue-400 shadow-[0_1px_2px_rgba(0,0,0,0.06),0_1px_3px_rgba(0,0,0,0.04)]'
                    : 'text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark'
                }`}
              >
                <Camera className="w-3.5 h-3.5" />
                Скриншот
              </button>
            </div>

            {/* Mode-specific Content Area */}
            {mode === 'article' && (
              <div className="px-3 py-2 bg-emerald-500/[0.07] dark:bg-emerald-500/[0.12] border border-emerald-500/20 rounded-xl flex items-center justify-between">
                <div className="flex items-center gap-2 text-[11px] text-emerald-800 dark:text-emerald-300 font-medium">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 shrink-0 shadow-[0_0_6px_rgba(16,185,129,0.4)]" />
                  {articleMd ? (
                    <span>Статья извлечена (~{Math.round(articleMd.split(/\s+/).length)} слов)</span>
                  ) : (
                    <span className="text-df-muted-light dark:text-df-muted-dark">Текст статьи не обнаружен</span>
                  )}
                </div>
                <button
                  onClick={handleSwitchToArticle}
                  className="text-[12px] font-medium text-accent hover:bg-accent/10 px-2 py-1 rounded-md transition-colors active:scale-95"
                >
                  {articleMd ? 'Обновить' : 'Извлечь'}
                </button>
              </div>
            )}

            {mode === 'selection' && (
              <div className="space-y-1">
                <div className="flex items-center justify-between text-[10px] text-df-muted-light dark:text-df-muted-dark px-0.5">
                  <span className="flex items-center gap-1.5 font-medium">
                    {selectedText ? (
                      <>
                        <span className="w-1.5 h-1.5 rounded-full bg-accent" />
                        Захваченный фрагмент
                      </>
                    ) : (
                      'Выделите текст на странице или вставьте сюда:'
                    )}
                  </span>
                  {selectedText && (
                    <button
                      onClick={() => setSelectedText('')}
                      className="text-df-muted-light dark:text-df-muted-dark hover:text-red-500 dark:hover:text-red-400 transition-colors duration-150 text-[10px]"
                    >
                      Очистить
                    </button>
                  )}
                </div>
                <div className="relative rounded-r-lg rounded-l-[2px] bg-[#F8F9FA] dark:bg-[#25272B] border-l-2 border-accent pl-2.5 pr-2 py-1.5">
                  <textarea
                    value={selectedText}
                    onChange={(e) => setSelectedText(e.target.value)}
                    placeholder="Выделите текст на веб-странице или вставьте цитату сюда..."
                    rows={Math.min(4, Math.max(2, selectedText.split('\n').length))}
                    className="w-full text-xs bg-transparent border-none p-0 focus:outline-none resize-none text-df-text-light dark:text-df-text-dark leading-relaxed font-sans placeholder:text-df-muted-light/60 dark:placeholder:text-df-muted-dark/60 max-h-[95px]"
                  />
                </div>
              </div>
            )}

            {mode === 'bookmark' && (
              <div className="px-2.5 py-2 bg-[#F8F9FA] dark:bg-[#25272B] rounded-r-lg rounded-l-[2px] border-l-2 border-accent/80 space-y-1">
                <div className="flex items-center justify-between text-[10px] text-df-muted-light dark:text-df-muted-dark">
                  <span className="font-medium uppercase tracking-wider text-[9px]">Закладка</span>
                  <span className="text-accent flex items-center gap-0.5"><ExternalLink className="w-2.5 h-2.5" /> Ссылка</span>
                </div>
                <div className="font-medium text-xs text-df-text-light dark:text-df-text-dark truncate">
                  {meta.title}
                </div>
                <div className="text-[10px] text-accent dark:text-blue-400 font-mono truncate">
                  {meta.url}
                </div>
                {meta.description && (
                  <div className="text-[10px] text-df-muted-light dark:text-df-muted-dark italic line-clamp-2 pt-0.5">
                    {meta.description}
                  </div>
                )}
              </div>
            )}

            {mode === 'screenshot' && (
              <div>
                {screenshotUrl ? (
                  <div className="relative rounded-lg overflow-hidden max-h-24 bg-black">
                    <img src={screenshotUrl} alt="Preview" className="w-full object-cover" />
                    <button
                      onClick={handleTakeScreenshot}
                      className="absolute bottom-1 right-1 px-2 py-0.5 bg-black/70 hover:bg-black text-[10px] text-white rounded transition active:scale-95 shadow"
                    >
                      Переснять
                    </button>
                  </div>
                ) : (
                  <button
                    onClick={handleTakeScreenshot}
                    className="w-full py-2.5 bg-[#F2F3F5] dark:bg-[#26282C] hover:bg-[#EBECEF] dark:hover:bg-[#303338] rounded-lg text-xs text-df-muted-light dark:text-df-muted-dark hover:text-df-text-light dark:hover:text-df-text-dark flex items-center justify-center gap-1.5 transition active:scale-[0.985]"
                  >
                    <Camera className="w-3.5 h-3.5" /> Снять видимую часть экрана
                  </button>
                )}
              </div>
            )}

            {/* Target Page Selector (Custom Modern Desktop Popover) */}
            <div className="space-y-1 relative" ref={folderDropdownRef}>
              <label className="text-[11px] font-medium text-df-muted-light dark:text-df-muted-dark flex items-center gap-1.5">
                <Folder className="w-3 h-3 text-df-muted-light dark:text-df-muted-dark" />
                Раздел назначения:
              </label>

              {/* Popover Trigger Button */}
              <button
                type="button"
                onClick={() => setIsFolderDropdownOpen((prev) => !prev)}
                className={`w-full px-3 h-9 text-xs bg-[#F2F3F5] dark:bg-[#26282C] hover:bg-[#EBECEF] dark:hover:bg-[#303338] rounded-lg text-df-text-light dark:text-df-text-dark flex items-center justify-between transition-all duration-150 active:scale-[0.99] border border-transparent ${
                  isFolderDropdownOpen ? 'ring-2 ring-accent/20 border-accent/40 bg-white dark:bg-[#1F2023]' : ''
                }`}
              >
                <div className="flex items-center gap-2 truncate">
                  {selectedFolderOption?.isInbox ? (
                    <Inbox className="w-3.5 h-3.5 text-accent shrink-0" />
                  ) : selectedFolderOption?.icon ? (
                    <span className="text-xs shrink-0">{selectedFolderOption.icon}</span>
                  ) : (
                    <Folder className="w-3.5 h-3.5 text-df-muted-light dark:text-df-muted-dark shrink-0" />
                  )}
                  <span className="truncate font-medium">
                    {selectedFolderOption?.title || 'Входящие / Web Clips'}
                  </span>
                  {selectedFolderOption?.isInbox && (
                    <span className="text-[10px] text-df-muted-light dark:text-df-muted-dark font-normal">
                      (по умолчанию)
                    </span>
                  )}
                </div>
                <ChevronDown
                  className={`w-4 h-4 text-df-muted-light dark:text-df-muted-dark shrink-0 ml-2 transition-transform duration-200 ${
                    isFolderDropdownOpen ? 'rotate-180 text-accent' : ''
                  }`}
                />
              </button>

              {/* Popover Menu (bounded strictly inside the popup) */}
              {isFolderDropdownOpen && (
                <div className="absolute left-0 right-0 top-full mt-1 bg-white dark:bg-[#1E2024] rounded-xl shadow-[0_10px_25px_rgba(0,0,0,0.15),0_2px_8px_rgba(0,0,0,0.06)] border border-black/[0.08] dark:border-white/[0.08] z-50 p-1 max-h-48 overflow-y-auto thin-scrollbar">
                  {folderOptions.map((opt) => {
                    const isSelected =
                      targetPageId === opt.id || (opt.id === 'inbox' && targetPageId === 'inbox');
                    return (
                      <button
                        key={opt.id}
                        type="button"
                        onClick={() => {
                          setTargetPageId(opt.id);
                          setIsFolderDropdownOpen(false);
                        }}
                        className={`w-full text-left px-2 py-1.5 rounded-lg text-xs flex items-center justify-between transition-colors duration-100 ${
                          isSelected
                            ? 'bg-accent/10 text-accent font-medium'
                            : 'text-df-text-light dark:text-df-text-dark hover:bg-black/[0.04] dark:hover:bg-white/[0.06]'
                        }`}
                        style={{ paddingLeft: `${8 + opt.depth * 14}px` }}
                      >
                        <div className="flex items-center gap-2 truncate">
                          {opt.isInbox ? (
                            <Inbox
                              className={`w-3.5 h-3.5 shrink-0 ${
                                isSelected ? 'text-accent' : 'text-df-muted-light dark:text-df-muted-dark'
                              }`}
                            />
                          ) : opt.icon ? (
                            <span className="text-xs shrink-0">{opt.icon}</span>
                          ) : (
                            <Folder
                              className={`w-3.5 h-3.5 shrink-0 ${
                                isSelected ? 'text-accent' : 'text-df-muted-light dark:text-df-muted-dark'
                              }`}
                            />
                          )}
                          <span className="truncate">{opt.title}</span>
                          {opt.isInbox && (
                            <span className="text-[10px] text-df-muted-light dark:text-df-muted-dark font-normal">
                              (по умолчанию)
                            </span>
                          )}
                        </div>
                        {isSelected && (
                          <Check className="w-3.5 h-3.5 text-accent shrink-0 ml-1.5" />
                        )}
                      </button>
                    );
                  })}
                </div>
              )}
            </div>

            {/* Comment */}
            <div className="space-y-1">
              <div className="relative flex items-center">
                <MessageSquare className="w-3.5 h-3.5 absolute left-3 text-[#9CA3AF] pointer-events-none transition-colors" />
                <input
                  type="text"
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                  placeholder="Добавить свой комментарий..."
                  className="w-full pl-9 pr-3 h-9 text-xs bg-[#F2F3F5] dark:bg-[#26282C] border border-transparent focus:border-accent/40 rounded-lg focus:outline-none focus:ring-2 focus:ring-accent/20 focus:bg-white dark:focus:bg-[#1F2023] text-df-text-light dark:text-df-text-dark transition-all placeholder:text-[#9CA3AF]"
                />
              </div>
            </div>

            {/* Tags */}
            <div className="space-y-1">
              <div className="relative flex items-center">
                <Tag className="w-3.5 h-3.5 absolute left-3 text-[#9CA3AF] pointer-events-none transition-colors" />
                <input
                  type="text"
                  value={tagsInput}
                  onChange={(e) => setTagsInput(e.target.value)}
                  placeholder="Теги (через запятую)..."
                  className="w-full pl-9 pr-3 h-9 text-xs bg-[#F2F3F5] dark:bg-[#26282C] border border-transparent focus:border-accent/40 rounded-lg focus:outline-none focus:ring-2 focus:ring-accent/20 focus:bg-white dark:focus:bg-[#1F2023] text-df-text-light dark:text-df-text-dark transition-all placeholder:text-[#9CA3AF]"
                />
              </div>
            </div>
          </>
        ) : (
          /* Scratchpad */
          <div className="flex flex-col space-y-2">
            <textarea
              value={scratchpadText}
              onChange={(e) => {
                setScratchpadText(e.target.value);
                saveScratchpadDraft(e.target.value);
              }}
              placeholder="Быстрый сброс мыслей, планов или заметок... Текст автосохраняется."
              rows={8}
              className="w-full h-44 p-2.5 text-xs bg-[#F8F9FA] dark:bg-[#25272B] rounded-lg border border-black/[0.04] dark:border-white/[0.06] focus:outline-none focus:ring-2 focus:ring-accent/20 resize-none font-mono text-df-text-light dark:text-df-text-dark leading-relaxed"
            />
            <div className="flex items-center justify-between text-[11px] text-df-muted-light dark:text-df-muted-dark px-1">
              <span>Символов: {scratchpadText.length}</span>
              <span className="flex items-center gap-1 text-emerald-500">
                <CheckCircle2 className="w-3 h-3" /> Автосохранение
              </span>
            </div>
          </div>
        )}

        {error && (
          <div className="p-2 bg-red-500/10 text-red-500 rounded-lg text-xs flex items-center gap-2">
            <AlertCircle className="w-3.5 h-3.5 shrink-0" />
            <span>{error}</span>
          </div>
        )}
      </div>

      {/* Modern Desktop Glass Footer */}
      <footer className="p-3 pt-2 border-t border-black/[0.04] dark:border-white/[0.06] bg-white/80 dark:bg-df-surface-dark/80 backdrop-blur-md space-y-2">
        <button
          onClick={activeTab === 'clipper' ? handleSaveClip : handleSaveScratchpad}
          disabled={saving || loading || (activeTab === 'scratchpad' && !scratchpadText.trim())}
          className={`w-full py-2 px-3.5 font-medium rounded-lg text-xs flex items-center justify-center gap-2 transition-all duration-150 active:scale-[0.985] shadow-[0_1px_2px_rgba(26,115,232,0.25),inset_0_1px_0_rgba(255,255,255,0.18)] ${
            success
              ? 'bg-emerald-600 text-white'
              : 'bg-accent hover:bg-accent-hover text-white disabled:opacity-50'
          }`}
        >
          {saving ? (
            <>
              <Loader2 className="w-3.5 h-3.5 animate-spin" />
              <span>Сохранение...</span>
            </>
          ) : success ? (
            <>
              <CheckCircle2 className="w-3.5 h-3.5 text-white" />
              <span>Сохранено в DraftFlow</span>
            </>
          ) : (
            <>
              <Send className="w-3.5 h-3.5" />
              <span>{activeTab === 'clipper' ? 'Сохранить в DraftFlow' : 'Создать заметку'}</span>
            </>
          )}
        </button>

        {/* Unified Keyboard shortcut bar */}
        <div className="flex items-center justify-center gap-3 text-[10px] text-df-muted-light dark:text-df-muted-dark">
          <span className="flex items-center gap-1">
            <span>Клиппер</span>
            <kbd className="px-1.5 py-0.5 rounded-[5px] bg-black/[0.05] dark:bg-white/[0.08] border border-black/[0.04] dark:border-white/[0.06] font-mono text-[9px] text-df-text-light dark:text-df-text-dark">⌥⇧D</kbd>
          </span>
          <span className="text-black/20 dark:text-white/20">•</span>
          <span className="flex items-center gap-1">
            <span>Панель</span>
            <kbd className="px-1.5 py-0.5 rounded-[5px] bg-black/[0.05] dark:bg-white/[0.08] border border-black/[0.04] dark:border-white/[0.06] font-mono text-[9px] text-df-text-light dark:text-df-text-dark">⌥⇧S</kbd>
          </span>
        </div>
      </footer>
    </div>
  );
}
