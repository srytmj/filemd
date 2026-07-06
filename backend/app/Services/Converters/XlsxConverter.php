<?php

namespace App\Services\Converters;

use PhpOffice\PhpSpreadsheet\IOFactory;

class XlsxConverter implements ConverterInterface
{
    public function convert(string $tmpPath, string $originalName): string
    {
        $spreadsheet = IOFactory::load($tmpPath);
        $sections = [];

        foreach ($spreadsheet->getAllSheets() as $sheet) {
            $name = $sheet->getTitle();
            $rows = $sheet->toArray(null, true, true, false);

            $nonEmpty = array_filter($rows, fn($r) => array_filter($r, fn($c) => $c !== null && $c !== ''));
            if (empty($nonEmpty)) {
                continue;
            }

            $lines = ["## {$name}"];
            $lines[] = '';

            $header = array_shift($rows);
            $cols = array_map(fn($c) => (string)($c ?? ''), $header);
            $lines[] = '| ' . implode(' | ', $cols) . ' |';
            $lines[] = '|' . str_repeat(' --- |', count($cols));

            foreach ($rows as $row) {
                $cells = array_map(fn($c) => str_replace('|', '\\|', (string)($c ?? '')), $row);
                $lines[] = '| ' . implode(' | ', $cells) . ' |';
            }

            $sections[] = implode("\n", $lines);
        }

        return implode("\n\n", $sections);
    }
}
