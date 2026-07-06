export type FileStatus = 'queued' | 'uploading' | 'done' | 'error';

export type ConvertFile = {
  id: string;
  file: File;
  status: FileStatus;
  error?: string;
};

export type ConvertResult =
  | { type: 'single'; filename: string; markdown: string }
  | { type: 'multiple'; files: { filename: string; markdown: string }[] };
