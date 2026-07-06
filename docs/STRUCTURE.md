# Project Structure

Penjelasan lengkap setiap folder dan file dalam monorepo ini.

```
filemd/
├── docs/                         # Dokumentasi proyek
│   ├── PRD.md                    # Product Requirements Document
│   ├── SRS.md                    # Software Requirements Specification
│   ├── TODO.md                   # Daftar pekerjaan yang belum selesai
│   └── STRUCTURE.md              # File ini
│
├── backend/                      # Laravel 11 — API only
│   ├── app/
│   │   ├── Http/
│   │   │   ├── Controllers/
│   │   │   │   ├── Controller.php          # Base controller (Laravel default)
│   │   │   │   └── ConvertController.php   # Satu-satunya controller; handle POST /api/convert
│   │   │   └── Requests/
│   │   │       └── ConvertRequest.php      # Validasi file: mimes, max 20MB, array files[]
│   │   ├── Services/
│   │   │   ├── ConverterFactory.php        # Resolve converter berdasarkan MIME type
│   │   │   ├── ConvertService.php          # Orchestrator: buat temp file, panggil converter, hapus file
│   │   │   └── Converters/
│   │   │       ├── ConverterInterface.php  # Contract: convert(tmpPath, originalName): string
│   │   │       ├── PdfConverter.php        # PDF → Markdown via smalot/pdfparser
│   │   │       ├── DocxConverter.php       # DOCX → Markdown via phpoffice/phpword
│   │   │       ├── XlsxConverter.php       # XLSX → GFM table via phpoffice/phpspreadsheet
│   │   │       ├── PptxConverter.php       # PPTX → slide sections via phpoffice/phppresentation
│   │   │       ├── CsvConverter.php        # CSV → GFM table via native fgetcsv
│   │   │       └── PlainTextConverter.php  # TXT / MD → dikembalikan apa adanya
│   │   ├── Models/
│   │   │   └── User.php                    # Laravel default, tidak dipakai (no auth)
│   │   └── Providers/
│   │       └── AppServiceProvider.php      # Laravel default
│   │
│   ├── bootstrap/
│   │   ├── app.php                         # Registrasi middleware dan service provider
│   │   └── providers.php                   # Daftar provider yang di-load
│   │
│   ├── config/
│   │   ├── cors.php                        # CORS: allowed_origins pakai env FRONTEND_URL
│   │   ├── app.php                         # Konfigurasi aplikasi Laravel
│   │   ├── cache.php                       # Driver cache (file, tidak dipakai aktif)
│   │   ├── logging.php                     # Channel log (single file)
│   │   └── ...                             # Config Laravel lainnya (tidak dimodifikasi)
│   │
│   ├── database/
│   │   ├── migrations/                     # Migrasi Laravel default (users, cache, jobs)
│   │   │                                   # Tidak dipakai — project ini tidak punya DB
│   │   └── database.sqlite                 # SQLite default untuk testing lokal
│   │
│   ├── public/
│   │   └── index.php                       # Entry point Laravel (semua request masuk sini)
│   │
│   ├── routes/
│   │   ├── api.php                         # POST /api/convert, GET /api/health
│   │   ├── web.php                         # Kosong (no Blade views)
│   │   └── console.php                     # Artisan commands (default)
│   │
│   ├── storage/                            # Laravel runtime storage
│   │   ├── framework/                      # Cache, session, compiled views (auto-generated)
│   │   └── logs/                           # Log aplikasi (laravel.log)
│   │
│   ├── tests/
│   │   ├── Feature/
│   │   │   └── ExampleTest.php             # Placeholder — belum ada feature test
│   │   └── Unit/
│   │       └── ExampleTest.php             # Placeholder — belum ada unit test
│   │
│   ├── .env                                # Environment lokal (tidak di-commit)
│   ├── .env.example                        # Template env untuk server baru
│   ├── artisan                             # Laravel CLI entry point
│   ├── composer.json                       # Dependencies PHP
│   └── phpunit.xml                         # Konfigurasi PHPUnit
│
├── frontend/                     # React 18 + Vite + TypeScript + Tailwind CSS v4
│   ├── src/
│   │   ├── components/
│   │   │   ├── DropZone.tsx        # Area drag & drop + click to browse; handle DragEvent
│   │   │   ├── FileList.tsx        # Daftar file yang di-queue + tombol "Convert N files"
│   │   │   ├── FileItem.tsx        # Satu baris file: nama, ukuran, status badge, progress bar, tombol hapus
│   │   │   ├── MarkdownOutput.tsx  # Tampilkan hasil konversi single file; toggle raw/preview
│   │   │   └── CopyButton.tsx      # Salin markdown ke clipboard; feedback "Copied!" 2 detik
│   │   │
│   │   ├── hooks/
│   │   │   └── useConverter.ts     # Seluruh logika: validasi client-side, state machine,
│   │   │                           # fetch ke API, trigger download untuk multi-file
│   │   │
│   │   ├── types/
│   │   │   └── index.ts            # FileStatus, ConvertFile, ConvertResult
│   │   │
│   │   ├── App.tsx                 # Root component; orkestrasi state dari useConverter
│   │   ├── main.tsx                # Entry point React; mount ke #root
│   │   └── index.css               # Global styles + @import "tailwindcss"
│   │
│   ├── public/
│   │   ├── favicon.svg             # Favicon
│   │   └── icons.svg               # Icon sprite (Vite template default)
│   │
│   ├── dist/                       # Output build Vite (auto-generated, tidak di-commit)
│   │
│   ├── .env                        # VITE_API_URL untuk development lokal
│   ├── .env.example                # Template env
│   ├── index.html                  # HTML shell; Vite inject bundle ke sini
│   ├── vite.config.ts              # Vite config: plugin react + tailwindcss
│   ├── tsconfig.app.json           # TypeScript config untuk src/ (strict mode)
│   ├── tsconfig.node.json          # TypeScript config untuk vite.config.ts
│   └── package.json                # Dependencies dan scripts npm
│
├── deploy.sh                     # Wizard deploy pertama kali ke EC2 / Azure
│                                 # Build backend + frontend, konfigurasi nginx, health check
├── update.sh                     # Pull GitHub terbaru + rebuild + redeploy
│                                 # Dijalankan di server setiap kali ada update kode
│
├── README.md                     # Dokumentasi utama: cara pakai, cara deploy, API reference
└── CLAUDE.md                     # Instruksi untuk Claude Code: constraints, conventions, TODO
```

