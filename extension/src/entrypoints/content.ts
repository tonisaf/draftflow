import { defineContentScript } from 'wxt/sandbox';
import { extractPageMetadata, parseArticleFromDocument } from '../services/readability';
import { getSettings } from '../storage/draftStore';

export default defineContentScript({
  matches: ['<all_urls>'],
  main() {
    let floatingBtn: HTMLButtonElement | null = null;
    let isFloatingEnabled = true;

    // Load initial settings
    getSettings().then((s) => {
      isFloatingEnabled = s.showFloatingButton ?? true;
    }).catch(() => {});

    // Listen to storage changes to update floating button setting dynamically
    chrome.storage.onChanged.addListener((changes) => {
      if (changes.draftflow_settings?.newValue) {
        isFloatingEnabled = changes.draftflow_settings.newValue.showFloatingButton ?? true;
        if (!isFloatingEnabled && floatingBtn) {
          removeFloatingButton();
        }
      }
    });

    // 1. Message listener from background
    chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
      if (message.action === 'GET_PAGE_DATA') {
        try {
          const meta = extractPageMetadata();
          const article = parseArticleFromDocument();
          sendResponse({ success: true, meta, article });
        } catch (err: unknown) {
          sendResponse({ success: false, error: String(err) });
        }
        return true;
      }

      if (message.action === 'SHOW_TOAST') {
        showDraftFlowToast(message.title || 'Сохранено в DraftFlow', message.pageTitle, message.isError);
        sendResponse({ success: true });
        return true;
      }

      if (message.action === 'PERFORM_QUICK_CLIP') {
        handleQuickClipRequest(message.mode, message.selectedText);
        sendResponse({ received: true });
        return true;
      }
    });

    // 2. Floating Quick Clip button on text selection
    document.addEventListener('mouseup', (e) => {
      if (!isFloatingEnabled) return;
      if (floatingBtn && floatingBtn.contains(e.target as Node)) return;

      setTimeout(() => {
        handleTextSelection();
      }, 20);
    });

    document.addEventListener('mousedown', (e) => {
      if (floatingBtn && !floatingBtn.contains(e.target as Node)) {
        removeFloatingButton();
      }
    });

    function handleTextSelection() {
      const selection = window.getSelection();
      if (!selection || selection.isCollapsed) {
        removeFloatingButton();
        return;
      }

      const text = selection.toString().trim();
      if (text.length < 3) {
        removeFloatingButton();
        return;
      }

      // Avoid showing inside input, textarea or contentEditable
      const anchorNode = selection.anchorNode;
      const element = anchorNode?.nodeType === Node.ELEMENT_NODE
        ? (anchorNode as HTMLElement)
        : anchorNode?.parentElement;

      if (
        element?.closest('input, textarea') ||
        element?.isContentEditable ||
        element?.closest('[contenteditable="true"]')
      ) {
        removeFloatingButton();
        return;
      }

      const range = selection.getRangeAt(0);
      const rect = range.getBoundingClientRect();
      if (rect.width === 0 && rect.height === 0) {
        removeFloatingButton();
        return;
      }

      createFloatingButton(rect, text);
    }

    function createFloatingButton(rect: DOMRect, selectedText: string) {
      removeFloatingButton();

      const btn = document.createElement('button');
      btn.id = 'draftflow-floating-clip-btn';
      btn.style.cssText = `
        position: absolute;
        z-index: 2147483646;
        background: #181818;
        color: #ffffff;
        border: 1px solid #383838;
        border-radius: 8px;
        box-shadow: 0 8px 20px rgba(0, 0, 0, 0.4);
        padding: 5px 10px;
        display: flex;
        align-items: center;
        gap: 6px;
        cursor: pointer;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        font-size: 12px;
        font-weight: 500;
        opacity: 0;
        transform: translateY(4px) scale(0.96);
        transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
        user-select: none;
      `;

      const iconUrl = chrome.runtime.getURL('icon-32.png');
      btn.innerHTML = `
        <img src="${iconUrl}" style="width:15px;height:15px;border-radius:3px;display:block;flex-shrink:0;" />
        <span>В DraftFlow</span>
      `;

      // Position: centered above selection (or below if too close to viewport top)
      const btnWidth = 110;
      const left = window.scrollX + rect.left + rect.width / 2 - btnWidth / 2;
      const top =
        rect.top > 45
          ? window.scrollY + rect.top - 36
          : window.scrollY + rect.bottom + 8;

      btn.style.left = `${Math.max(10, left)}px`;
      btn.style.top = `${top}px`;

      btn.addEventListener('mouseenter', () => {
        btn.style.background = '#242424';
        btn.style.borderColor = '#22c55e';
      });

      btn.addEventListener('mouseleave', () => {
        btn.style.background = '#181818';
        btn.style.borderColor = '#383838';
      });

      btn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();

        btn.innerHTML = `
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#22c55e" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
            <path d="M20 6 9 17l-5-5"/>
          </svg>
          <span style="color:#22c55e;">Сохранено!</span>
        `;

        handleQuickClipRequest('selection', selectedText);

        setTimeout(() => {
          removeFloatingButton();
        }, 1200);
      });

      document.body.appendChild(btn);
      floatingBtn = btn;

      requestAnimationFrame(() => {
        btn.style.opacity = '1';
        btn.style.transform = 'translateY(0) scale(1)';
      });
    }

    function removeFloatingButton() {
      if (floatingBtn) {
        floatingBtn.remove();
        floatingBtn = null;
      }
    }

    async function handleQuickClipRequest(mode: 'selection' | 'article', textOverride?: string) {
      try {
        const meta = extractPageMetadata();
        let selectedText = textOverride || meta.selectedText || window.getSelection()?.toString().trim();
        let articleMarkdown: string | undefined = undefined;

        if (mode === 'article') {
          const parsed = parseArticleFromDocument();
          articleMarkdown = parsed.markdown;
        }

        showDraftFlowToast('Сохранение в DraftFlow...', meta.title);

        chrome.runtime.sendMessage(
          {
            action: 'SAVE_QUICK_CLIP',
            data: {
              mode,
              url: meta.url,
              title: meta.title,
              selectedText: mode === 'selection' ? selectedText : undefined,
              articleMarkdown: mode === 'article' ? articleMarkdown : undefined,
            },
          },
          (res) => {
            if (chrome.runtime.lastError || !res?.success) {
              const err = res?.error || chrome.runtime.lastError?.message || 'Ошибка сохранения';
              showDraftFlowToast('Ошибка сохранения', err, true);
            } else {
              showDraftFlowToast(
                mode === 'selection' ? 'Цитата сохранена в DraftFlow' : 'Статья сохранена в DraftFlow',
                res.title || meta.title
              );
            }
          }
        );
      } catch (err: unknown) {
        showDraftFlowToast('Ошибка сохранения', String(err), true);
      }
    }
  },
});

