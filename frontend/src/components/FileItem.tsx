import type { ConvertFile } from '../types';

type FileItemProps = {
  item: ConvertFile;
  onRemove: (id: string) => void;
};

const STATUS_LABEL: Record<string, string> = {
  queued: 'Queued',
  uploading: 'Converting…',
  done: 'Done',
  error: 'Error',
};

const STATUS_COLOR: Record<string, string> = {
  queued: 'text-gray-500',
  uploading: 'text-violet-600',
  done: 'text-green-600',
  error: 'text-red-600',
};

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function FileItem({ item, onRemove }: FileItemProps) {
  const canRemove = item.status !== 'uploading';

  return (
    <li className="flex items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-3">
      <FileIcon ext={item.file.name.split('.').pop() ?? ''} />

      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium text-gray-800">{item.file.name}</p>
        <div className="flex items-center gap-2 mt-0.5">
          <span className="text-xs text-gray-400">{formatBytes(item.file.size)}</span>
          <span className="text-gray-300 text-xs">·</span>
          <span className={`text-xs font-medium ${STATUS_COLOR[item.status]}`}>
            {STATUS_LABEL[item.status]}
          </span>
        </div>
        {item.status === 'uploading' && (
          <div className="mt-1.5 h-1 w-full overflow-hidden rounded-full bg-gray-100">
            <div className="h-full w-full origin-left animate-pulse bg-violet-500 rounded-full" />
          </div>
        )}
        {item.status === 'error' && item.error && (
          <p className="mt-0.5 text-xs text-red-500">{item.error}</p>
        )}
      </div>

      {canRemove && (
        <button
          type="button"
          aria-label={`Remove ${item.file.name}`}
          onClick={() => onRemove(item.id)}
          className="shrink-0 rounded-lg p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600 transition-colors"
        >
          <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} viewBox="0 0 24 24" aria-hidden="true">
            <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      )}
    </li>
  );
}

function FileIcon({ ext }: { ext: string }) {
  const colors: Record<string, string> = {
    pdf: 'bg-red-50 text-red-600',
    docx: 'bg-blue-50 text-blue-600',
    xlsx: 'bg-green-50 text-green-600',
    pptx: 'bg-orange-50 text-orange-600',
    csv: 'bg-emerald-50 text-emerald-600',
    txt: 'bg-gray-50 text-gray-600',
    md: 'bg-violet-50 text-violet-600',
  };
  const color = colors[ext.toLowerCase()] ?? 'bg-gray-50 text-gray-500';

  return (
    <span className={`shrink-0 rounded-lg px-2 py-1 text-xs font-bold uppercase tracking-wide ${color}`}>
      {ext || '?'}
    </span>
  );
}
