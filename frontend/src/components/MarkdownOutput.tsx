import { useState } from 'react';
import { CopyButton } from './CopyButton';

type MarkdownOutputProps = {
  filename: string;
  markdown: string;
  onReset: () => void;
};

export function MarkdownOutput({ filename, markdown, onReset }: MarkdownOutputProps) {
  const [view, setView] = useState<'raw' | 'preview'>('raw');

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <h2 className="text-sm font-semibold text-gray-700">{filename}</h2>
          <span className="rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-700">
            Converted
          </span>
        </div>

        <div className="flex items-center gap-2">
          <div className="flex rounded-lg border border-gray-200 overflow-hidden text-xs">
            <button
              type="button"
              onClick={() => setView('raw')}
              className={`px-3 py-1.5 font-medium transition-colors ${view === 'raw' ? 'bg-violet-600 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'}`}
            >
              Raw
            </button>
            <button
              type="button"
              onClick={() => setView('preview')}
              className={`px-3 py-1.5 font-medium transition-colors ${view === 'preview' ? 'bg-violet-600 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'}`}
            >
              Preview
            </button>
          </div>
          <CopyButton text={markdown} />
          <button
            type="button"
            onClick={onReset}
            className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50 transition-colors"
          >
            New conversion
          </button>
        </div>
      </div>

      {view === 'raw' ? (
        <pre className="max-h-[60vh] overflow-auto rounded-xl border border-gray-200 bg-gray-50 p-4 text-xs text-gray-700 leading-relaxed whitespace-pre-wrap font-mono">
          {markdown}
        </pre>
      ) : (
        <div
          className="prose prose-sm max-w-none max-h-[60vh] overflow-auto rounded-xl border border-gray-200 bg-white p-6"
          dangerouslySetInnerHTML={{ __html: renderMarkdown(markdown) }}
        />
      )}
    </div>
  );
}

// Minimal markdown → HTML for preview (no external deps)
function renderMarkdown(md: string): string {
  return md
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    // headings
    .replace(/^#{6}\s(.+)$/gm, '<h6>$1</h6>')
    .replace(/^#{5}\s(.+)$/gm, '<h5>$1</h5>')
    .replace(/^#{4}\s(.+)$/gm, '<h4>$1</h4>')
    .replace(/^#{3}\s(.+)$/gm, '<h3>$1</h3>')
    .replace(/^#{2}\s(.+)$/gm, '<h2>$1</h2>')
    .replace(/^#{1}\s(.+)$/gm, '<h1>$1</h1>')
    // bold + italic
    .replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>')
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g, '<em>$1</em>')
    // blockquote
    .replace(/^&gt;\s(.+)$/gm, '<blockquote>$1</blockquote>')
    // horizontal rule
    .replace(/^---$/gm, '<hr />')
    // unordered list items (wrap handled below)
    .replace(/^[-*]\s(.+)$/gm, '<li>$1</li>')
    // paragraphs (double newline)
    .split(/\n\n+/)
    .map((block) => {
      if (/^<(h[1-6]|hr|blockquote|li|ul|ol|table)/.test(block.trim())) return block;
      if (block.trim() === '') return '';
      if (block.includes('<li>')) return `<ul>${block}</ul>`;
      return `<p>${block.replace(/\n/g, '<br />')}</p>`;
    })
    .join('\n');
}
