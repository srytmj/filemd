import type { ConvertFile } from '../types';
import { FileItem } from './FileItem';

type FileListProps = {
  files: ConvertFile[];
  onRemove: (id: string) => void;
  onConvert: () => void;
  isUploading: boolean;
};

export function FileList({ files, onRemove, onConvert, isUploading }: FileListProps) {
  const hasQueued = files.some((f) => f.status === 'queued');

  return (
    <div className="flex flex-col gap-4">
      <ul className="flex flex-col gap-2">
        {files.map((item) => (
          <FileItem key={item.id} item={item} onRemove={onRemove} />
        ))}
      </ul>

      {hasQueued && (
        <button
          type="button"
          onClick={onConvert}
          disabled={isUploading}
          className="self-end rounded-xl bg-violet-600 px-6 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-violet-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        >
          {isUploading ? 'Converting…' : `Convert ${files.filter((f) => f.status === 'queued').length} file${files.filter((f) => f.status === 'queued').length === 1 ? '' : 's'}`}
        </button>
      )}
    </div>
  );
}
