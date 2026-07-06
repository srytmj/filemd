<?php

namespace App\Services\Converters;

class CsvConverter implements ConverterInterface
{
    public function convert(string $tmpPath, string $originalName): string
    {
        $handle = fopen($tmpPath, 'r');
        if ($handle === false) {
            return '';
        }

        $rows = [];
        while (($row = fgetcsv($handle)) !== false) {
            $rows[] = $row;
        }
        fclose($handle);

        if (empty($rows)) {
            return '';
        }

        $lines = [];
        $header = array_shift($rows);
        $cols = array_map(fn($c) => str_replace('|', '\\|', (string)$c), $header);
        $lines[] = '| ' . implode(' | ', $cols) . ' |';
        $lines[] = '|' . str_repeat(' --- |', count($cols));

        foreach ($rows as $row) {
            $cells = array_map(fn($c) => str_replace('|', '\\|', (string)$c), $row);
            // Pad if row is shorter than header
            while (count($cells) < count($cols)) {
                $cells[] = '';
            }
            $lines[] = '| ' . implode(' | ', $cells) . ' |';
        }

        return implode("\n", $lines);
    }
}
