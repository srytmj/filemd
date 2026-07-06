# SRS - File to Markdown Converter

## Tech Stack

| Layer | Choice |
|-------|--------|
| Frontend | React 18 + Vite + TypeScript |
| Styling | Tailwind CSS v4 |
| Backend | Laravel 11 (API only) |
| File Processing | PHP libraries per format |
| Hosting | Azure App Service (backend), Azure Static Web Apps (frontend) |
| Tunnel | Cloudflare (DNS + proxy) |
| Database | None (no persistence) |

---

## Project Structure

```
root/
  frontend/           # React + Vite
    src/
      components/
        DropZone.tsx
        FileList.tsx
        MarkdownOutput.tsx
        ProgressBar.tsx
      hooks/
        useConverter.ts
      types/
        index.ts
      App.tsx
      main.tsx
    vite.config.ts
    tailwind.config.ts

  backend/            # Laravel
    app/
      Http/
        Controllers/
          ConvertController.php
        Requests/
          ConvertRequest.php
      Services/
        Converters/
          PdfConverter.php
          DocxConverter.php
          XlsxConverter.php
          PptxConverter.php
          CsvConverter.php
          PlainTextConverter.php
        ConverterFactory.php
        ConvertService.php
    routes/
      api.php
```

---

## API Contract

### POST /api/convert

Accepts one or more files. Returns markdown.

**Request**
```
Content-Type: multipart/form-data

files[]   File[]   required   One or more files, max 20MB each
```

**Response - Single File**
```json
{
  "type": "single",
  "filename": "document.pdf",
  "markdown": "# Document Title\n\nContent here..."
}
```

**Response - Multiple Files**
```json
{
  "type": "multiple",
  "files": [
    {
      "filename": "document.pdf",
      "markdown": "# Document Title\n\nContent here..."
    },
    {
      "filename": "spreadsheet.xlsx",
      "markdown": "## Sheet1\n\n| Col1 | Col2 |\n|------|------|\n| A | B |"
    }
  ]
}
```

**Error Response**
```json
{
  "error": true,
  "message": "File type not supported.",
  "filename": "video.mp4"
}
```

**HTTP Status Codes**
- 200: Success
- 422: Validation failed (size, type)
- 500: Conversion failed

---

## File Type Support

| Extension | MIME Type | Library |
|-----------|-----------|---------|
| .pdf | application/pdf | `smalot/pdfparser` |
| .docx | application/vnd.openxmlformats-officedocument.wordprocessingml.document | `phpoffice/phpword` |
| .xlsx | application/vnd.openxmlformats-officedocument.spreadsheetml.sheet | `phpoffice/phpspreadsheet` |
| .pptx | application/vnd.openxmlformats-officedocument.presentationml.presentation | `phpoffice/phpspreadsheet` |
| .txt | text/plain | native |
| .md | text/markdown | native |
| .csv | text/csv | native (str_getcsv) |

---

## Security Spec

### File Lifecycle

```
Upload -> Store in sys_get_temp_dir() -> Convert -> Build response -> Delete temp file -> Return response
```

- Use `sys_get_temp_dir()`, not `storage/app`
- Delete in `finally` block so deletion runs even on exception
- Never store file content in database
- Never log filename or file content

### Validation (Server)

```php
'files.*' => [
    'required',
    'file',
    'max:20480',  // 20MB in KB
    'mimes:pdf,docx,xlsx,pptx,txt,md,csv',
]
```

### Validation (Client)

- Max size: 20MB per file
- Allowed extensions: pdf, docx, xlsx, pptx, txt, md, csv
- Validate before upload, show error inline per file
- Do not block UI for other valid files

### Headers (Laravel)

```php
// cors.php
'allowed_origins' => [env('FRONTEND_URL')],
'allowed_methods' => ['POST'],
'allowed_headers' => ['Content-Type'],
```

---

## Frontend State Machine

```
idle
  -> dragging (user drags file over zone)
  -> selected (files added to queue)
    -> uploading (POST fired)
      -> success_single (1 file, show inline)
      -> success_multiple (n files, trigger download)
      -> error (per file or global)
  -> reset (user clears or uploads again)
```

---

## Markdown Output Rules

### PDF
- Extract text per page
- H1 for document title if detectable
- Page breaks as `---`

### DOCX
- Map heading styles to `#`, `##`, `###`
- Bold, italic preserved
- Tables as GFM tables
- Images skipped (note: `[image omitted]`)

### XLSX
- Each sheet as `## Sheet Name`
- Data as GFM table
- Empty cells as empty string in table

### PPTX
- Each slide as `## Slide N: Title`
- Bullet points as unordered list
- Speaker notes as blockquote

### CSV
- Full content as GFM table
- First row as header

### TXT / MD
- Return as-is (TXT wrapped in plain block if needed)

---

## Deployment

### Backend (Azure App Service)
- PHP 8.3
- Env vars: `APP_ENV=production`, `FRONTEND_URL=https://yourdomain.com`
- No queue, no DB, no cache driver needed
- Health check endpoint: `GET /api/health` returns `{"status":"ok"}`

### Frontend (Azure Static Web Apps)
- Build: `vite build`
- Output: `dist/`
- Env: `VITE_API_URL=https://api.yourdomain.com`

### Cloudflare
- Proxy both frontend and backend domains
- Force HTTPS
- Set max upload size to 20MB (Free plan default is 100MB, no change needed)

---

## Acceptance Criteria

| Feature | Criteria |
|---------|----------|
| Upload | Drag and drop works. Click to browse works. |
| Validation | Files over 20MB rejected client-side before upload. |
| Single file | Markdown shown inline. Copy button works. |
| Multiple files | `.md` file downloaded automatically after conversion. |
| File deletion | Temp file deleted in `finally` block server-side. |
| Error | Per-file error shown without blocking other files. |
| Security | No file content in logs, DB, or storage after response. |
