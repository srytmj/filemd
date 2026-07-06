import { useConverter } from './hooks/useConverter';
import { DropZone } from './components/DropZone';
import { FileList } from './components/FileList';
import { MarkdownOutput } from './components/MarkdownOutput';

export default function App() {
  const { files, result, isUploading, addFiles, removeFile, convert, reset } = useConverter();

  const hasFiles = files.length > 0;
  const singleResult = result?.type === 'single' ? result : null;

  return (
    <div className="min-h-screen bg-gray-50 py-12 px-4">
      <div className="mx-auto w-full max-w-2xl flex flex-col gap-8">
        <header className="text-center">
          <h1 className="text-3xl font-bold tracking-tight text-gray-900">
            File to Markdown
          </h1>
          <p className="mt-2 text-sm text-gray-500">
            Convert PDF, DOCX, XLSX, PPTX, TXT, MD, or CSV to clean Markdown.
            Files are deleted immediately after conversion.
          </p>
        </header>

        <main className="flex flex-col gap-6 rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
          {singleResult ? (
            <MarkdownOutput
              filename={singleResult.filename}
              markdown={singleResult.markdown}
              onReset={reset}
            />
          ) : (
            <>
              <DropZone onFiles={addFiles} disabled={isUploading} />
              {hasFiles && (
                <FileList
                  files={files}
                  onRemove={removeFile}
                  onConvert={convert}
                  isUploading={isUploading}
                />
              )}
            </>
          )}
        </main>

        <footer className="text-center text-xs text-gray-400">
          Max 20 MB per file &bull; No data is stored after conversion
        </footer>
      </div>
    </div>
  );
}
