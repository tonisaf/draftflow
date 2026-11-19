import { defineBackground } from 'wxt/sandbox';
import { ClipMode, DraftFlowPage } from '../services/types';
import { buildMarkdownForClip } from '../services/readability';
import { markdownToDraftFlowBlocks, generateUuid } from '../services/blockEncoder';
import {
  fetchRemotePages,
  getOrCreateInboxPage,
  saveNewPageWithBlocks,
} from '../services/syncEngine';

export default defineBackground(() => {
  // Set up context menus on install
  chrome.runtime.onInstalled.addListener(() => {
    chrome.contextMenus.create({
      id: 'draftflow-save-page',
      title: 'Сохранить страницу в DraftFlow',
      contexts: ['page'],
    });

    chrome.contextMenus.create({
      id: 'draftflow-save-selection',
      title: 'Сохранить цитату в DraftFlow',
      contexts: ['selection'],
    });
  });

  // Handle context menu clicks
  chrome.contextMenus.onClicked.addListener(async (info, tab) => {
    if (!tab?.id) return;

    if (info.menuItemId === 'draftflow-save-selection') {
      try {
        await chrome.tabs.sendMessage(tab.id, {
          action: 'PERFORM_QUICK_CLIP',
          mode: 'selection',
          selectedText: info.selectionText,
        });
      } catch (err) {
        console.error('Error sending quick clip selection message:', err);
      }
    } else if (info.menuItemId === 'draftflow-save-page') {
      try {
        await chrome.tabs.sendMessage(tab.id, {
          action: 'PERFORM_QUICK_CLIP',
          mode: 'article',
        });
      } catch (err) {
        console.error('Error sending quick clip page message:', err);
      }
    }
  });

  // Handle keyboard shortcuts (commands)
  chrome.commands.onCommand.addListener(async (command, tab) => {
    if (command === 'open_side_panel') {
      if (tab?.windowId) {
        await chrome.sidePanel.open({ windowId: tab.windowId });
      }
    }
  });

  // Handle messages from popup / content scripts
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.action === 'CAPTURE_VISIBLE_TAB') {
      chrome.windows.getLastFocused({ populate: false }, (win) => {
        const targetWindowId = win?.id || chrome.windows.WINDOW_ID_CURRENT;
        chrome.tabs.captureVisibleTab(targetWindowId, { format: 'png' }, (dataUrl) => {
          if (chrome.runtime.lastError) {
            console.warn('captureVisibleTab error:', chrome.runtime.lastError.message);
            sendResponse({ error: chrome.runtime.lastError.message });
          } else {
            sendResponse({ dataUrl });
          }
        });
      });
      return true;
    }

    if (message.action === 'SAVE_QUICK_CLIP') {
      handleQuickClipSave(message.data)
        .then((page) => {
          sendResponse({ success: true, title: page.title });
        })
        .catch((err: unknown) => {
          console.error('handleQuickClipSave error:', err);
          sendResponse({
            success: false,
            error: err instanceof Error ? err.message : String(err),
          });
        });
      return true; // Keep message channel open for async response
    }
  });
});

async function handleQuickClipSave(data: {
  mode: ClipMode;
  url: string;
  title: string;
  selectedText?: string;
  articleMarkdown?: string;
}): Promise<DraftFlowPage> {
  const pages = await fetchRemotePages();
  const inbox = await getOrCreateInboxPage(pages);

  const markdown = buildMarkdownForClip({
    mode: data.mode,
    url: data.url,
    title: data.title,
    selectedText: data.selectedText,
    articleMarkdown: data.articleMarkdown,
  });

  const pageId = generateUuid();
  let clipTitle = data.title || 'Новая заметка';
  if (data.mode === 'selection' && data.selectedText) {
    const firstLine = data.selectedText.trim().split('\n')[0].substring(0, 60).trim();
    if (firstLine) {
      clipTitle = `«${firstLine}»`;
    }
  }

  const clipPage: DraftFlowPage = {
    id: pageId,
    title: clipTitle,
    parent_id: inbox.id,
    icon: data.mode === 'selection' ? '💬' : '📄',
    order_key: 'a0',
    created_at: Math.floor(Date.now() / 1000),
    trashed_at: null,
  };

  const blocks = markdownToDraftFlowBlocks(markdown, pageId);
  await saveNewPageWithBlocks(clipPage, blocks);

  return clipPage;
}
