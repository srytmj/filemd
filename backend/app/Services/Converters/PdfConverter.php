<?php

namespace App\Services\Converters;

use Smalot\PdfParser\Parser;

class PdfConverter implements ConverterInterface
{
    public function convert(string $tmpPath, string $originalName): string
    {
        $parser = new Parser();
        $pdf = $parser->parseFile($tmpPath);
        $pages = $pdf->getPages();

        if (empty($pages)) {
            return '';
        }

        $lines = [];
        $details = $pdf->getDetails();
        if (!empty($details['Title'])) {
            $lines[] = '# ' . trim($details['Title']);
            $lines[] = '';
        }

        foreach ($pages as $i => $page) {
            $text = trim($page->getText());
            if ($text !== '') {
                $lines[] = $text;
            }
            if ($i < count($pages) - 1) {
                $lines[] = '';
                $lines[] = '---';
                $lines[] = '';
            }
        }

        return implode("\n", $lines);
    }
}
