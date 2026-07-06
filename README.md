# filemd

A fast, zero-friction web tool that converts uploaded documents into clean Markdown — ready for AI workflows, note-taking, or any Markdown-first pipeline.

**No login. No database. No file retention.** Every file is deleted from the server immediately after conversion.

## Docs

| Document | Description |
|----------|-------------|
| [docs/PRD.md](docs/PRD.md) | Product Requirements — problem, user stories, features, success metrics |
| [docs/SRS.md](docs/SRS.md) | Software Requirements — tech stack, API contract, security spec, deployment |
| [docs/STRUCTURE.md](docs/STRUCTURE.md) | Full file structure with explanation of every folder and file |
| [docs/TODO.md](docs/TODO.md) | Planned work and known gaps |
| [SESSION-PROMPTS.md](SESSION-PROMPTS.md) | Copy-paste prompts for PM / DEV / QA Claude Code sessions |

---

## Features

- **Drag & drop** upload zone with click-to-browse fallback
- **Multi-file support** — upload several files at once
- **7 formats supported:** PDF, DOCX, XLSX, PPTX, TXT, MD, CSV
- **20 MB per file** limit, validated on both client and server
- **Single file** → Markdown shown inline with raw/preview toggle and copy button
- **Multiple files** → auto-downloads a single combined `.md` file
- Per-file error display — invalid files don't block valid ones
- Files deleted in a `finally` block — never stored, never logged

---

## Markdown Output Format

| Format | Output |
|--------|--------|
| PDF | Text extracted per page, separated by `---`. Title as `# H1` if detectable. |
| DOCX | Headings → `#` `##` `###`, bold/italic preserved, tables as GFM, images skipped (`[image omitted]`) |
| XLSX | Each sheet as `## Sheet Name` + GFM table |
| PPTX | Each slide as `## Slide N: Title`, bullets as list, speaker notes as blockquote |
| CSV | First row as header, full content as GFM table |
| TXT / MD | Returned as-is |

---

## Tech Stack

| Layer | Choice |
|-------|--------|
| Frontend | React 18 + Vite + TypeScript + Tailwind CSS v4 |
| Backend | Laravel 11 (API only — no Blade, no DB, no queues) |
| PDF | `smalot/pdfparser` |
| DOCX | `phpoffice/phpword` |
| XLSX / PPTX | `phpoffice/phpspreadsheet`, `phpoffice/phppresentation` |
| Hosting | EC2 / any Linux VM |

---

## Project Structure

```
filemd/
  backend/                  # Laravel 11 API
    app/
      Http/
        Controllers/
          ConvertController.php
        Requests/
          ConvertRequest.php
      Services/
        Converters/
          ConverterInterface.php
          PdfConverter.php
          DocxConverter.php
          XlsxConverter.php
          PptxConverter.php
          CsvConverter.php
          PlainTextConverter.php
        ConverterFactory.php
        ConvertService.php
    routes/
      api.php               # POST /api/convert, GET /api/health
  frontend/                 # React + Vite
    src/
      components/
        DropZone.tsx
        FileList.tsx
        FileItem.tsx
        MarkdownOutput.tsx
        CopyButton.tsx
      hooks/
        useConverter.ts
      types/
        index.ts
      App.tsx
  scripts/
    deploy.sh               # First-time deploy wizard
    update.sh               # Pull latest + rebuild + redeploy
  docs/
    PRD.md
    SRS.md
    STRUCTURE.md
    TODO.md
    tickets/                # TASK-XXX.md per feature ticket
      bugs/                 # BUG-XXX.md per bug ticket
  .claude/
    CLAUDE.md               # Project instructions for Claude Code
    agents/
      PM.md                 # PM session persona
      DEV.md                # DEV session persona
      QA.md                 # QA session persona
  Makefile                  # make sync / make update / make deploy
  sync.sh                   # Sync stack from SRS into .claude/CLAUDE.md
  SESSION-PROMPTS.md        # Copy-paste prompts for each Claude session
```

---

## API

### `POST /api/convert`

**Request:** `multipart/form-data`, field `files[]`, max 20 MB per file.

