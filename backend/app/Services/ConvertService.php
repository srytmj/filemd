<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;

class ConvertService
{
    public function __construct(private ConverterFactory $factory) {}

    public function convertFile(UploadedFile $file): string
    {
        $mimeType = $file->getMimeType() ?? '';
        $converter = $this->factory->make($mimeType);

        $tmpPath = tempnam(sys_get_temp_dir(), 'convert_');
        try {
            file_put_contents($tmpPath, $file->getContent());
            return $converter->convert($tmpPath, $file->getClientOriginalName());
        } finally {
            if (file_exists($tmpPath)) {
                unlink($tmpPath);
            }
        }
    }
}
