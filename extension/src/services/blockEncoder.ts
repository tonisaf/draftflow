import { DraftFlowBlock } from './types';

// Simple order key generator ('a0', 'a1', 'a2', ...)
export function makeOrderKey(index: number): string {
  return 'a' + index.toString(36).padStart(4, '0');
}

export function generateUuid(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/**
 * Parses inline markdown links [text](url), bold, italic, code and strikethrough into Delta attributes
 */
function parseInlineDelta(text: string): Array<{ insert: string; attributes?: Record<string, unknown> }> {
  if (!text) return [{ insert: '' }];

  const runs: Array<{ insert: string; attributes?: Record<string, unknown> }> = [];
  const tokenRegex = /(\[([^\]]+)\]\(([^)]+)\)|\*\*\*([^*]+)\*\*\*|\*\*([^*]+)\*\*|\*([^*]+)\*|`([^`]+)`|~~([^~]+)~~)/g;

  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = tokenRegex.exec(text)) !== null) {
    if (match.index > lastIndex) {
      runs.push({ insert: text.substring(lastIndex, match.index) });
    }

    if (match[2] && match[3]) {
      // Link [text](url)
      runs.push({
        insert: match[2],
        attributes: { href: match[3] },
      });
    } else if (match[4]) {
      // Bold + Italic
      runs.push({
        insert: match[4],
        attributes: { bold: true, italic: true },
      });
    } else if (match[5]) {
      // Bold **text**
      runs.push({
        insert: match[5],
        attributes: { bold: true },
      });
    } else if (match[6]) {
      // Italic *text*
      runs.push({
        insert: match[6],
        attributes: { italic: true },
      });
    } else if (match[7]) {
      // Inline code `text`
      runs.push({
        insert: match[7],
        attributes: { code: true },
      });
    } else if (match[8]) {
      // Strikethrough ~~text~~
      runs.push({
        insert: match[8],
        attributes: { strikethrough: true },
      });
    }

    lastIndex = match.index + match[0].length;
  }

  if (lastIndex < text.length) {
    runs.push({ insert: text.substring(lastIndex) });
  }

  if (runs.length === 0) {
    runs.push({ insert: text });
  }

  return runs;
}

/**
 * Converts markdown text into structured AppFlowy blocks for DraftFlow.
 */
export function markdownToDraftFlowBlocks(markdown: string, pageId: string): DraftFlowBlock[] {
  const lines = markdown.split(/\r?\n/);
  const blocks: DraftFlowBlock[] = [];

  let inCodeBlock = false;
  let codeLang = '';
  let codeLines: string[] = [];

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    if (trimmed.startsWith('```')) {
      if (!inCodeBlock) {
        inCodeBlock = true;
        codeLang = trimmed.substring(3).trim();
        codeLines = [];
      } else {
        inCodeBlock = false;
        blocks.push({
          id: generateUuid(),
          page_id: pageId,
          parent_id: null,
          type: 'code',
          content: JSON.stringify({
            type: 'code',
            data: {
              language: codeLang || 'text',
              delta: [{ insert: codeLines.join('\n') }],
            },
          }),
          order_key: makeOrderKey(blocks.length),
          trashed_at: null,
          trash_batch_id: null,
        });
      }
      continue;
    }

    if (inCodeBlock) {
      codeLines.push(line);
      continue;
    }

    if (trimmed.length === 0) continue;

    // Horizontal rule / Divider
    if (/^(\-{3,}|\*{3,}|_{3,})$/.test(trimmed)) {
      blocks.push({
        id: generateUuid(),
        page_id: pageId,
        parent_id: null,
        type: 'divider',
        content: JSON.stringify({
          type: 'divider',
          data: {},
        }),
        order_key: makeOrderKey(blocks.length),
        trashed_at: null,
        trash_batch_id: null,
      });
      continue;
    }

    // Image: ![alt](url)
    const imgMatch = /^!\[([^\]]*)\]\(([^)]+)\)$/.exec(trimmed);
    if (imgMatch) {
      blocks.push({
        id: generateUuid(),
        page_id: pageId,
        parent_id: null,
        type: 'image',
        content: JSON.stringify({
          type: 'image',
          data: {
            url: imgMatch[2],
          },
        }),
        order_key: makeOrderKey(blocks.length),
        trashed_at: null,
        trash_batch_id: null,
      });
      continue;
    }

    // Headings
    if (trimmed.startsWith('# ')) {
      blocks.push(createBlock(pageId, 'heading', {
        level: 1,
        delta: parseInlineDelta(trimmed.substring(2).trim()),
      }, blocks.length));
      continue;
    }
    if (trimmed.startsWith('## ')) {
      blocks.push(createBlock(pageId, 'heading', {
        level: 2,
        delta: parseInlineDelta(trimmed.substring(3).trim()),
      }, blocks.length));
      continue;
    }
    if (trimmed.startsWith('### ')) {
      blocks.push(createBlock(pageId, 'heading', {
        level: 3,
        delta: parseInlineDelta(trimmed.substring(4).trim()),
      }, blocks.length));
      continue;
    }

    // Quote
    if (trimmed.startsWith('>')) {
      const quoteText = trimmed.replace(/^>\s*/, '').trim();
      if (quoteText.length > 0) {
        blocks.push(createBlock(pageId, 'quote', {
          delta: parseInlineDelta(quoteText),
        }, blocks.length));
      }
      continue;
    }

    // Bulleted list
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      blocks.push(createBlock(pageId, 'bulleted_list', {
        delta: parseInlineDelta(trimmed.substring(2).trim()),
      }, blocks.length));
      continue;
    }

    // Numbered list
    const numMatch = /^\d+\.\s+(.*)$/.exec(trimmed);
    if (numMatch) {
      blocks.push(createBlock(pageId, 'numbered_list', {
        delta: parseInlineDelta(numMatch[1]),
      }, blocks.length));
      continue;
    }

    // Todo / Checkbox
    if (trimmed.startsWith('- [ ] ')) {
      blocks.push(createBlock(pageId, 'todo_list', {
        check: false,
        delta: parseInlineDelta(trimmed.substring(6)),
      }, blocks.length));
      continue;
    }
    if (trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ')) {
      blocks.push(createBlock(pageId, 'todo_list', {
        check: true,
        delta: parseInlineDelta(trimmed.substring(6)),
      }, blocks.length));
      continue;
    }

    // Standard paragraph
    blocks.push(createBlock(pageId, 'paragraph', {
      delta: parseInlineDelta(line),
    }, blocks.length));
  }

  // Handle open code block at the end if any
  if (inCodeBlock && codeLines.length > 0) {
    blocks.push({
      id: generateUuid(),
      page_id: pageId,
      parent_id: null,
      type: 'code',
      content: JSON.stringify({
        type: 'code',
        data: {
          language: codeLang || 'text',
          delta: [{ insert: codeLines.join('\n') }],
        },
      }),
      order_key: makeOrderKey(blocks.length),
      trashed_at: null,
      trash_batch_id: null,
    });
  }

  return blocks;
}

function createBlock(
  pageId: string,
  type: string,
  data: Record<string, unknown>,
  index: number
): DraftFlowBlock {
  return {
    id: generateUuid(),
    page_id: pageId,
    parent_id: null,
    type,
    content: JSON.stringify({ type, data }),
    order_key: makeOrderKey(index),
    trashed_at: null,
    trash_batch_id: null,
  };
}
