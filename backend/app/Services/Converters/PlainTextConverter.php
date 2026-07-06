<?php

namespace App\Services\Converters;

class PlainTextConverter implements ConverterInterface
{
    public function convert(string $tmpPath, string $originalName): string
    {
        return file_get_contents($tmpPath) ?: '';
    }
}
