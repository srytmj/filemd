# CLAUDE.md - File to Markdown Converter

## Project Overview

A web tool that converts uploaded files (PDF, DOCX, XLSX, PPTX, TXT, MD, CSV) into markdown format.
Files are deleted immediately after conversion. No database. No auth.

## Monorepo Structure

```
/
  frontend/   React + Vite + TypeScript + Tailwind
  backend/    Laravel 11 API only
```

---

## Backend (Laravel)

### Constraints

- API only. No Blade views. No sessions. No queues.
- No database. No migrations needed.
- No file storage in `storage/app`. Use `sys_get_temp_dir()` only.
- Always delete temp file in `finally` block.
- Never log filename, file content, or user IP.
- Return JSON only. All responses go through `response()->json()`.

### Commands

```bash
cd backend
composer install
php artisan serve
php artisan test
```

### Required Packages

```bash
composer require smalot/pdfparser
composer require phpoffice/phpword
composer require phpoffice/phpspreadsheet
```

### File Lifecycle Rule

Every converter MUST follow this pattern:

```php
$tmpPath = tempnam(sys_get_temp_dir(), 'convert_');
try {
    file_put_contents($tmpPath, $file->getContent());
    $markdown = $this->parse($tmpPath);
} finally {
    if (file_exists($tmpPath)) {
        unlink($tmpPath);
    }
}
return $markdown;
```

### Route

```php
// routes/api.php
Route::post('/convert', [ConvertController::class, 'handle']);
Route::get('/health', fn() => response()->json(['status' => 'ok']));
```

### Validation

```php
'files.*' => ['required', 'file', 'max:20480', 'mimes:pdf,docx,xlsx,pptx,txt,md,csv']
```

### Response Shape

Single file:
```json
{ "type": "single", "filename": "x.pdf", "markdown": "..." }
```

Multiple files:
```json
{ "type": "multiple", "files": [{ "filename": "...", "markdown": "..." }] }
```

Error:
```json
{ "error": true, "message": "...", "filename": "..." }
```

### Converter Structure

- `app/Services/Converters/PdfConverter.php`
- `app/Services/Converters/DocxConverter.php`
- `app/Services/Converters/XlsxConverter.php`
- `app/Services/Converters/PptxConverter.php`
- `app/Services/Converters/CsvConverter.php`
- `app/Services/Converters/PlainTextConverter.php`
- `app/Services/ConverterFactory.php` - resolves converter by MIME type
- `app/Services/ConvertService.php` - orchestrates, calls factory

Each converter implements:
```php
interface ConverterInterface {
    public function convert(string $tmpPath, string $originalName): string;
}
```

---

## Frontend (React + Vite)

### Constraints

- TypeScript strict mode.
- Tailwind CSS v4 only. No CSS modules. No inline styles.
- No UI component library (no shadcn, no MUI).
- All validation done before upload (size, type).
- Use `fetch` for API calls. No axios.
- Environment variable: `VITE_API_URL` for backend base URL.

### Commands

```bash
cd frontend
npm install
npm run dev
npm run build
npm run lint
```

### Component Structure

```
src/
  components/
    DropZone.tsx       # drag and drop + click to browse
    FileList.tsx       # list of queued files with status
    FileItem.tsx       # single file row with progress/error/remove
    MarkdownOutput.tsx # inline display for single file result
    CopyButton.tsx     # copy to clipboard
  hooks/
    useConverter.ts    # upload logic, state management
  types/
    index.ts           # shared types
  App.tsx
  main.tsx
```

### Types

```typescript
type FileStatus = 'queued' | 'uploading' | 'done' | 'error';

type ConvertFile = {
  id: string;
  file: File;
  status: FileStatus;
  error?: string;
};

type ConvertResult =
  | { type: 'single'; filename: string; markdown: string }
  | { type: 'multiple'; files: { filename: string; markdown: string }[] };
```

### Behavior Rules

- Single file result: show `MarkdownOutput` inline with copy button.
- Multiple files result: auto-trigger download of combined `.md` file.
- Combined file format: each section prefixed with `# filename.ext`, separated by `---`.
- Validation errors shown per file, do not block valid files.
- After result shown, allow user to reset and upload again.

### API Call

```typescript
const formData = new FormData();
files.forEach(f => formData.append('files[]', f.file));

const res = await fetch(`${import.meta.env.VITE_API_URL}/api/convert`, {
  method: 'POST',
  body: formData,
});
```

---

## Do Not

- Do not add authentication or sessions.
- Do not store file content anywhere (DB, cache, storage).
- Do not log filenames or file content.
- Do not use Laravel queues or jobs.
- Do not add a database.
- Do not add Redux, Zustand, or any global state library. Use React state + hooks only.
- Do not use any CSS framework other than Tailwind.
- Do not add `console.log` in production code.

## Code Style

- Laravel: PSR-12, type hints on all methods, no `var_dump`.
- React: functional components only, explicit return types on hooks.
- Commit messages: conventional commits (`feat:`, `fix:`, `chore:`).