**Response — single file:**
```json
{ "type": "single", "filename": "doc.pdf", "markdown": "# Title\n\nContent..." }
```

**Response — multiple files:**
```json
{
  "type": "multiple",
  "files": [
    { "filename": "doc.pdf", "markdown": "..." },
    { "filename": "sheet.xlsx", "markdown": "..." }
  ]
}
```

**Error:**
```json
{ "error": true, "message": "File type not supported.", "filename": "video.mp4" }
```

### `GET /api/health`
```json
{ "status": "ok" }
```

---

## Local Development

### Prerequisites

- PHP 8.2+
- Composer
- Node.js 18+
- npm

### Backend

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
php artisan serve
# → http://localhost:8000
```

### Frontend

```bash
cd frontend
npm install
cp .env.example .env          # set VITE_API_URL=http://localhost:8000
npm run dev
# → http://localhost:5173
```

### Environment Variables

**backend/.env** (key ones):
```env
APP_ENV=local
APP_URL=http://localhost:8000
FRONTEND_URL=http://localhost:5173
```

**frontend/.env:**
```env
VITE_API_URL=http://localhost:8000
```

---

## Deployment

### Requirements on the server

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y php8.2 php8.2-fpm php8.2-cli php8.2-xml php8.2-mbstring \
  php8.2-zip php8.2-curl php8.2-gd nginx git unzip curl

# Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

---

### Option A — AWS EC2

1. **Launch instance:** Ubuntu 22.04, t2.micro (free tier) or t3.small for heavier PDFs. Open ports 22, 80, 443.

2. **SSH and clone:**
```bash
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
git clone https://github.com/your-username/filemd.git
cd filemd
```

3. **Run deploy wizard:**
```bash
make deploy
```
The wizard will ask for your domain/IP, build both backend and frontend, configure nginx, and run a health check.

4. **Point your domain** (or use the EC2 public IP directly) to the instance. If using Cloudflare, enable proxy and force HTTPS.

5. **HTTPS with Let's Encrypt** (if using a domain):
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

---

### Option B — Azure App Service + Static Web Apps

1. **Create resources in Azure Portal:**
   - App Service (PHP 8.2, Linux) for backend
   - Static Web App for frontend

2. **SSH into a temporary VM or use Azure Cloud Shell, clone the repo, then run:**
```bash
make deploy
```
The wizard will ask for your Azure subscription, resource group, App Service name, and Static Web App name — then build, package, and deploy both.

3. **Set CORS** — the wizard writes `FRONTEND_URL` to App Service settings automatically.

4. **Cloudflare** — add both backend and frontend domains as proxied records, enable HTTPS.

---

### Updating After First Deploy

Pull latest dari GitHub, rebuild everything, dan redeploy:

```bash
make update
```

This will:
1. `git fetch` + `git reset --hard origin/<branch>` (local changes overwritten)
2. `composer install --no-dev` + `php artisan config:cache route:cache`
3. `npm ci` + `vite build`
4. Redeploy to Azure App Service + Static Web Apps (or skip if not configured)
5. Health check `GET /api/health`

---

### nginx Config (EC2 / VPS)

**Backend** — `/etc/nginx/sites-available/filemd-api`:
```nginx
server {
    listen 80;
    server_name api.yourdomain.com;
    root /var/www/filemd/backend/public;

    index index.php;

    client_max_body_size 25M;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

**Frontend** — `/etc/nginx/sites-available/filemd`:
```nginx
server {
    listen 80;
    server_name yourdomain.com;
    root /var/www/filemd/frontend/dist;

    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/filemd-api /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/filemd /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

---

## Security

- Temp files created with `tempnam(sys_get_temp_dir(), 'convert_')`, deleted in `finally` block
- No filename, content, or IP is ever logged
- MIME type validated server-side (not just extension)
- CORS restricted to `FRONTEND_URL` env var
- Max upload size enforced both client-side (before request) and server-side (`max:20480`)

---

## TODO

See [docs/TODO.md](docs/TODO.md) for planned work and known gaps.
