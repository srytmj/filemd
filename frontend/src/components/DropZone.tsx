import { useRef, useState, type DragEvent, type ChangeEvent } from 'react';

type DropZoneProps = {
  onFiles: (files: File[]) => void;
  disabled?: boolean;
};

export function DropZone({ onFiles, disabled = false }: DropZoneProps) {
  const [dragging, setDragging] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  function handleDragOver(e: DragEvent<HTMLDivElement>): void {
    e.preventDefault();
    if (!disabled) setDragging(true);
  }

  function handleDragLeave(): void {
    setDragging(false);
  }

  function handleDrop(e: DragEvent<HTMLDivElement>): void {
    e.preventDefault();
    setDragging(false);
    if (disabled) return;
    const dropped = Array.from(e.dataTransfer.files);
    if (dropped.length > 0) onFiles(dropped);
  }

  function handleChange(e: ChangeEvent<HTMLInputElement>): void {
    const picked = Array.from(e.target.files ?? []);
    if (picked.length > 0) onFiles(picked);
    e.target.value = '';
  }

  return (
    <div
      role="button"
      tabIndex={0}
      aria-label="Upload files"
      onClick={() => !disabled && inputRef.current?.click()}
      onKeyDown={(e) => e.key === 'Enter' && !disabled && inputRef.current?.click()}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
      className={[
        'flex flex-col items-center justify-center gap-3 rounded-2xl border-2 border-dashed px-8 py-14 text-center transition-colors cursor-pointer select-none',
        dragging
          ? 'border-violet-500 bg-violet-50'
          : 'border-gray-300 hover:border-violet-400 hover:bg-gray-50',
        disabled ? 'opacity-50 pointer-events-none' : '',
      ].join(' ')}
    >
      <svg
        className="h-10 w-10 text-gray-400"
        fill="none"
        stroke="currentColor"
        strokeWidth={1.5}
        viewBox="0 0 24 24"
        aria-hidden="true"
      >
        <path
          strokeLinecap="round"
          strokeLinejoin="round"
          d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"
        />
      </svg>

      <div>
        <p className="text-sm font-medium text-gray-700">
          Drag &amp; drop files here, or{' '}
          <span className="text-violet-600 underline underline-offset-2">browse</span>
        </p>
        <p className="mt-1 text-xs text-gray-400">
          PDF, DOCX, XLSX, PPTX, TXT, MD, CSV &mdash; up to 20 MB each
        </p>
      </div>

      <input
        ref={inputRef}
        type="file"
        multiple
        accept=".pdf,.docx,.xlsx,.pptx,.txt,.md,.csv"
        className="sr-only"
        onChange={handleChange}
        tabIndex={-1}
      />
    </div>
  );
}