---

## Alur Request

```
Browser
  │
  ├─► GET  /               → frontend/dist/index.html  (nginx static)
  │
  └─► POST /api/convert    → nginx → php-fpm → Laravel public/index.php
                                                  │
                                          ConvertRequest (validasi)
                                                  │
                                          ConvertController
                                                  │
                                          ConvertService
                                            ├─ tempnam(sys_get_temp_dir())
                                            ├─ ConverterFactory → pilih converter
                                            ├─ Converter::convert()
                                            └─ finally: unlink(tmpPath)
                                                  │
                                          response()->json(...)
```

---

## Environment Variables

### backend/.env

| Key | Contoh | Keterangan |
|-----|--------|------------|
| `APP_ENV` | `production` | Mode Laravel |
| `APP_KEY` | `base64:...` | Enkripsi Laravel, generate via `artisan key:generate` |
| `APP_URL` | `https://api.yourdomain.com` | URL backend |
| `FRONTEND_URL` | `https://yourdomain.com` | Dipakai di CORS config |

### frontend/.env

| Key | Contoh | Keterangan |
|-----|--------|------------|
| `VITE_API_URL` | `https://api.yourdomain.com` | Base URL backend untuk fetch di browser |

---

## File yang Tidak Perlu Diubah

File-file di bawah ini adalah boilerplate Laravel/Vite dan tidak relevan dengan fungsionalitas project:

- `backend/app/Models/User.php` — tidak ada auth
- `backend/database/migrations/*` — tidak ada DB
- `backend/resources/` — tidak ada Blade views
- `backend/routes/web.php` — tidak ada web routes
- `frontend/src/assets/` — gambar placeholder dari template Vite
- `frontend/src/App.css` — CSS lama dari template, tidak dipakai
