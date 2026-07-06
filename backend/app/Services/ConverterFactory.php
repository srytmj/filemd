<?php

namespace App\Services;

use App\Services\Converters\ConverterInterface;
use App\Services\Converters\PdfConverter;
use App\Services\Converters\DocxConverter;
use App\Services\Converters\XlsxConverter;
use App\Services\Converters\PptxConverter;
use App\Services\Converters\CsvConverter;
use App\Services\Converters\PlainTextConverter;
use InvalidArgumentException;

class ConverterFactory
{
    private const MAP = [
        'application/pdf'                                                                        => PdfConverter::class,
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'               => DocxConverter::class,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'                     => XlsxConverter::class,
        'application/vnd.openxmlformats-officedocument.presentationml.presentation'             => PptxConverter::class,
        'text/csv'                                                                               => CsvConverter::class,
        'text/plain'                                                                             => PlainTextConverter::class,
        'text/markdown'                                                                          => PlainTextConverter::class,
    ];

    public function make(string $mimeType): ConverterInterface
    {
        $class = self::MAP[$mimeType] ?? null;

        if ($class === null) {
            throw new InvalidArgumentException("Unsupported MIME type: {$mimeType}");
        }

        return new $class();
    }
}
