# PRD - File to Markdown Converter

## Problem Statement

Converting files to markdown for AI consumption is tedious and manual. Users need a fast, secure, zero-friction tool that converts uploaded files into clean markdown output without storing any data.

## Target Users

General public. No login required. Anyone who needs to convert documents for AI workflows.

## Core User Stories

- As a user, I want to drag and drop a file, so that I get the markdown output immediately without any signup.
- As a user uploading a single file, I want to see the markdown rendered on screen, so that I can copy it directly.
- As a user uploading multiple files, I want to download a single combined markdown file, so that I can use it without manual merging.
- As a user, I want confidence that my files are deleted after conversion, so that sensitive documents are not stored anywhere.

## Features

### P0 (Must Have)

- Drag and drop upload zone (multi-file supported)
- Click to browse fallback
- Supported formats: PDF, DOCX, XLSX, PPTX, TXT, MD, CSV
- File size limit: 20MB per file
- Single file: display markdown output inline with copy button
- Multiple files: download as combined `.md` file
- File deleted from server immediately after conversion
- No database storage of file content
- Error state per file (unsupported format, too large, conversion failed)

### P1 (Should Have)

- Progress indicator per file during upload and conversion
- File list preview before converting (with remove option)
- Conversion time display
- Markdown preview toggle (raw vs rendered)

### P2 (Nice to Have)

- Dark mode
- Conversion history (local storage only, no server)
- Individual file download when multiple files uploaded

## Out of Scope

- User authentication
- File storage or history on server
- AI processing of the markdown (this tool only converts)
- Real-time collaboration
- Mobile-native app

## Security Requirements

- Files stored only in Laravel temp storage during processing
- Temp file deleted immediately after conversion response is sent
- No file metadata logged (filename, content, user IP not persisted)
- HTTPS enforced
- Max file size validated on both client and server
- File type validated by MIME type, not extension

## Success Metrics

- Conversion success rate > 95%
- Time to markdown output < 5 seconds for files under 5MB
- Zero file retention incidents
