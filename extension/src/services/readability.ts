import { Readability } from '@mozilla/readability';
import TurndownService from 'turndown';
import { PageMetadata, ClipMode } from './types';

const turndown = new TurndownService({
  headingStyle: 'atx',
  hr: '---',
  bulletListMarker: '-',
  codeBlockStyle: 'fenced',
});

// Remove noise elements
turndown.remove(['script', 'style', 'noscript', 'nav', 'footer', 'header', 'iframe', 'svg']);

// Avoid dumping huge data-uris into markdown
turndown.addRule('inlineImages', {
  filter: 'img',
  replacement: (content, node) => {
    const el = node as HTMLImageElement;
    const src = el.getAttribute('src') || '';
    const alt = el.getAttribute('alt') || '';
    if (src.startsWith('data:')) {
      return '';
    }
    return `![${alt}](${src})\n\n`;
  },
});

export function extractPageMetadata(doc: Document = document): PageMetadata {
  const url = window.location.href;
  const title =
    doc.querySelector('meta[property="og:title"]')?.getAttribute('content') ||
    doc.title ||
    url;

  const description =
    doc.querySelector('meta[property="og:description"]')?.getAttribute('content') ||
    doc.querySelector('meta[name="description"]')?.getAttribute('content') ||
    '';

  const faviconEl = doc.querySelector('link[rel~="icon"]') as HTMLLinkElement | null;
  const faviconUrl = faviconEl?.href || `${window.location.origin}/favicon.ico`;

  const selection = window.getSelection()?.toString().trim() || undefined;

  return {
    url,
    title,
    description,
    faviconUrl,
    selectedText: selection,
  };
}

export function parseArticleFromDocument(doc: Document = document): {
  title: string;
  markdown: string;
  excerpt: string;
} {
  try {
    const clonedDoc = doc.cloneNode(true) as Document;

    // Remove noise widgets & promo/ad blocks often embedded in article containers (DTF, Habr, etc.)
    const noiseSelectors = [
      '.comments',
      '.recommendations',
      '.advert',
      '.booster',
      '.subscription',
      '.pay4game',
      '[data-recommendations]',
      '[data-advert]',
      '.feed-item',
      '.paywall',
      '.banner',
      'aside',
    ];
    for (const sel of noiseSelectors) {
      clonedDoc.querySelectorAll(sel).forEach((el) => el.remove());
    }

    const reader = new Readability(clonedDoc);
    const article = reader.parse();

    if (!article || !article.content) {
      // Fallback: extract main or article element if present, or body
      const mainEl = doc.querySelector('main, article, [role="main"]') || doc.body;
      return {
        title: doc.title,
        markdown: mainEl ? turndown.turndown(mainEl.innerHTML || '') : '',
        excerpt: '',
      };
    }

    const markdown = turndown.turndown(article.content);

    return {
      title: article.title || doc.title,
      markdown,
      excerpt: article.excerpt || '',
    };
  } catch (err) {
    console.error('Error parsing article with Readability:', err);
    const mainEl = doc.querySelector('main, article, [role="main"]') || doc.body;
    return {
      title: doc.title,
      markdown: mainEl ? turndown.turndown(mainEl.innerHTML || '') : '',
      excerpt: '',
    };
  }
}

export function buildMarkdownForClip(params: {
  mode: ClipMode;
  url: string;
  title: string;
  description?: string;
  selectedText?: string;
  articleMarkdown?: string;
  comment?: string;
  tags?: string[];
  screenshotUrl?: string;
}): string {
  const { mode, url, title, description, selectedText, articleMarkdown, comment, tags, screenshotUrl } = params;
  const parts: string[] = [];

  let domain = '';
  try {
    domain = new URL(url).hostname.replace(/^www\./, '');
  } catch {}

  // Comment / user note
  if (comment && comment.trim()) {
    parts.push('### 💭 Мой комментарий');
    parts.push(comment.trim());
    parts.push('');
  }

  // Tags
  if (tags && tags.length > 0) {
    parts.push(`> 🏷️ ${tags.map(t => `#${t.replace(/^#/, '')}`).join(' ')}`);
    parts.push('');
  }

  // Content body depending on mode
  if (mode === 'article') {
    if (articleMarkdown && articleMarkdown.trim()) {
      parts.push(articleMarkdown);
    } else {
      parts.push('*[Текст статьи не удалось извлечь со страницы. Сохранена ссылка.]*');
    }
  } else if (mode === 'selection') {
    parts.push('### ❝ Цитата');
    if (selectedText && selectedText.trim()) {
      const quoteLines = selectedText.split('\n').map(l => `> ${l}`).join('\n');
      parts.push(quoteLines);
    } else {
      parts.push('> *(Фрагмент текста не был выбран)*');
    }
    parts.push('');
    parts.push(`> 🔗 Источник: [${title}](${url})`);
    parts.push(`> 🌐 [${url}](${url})`);
  } else if (mode === 'bookmark') {
    parts.push(`### 🔖 Закладка`);
    parts.push('');
    parts.push(`🌐 **[${title}](${url})**`);
    parts.push('');
    parts.push(`🔗 [${url}](${url})`);
    if (description && description.trim()) {
      parts.push('');
      parts.push('---');
      parts.push('');
      parts.push(`> 📝 ${description.trim()}`);
    }
  } else if (mode === 'screenshot') {
    parts.push(`### 📸 Снимок экрана`);
    parts.push(`> 🔗 Источник: [${title}](${url})`);
    parts.push(`> 🌐 [${url}](${url})`);
    parts.push('');
    if (screenshotUrl) {
      parts.push(`![Скриншот страницы](${screenshotUrl})`);
    }
  }

  return parts.join('\n');
}
