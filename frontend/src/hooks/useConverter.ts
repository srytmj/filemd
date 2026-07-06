import { useState, useCallback } from 'react';
import type { ConvertFile, ConvertResult } from '../types';

const MAX_SIZE_BYTES = 20 * 1024 * 1024;
const ALLOWED_EXTENSIONS = ['pdf', 'docx', 'xlsx', 'pptx', 'txt', 'md', 'csv'];
const ALLOWED_MIME_TYPES = [
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain',
  'text/markdown',
  'text/csv',
];

function validateFile(file: File): string | null {
  const ext = file.name.split('.').pop()?.toLowerCase() ?? '';
  if (!ALLOWED_EXTENSIONS.includes(ext)) {
    return `Unsupported format (.${ext}). Allowed: ${ALLOWED_EXTENSIONS.join(', ')}`;
  }
  if (!ALLOWED_MIME_TYPES.includes(file.type) && file.type !== '') {
    return `Unsupported file type.`;
  }
  if (file.size > MAX_SIZE_BYTES) {
    return `File exceeds 20 MB limit.`;
  }
  return null;
}

function buildId(): string {
  return Math.random().toString(36).slice(2);
}

type UseConverterReturn = {
  files: ConvertFile[];
  result: ConvertResult | null;
  isUploading: boolean;
  addFiles: (incoming: File[]) => void;
  removeFile: (id: string) => void;
  convert: () => Promise<void>;
  reset: () => void;
};

export function useConverter(): UseConverterReturn {
  const [files, setFiles] = useState<ConvertFile[]>([]);
  const [result, setResult] = useState<ConvertResult | null>(null);
  const [isUploading, setIsUploading] = useState(false);

  const addFiles = useCallback((incoming: File[]) => {
    const next: ConvertFile[] = incoming.map((file) => {
      const error = validateFile(file) ?? undefined;
      return { id: buildId(), file, status: error ? 'error' : 'queued', error };
    });
    setFiles((prev) => [...prev, ...next]);
  }, []);

  const removeFile = useCallback((id: string) => {
    setFiles((prev) => prev.filter((f) => f.id !== id));
  }, []);

  const reset = useCallback(() => {
    setFiles([]);
    setResult(null);
  }, []);

  const convert = useCallback(async () => {
    const valid = files.filter((f) => f.status === 'queued');
    if (valid.length === 0) return;

    setIsUploading(true);
    setFiles((prev) =>
      prev.map((f) => (f.status === 'queued' ? { ...f, status: 'uploading' } : f))
    );

    const formData = new FormData();
    valid.forEach((f) => formData.append('files[]', f.file));

    try {
      const res = await fetch(`${import.meta.env.VITE_API_URL}/api/convert`, {
        method: 'POST',
        body: formData,
      });

      if (!res.ok) {
        const json = await res.json().catch(() => ({}));
        throw new Error(json.message ?? `Server error ${res.status}`);
      }

      const data: ConvertResult = await res.json();

      setFiles((prev) =>
        prev.map((f) => (f.status === 'uploading' ? { ...f, status: 'done' } : f))
      );
      setResult(data);

      if (data.type === 'multiple') {
        triggerDownload(data.files);
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Upload failed.';
      setFiles((prev) =>
        prev.map((f) =>
          f.status === 'uploading' ? { ...f, status: 'error', error: message } : f
        )
      );
    } finally {
      setIsUploading(false);
    }
  }, [files]);

  return { files, result, isUploading, addFiles, removeFile, convert, reset };
}

function triggerDownload(files: { filename: string; markdown: string }[]): void {
  const content = files
    .map((f) => `# ${f.filename}\n\n${f.markdown}`)
    .join('\n\n---\n\n');

  const blob = new Blob([content], { type: 'text/markdown' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'converted.md';
  a.click();
  URL.revokeObjectURL(url);
}
