import React, { useState } from 'react';
import { Copy, Check, ExternalLink } from 'lucide-react';

export interface ParsedBlock {
  id: string;
  type: string;
  data: Record<string, any>;
  order_key: string;
}

export function renderDelta(delta?: Array<{ insert?: string; attributes?: Record<string, any> }>) {
  if (!delta || !Array.isArray(delta)) return null;

  return delta.map((item, idx) => {
    const text = item.insert || '';
    const attrs = item.attributes || {};

    let content: React.ReactNode = text;

    if (attrs.code) {
      content = (
        <code key={idx} className="px-1.5 py-0.5 rounded-inner bg-black/5 dark:bg-white/10 text-accent dark:text-blue-400 font-mono text-[11px]">
          {content}
        </code>
      );
    }
    if (attrs.bold) {
      content = <strong key={idx} className="font-semibold text-df-text-light dark:text-df-text-dark">{content}</strong>;
    }
    if (attrs.italic) {
      content = <em key={idx}>{content}</em>;
    }
    if (attrs.underline) {
      content = <u key={idx}>{content}</u>;
    }
    if (attrs.strikethrough) {
      content = <s key={idx}>{content}</s>;
    }
    if (attrs.href) {
      content = (
        <a
          key={idx}
          href={attrs.href}
          target="_blank"
          rel="noopener noreferrer"
          className="text-accent hover:underline inline-flex items-center gap-0.5 font-medium"
        >
          {content}
          <ExternalLink className="w-2.5 h-2.5 opacity-60 inline" />
        </a>
      );
    }

    return <React.Fragment key={idx}>{content}</React.Fragment>;
  });
}

export function CodeBlock({ code, language }: { code: string; language?: string }) {
  const [copied, setCopied] = useState(false);

  function copyCode() {
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  return (
    <div className="relative group my-2.5 rounded-control overflow-hidden bg-df-card-light dark:bg-df-card-dark border border-df-divider-light dark:border-df-divider-dark text-df-text-light dark:text-df-text-dark text-xs font-mono shadow-sm">
      <div className="flex items-center justify-between px-3 py-1.5 bg-black/[0.03] dark:bg-black/20 border-b border-df-divider-light dark:border-df-divider-dark text-[10px] text-df-muted-light dark:text-df-muted-dark">
        <span className="font-medium tracking-wide uppercase">{language || 'text'}</span>
        <button
          onClick={copyCode}
          className="flex items-center gap-1 hover:text-df-text-light dark:hover:text-df-text-dark transition py-0.5 px-1.5 rounded hover:bg-black/5 dark:hover:bg-white/10"
        >
          {copied ? <Check className="w-3 h-3 text-emerald-500" /> : <Copy className="w-3 h-3" />}
          <span>{copied ? 'Скопировано' : 'Копировать'}</span>
        </button>
      </div>
      <pre className="p-3 overflow-x-auto text-[11.5px] leading-relaxed selection:bg-accent/30 font-mono">
        <code>{code}</code>
      </pre>
    </div>
  );
}

export default function BlockRenderer({ block }: { block: ParsedBlock }) {
  const { type, data } = block;

  switch (type) {
    case 'heading': {
      const level = data.level || 1;
      const content = renderDelta(data.delta);
      if (level === 1) {
        return <h1 className="text-sm font-bold mt-4 mb-2 text-df-text-light dark:text-df-text-dark border-b border-df-divider-light dark:border-df-divider-dark pb-1 tracking-tight">{content}</h1>;
      }
      if (level === 2) {
        return <h2 className="text-xs font-semibold mt-3 mb-1.5 text-df-text-light dark:text-df-text-dark tracking-tight">{content}</h2>;
      }
      return <h3 className="text-[11px] font-semibold mt-2.5 mb-1 text-df-muted-light dark:text-df-muted-dark uppercase tracking-wider">{content}</h3>;
    }

    case 'quote': {
      return (
        <blockquote className="my-2.5 pl-3 py-1 border-l-2 border-accent text-xs italic text-df-muted-light dark:text-df-muted-dark bg-accent/5 rounded-r">
          {renderDelta(data.delta)}
        </blockquote>
      );
    }

    case 'bulleted_list': {
      return (
        <div className="flex items-start gap-2 my-0.5 text-xs text-df-text-light dark:text-df-text-dark pl-1">
          <span className="text-accent mt-1 text-[7px] select-none">•</span>
          <div className="flex-1 leading-relaxed">{renderDelta(data.delta)}</div>
        </div>
      );
    }

    case 'numbered_list': {
      return (
        <div className="flex items-start gap-2 my-0.5 text-xs text-df-text-light dark:text-df-text-dark pl-1">
          <span className="text-df-muted-light dark:text-df-muted-dark font-mono text-[11px] select-none">{data.number || '1'}.</span>
          <div className="flex-1 leading-relaxed">{renderDelta(data.delta)}</div>
        </div>
      );
    }

    case 'todo_list': {
      const checked = Boolean(data.check);
      return (
        <div className="flex items-start gap-2 my-1 text-xs text-df-text-light dark:text-df-text-dark pl-1">
          <input
            type="checkbox"
            checked={checked}
            readOnly
            className="mt-0.5 rounded-sm border-df-divider-light dark:border-df-divider-dark text-accent focus:ring-0 cursor-default"
          />
          <span className={`flex-1 leading-relaxed ${checked ? 'line-through text-df-faint-light dark:text-df-faint-dark' : ''}`}>
            {renderDelta(data.delta)}
          </span>
        </div>
      );
    }

    case 'code': {
      const codeText = data.delta?.map((d: any) => d.insert || '').join('') || '';
      return <CodeBlock code={codeText} language={data.language} />;
    }

    case 'image': {
      const url = data.url || '';
      if (!url) return null;
      return (
        <div className="my-3 rounded-card overflow-hidden border border-df-divider-light dark:border-df-divider-dark bg-df-surfaceSubtle-light dark:bg-df-card-dark shadow-sm">
          <img
            src={url}
            alt="Page attachment"
            className="w-full object-contain max-h-64"
            loading="lazy"
          />
        </div>
      );
    }

    case 'paragraph':
    default: {
      const content = renderDelta(data.delta);
      if (!content || (Array.isArray(data.delta) && data.delta.length === 0)) {
        return <div className="h-2" />;
      }
      return <p className="text-xs leading-relaxed my-1.5 text-df-text-light dark:text-df-text-dark">{content}</p>;
    }
  }
}