function showDraftFlowToast(message: string, subtext?: string, isError = false) {
  const existing = document.getElementById('draftflow-toast-container');
  if (existing) existing.remove();

  const container = document.createElement('div');
  container.id = 'draftflow-toast-container';
  container.style.cssText = `
    position: fixed;
    bottom: 24px;
    right: 24px;
    z-index: 2147483647;
    background: #181818;
    color: #ffffff;
    border: 1px solid ${isError ? '#ef4444' : '#333333'};
    box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.5), 0 8px 10px -6px rgba(0, 0, 0, 0.4);
    border-radius: 12px;
    padding: 12px 18px;
    display: flex;
    align-items: center;
    gap: 12px;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    font-size: 13px;
    opacity: 0;
    transform: translateY(12px) scale(0.96);
    transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    max-width: 380px;
    pointer-events: auto;
  `;

  const icon = document.createElement('div');
  icon.style.shrink = '0';
  if (isError) {
    icon.innerHTML = `
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#ef4444" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="10"/>
        <line x1="12" y1="8" x2="12" y2="12"/>
        <line x1="12" y1="16" x2="12.01" y2="16"/>
      </svg>
    `;
  } else {
    const iconUrl = chrome.runtime.getURL('icon-32.png');
    icon.innerHTML = `
      <div style="position:relative;display:inline-flex;align-items:center;justify-content:center;">
        <img src="${iconUrl}" style="width:22px;height:22px;border-radius:5px;display:block;" />
        <span style="position:absolute;bottom:-2px;right:-2px;width:9px;height:9px;border-radius:50%;background:#22c55e;border:1.5px solid #181818;"></span>
      </div>
    `;
  }

  const textWrap = document.createElement('div');
  textWrap.style.overflow = 'hidden';

  const mainText = document.createElement('div');
  mainText.style.fontWeight = '600';
  mainText.style.color = isError ? '#f87171' : '#ffffff';
  mainText.innerText = message;
  textWrap.appendChild(mainText);

  if (subtext) {
    const sub = document.createElement('div');
    sub.style.fontSize = '12px';
    sub.style.color = '#a1a1aa';
    sub.style.marginTop = '2px';
    sub.style.whiteSpace = 'nowrap';
    sub.style.overflow = 'hidden';
    sub.style.textOverflow = 'ellipsis';
    sub.innerText = subtext;
    textWrap.appendChild(sub);
  }

  container.appendChild(icon);
  container.appendChild(textWrap);
  document.body.appendChild(container);

  // Trigger enter animation
  requestAnimationFrame(() => {
    container.style.opacity = '1';
    container.style.transform = 'translateY(0) scale(1)';
  });

  // Auto remove after 3.5s
  setTimeout(() => {
    container.style.opacity = '0';
    container.style.transform = 'translateY(8px) scale(0.96)';
    setTimeout(() => container.remove(), 300);
  }, 3500);
}
