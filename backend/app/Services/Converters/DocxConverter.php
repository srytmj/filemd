<?php

namespace App\Services\Converters;

use PhpOffice\PhpWord\IOFactory;
use PhpOffice\PhpWord\Element\Text;
use PhpOffice\PhpWord\Element\TextRun;
use PhpOffice\PhpWord\Element\Title;
use PhpOffice\PhpWord\Element\Table;
use PhpOffice\PhpWord\Element\Image;
use PhpOffice\PhpWord\Element\ListItem;

class DocxConverter implements ConverterInterface
{
    public function convert(string $tmpPath, string $originalName): string
    {
        $phpWord = IOFactory::load($tmpPath, 'Word2007');
        $lines = [];

        foreach ($phpWord->getSections() as $section) {
            foreach ($section->getElements() as $element) {
                $line = $this->renderElement($element);
                if ($line !== null) {
                    $lines[] = $line;
                }
            }
        }

        return implode("\n\n", array_filter($lines, fn($l) => $l !== ''));
    }

    private function renderElement(mixed $element): ?string
    {
        if ($element instanceof Title) {
            $depth = $element->getDepth();
            $prefix = str_repeat('#', max(1, min($depth, 6)));
            $text = $this->extractText($element->getText());
            return $prefix . ' ' . $text;
        }

        if ($element instanceof ListItem) {
            $text = $this->extractText($element->getTextObject());
            return '- ' . $text;
        }

        if ($element instanceof Table) {
            return $this->renderTable($element);
        }

        if ($element instanceof Image) {
            return '[image omitted]';
        }

        if ($element instanceof TextRun) {
            return $this->renderTextRun($element);
        }

        if ($element instanceof Text) {
            return $element->getText();
        }

        // Paragraph or other container
        if (method_exists($element, 'getElements')) {
            $parts = [];
            foreach ($element->getElements() as $child) {
                $rendered = $this->renderElement($child);
                if ($rendered !== null) {
                    $parts[] = $rendered;
                }
            }
            return implode('', $parts);
        }

        return null;
    }

    private function renderTextRun(TextRun $run): string
    {
        $parts = [];
        foreach ($run->getElements() as $el) {
            if ($el instanceof Text) {
                $text = $el->getText();
                $font = $el->getFontStyle();
                if (is_object($font)) {
                    if ($font->getBold() && $font->getItalic()) {
                        $text = '***' . $text . '***';
                    } elseif ($font->getBold()) {
                        $text = '**' . $text . '**';
                    } elseif ($font->getItalic()) {
                        $text = '*' . $text . '*';
                    }
                }
                $parts[] = $text;
            }
        }
        return implode('', $parts);
    }

    private function renderTable(Table $table): string
    {
        $rows = $table->getRows();
        if (empty($rows)) {
            return '';
        }

        $mdRows = [];
        foreach ($rows as $row) {
            $cells = [];
            foreach ($row->getCells() as $cell) {
                $cellText = '';
                foreach ($cell->getElements() as $el) {
                    $rendered = $this->renderElement($el);
                    if ($rendered !== null) {
                        $cellText .= $rendered;
                    }
                }
                $cells[] = trim($cellText);
            }
            $mdRows[] = '| ' . implode(' | ', $cells) . ' |';
        }

        // Insert separator after header row
        if (count($mdRows) > 0) {
            $colCount = substr_count($mdRows[0], '|') - 1;
            $separator = '|' . str_repeat(' --- |', $colCount);
            array_splice($mdRows, 1, 0, [$separator]);
        }

        return implode("\n", $mdRows);
    }

    private function extractText(mixed $text): string
    {
        if (is_string($text)) {
            return $text;
        }
        if ($text instanceof TextRun) {
            return $this->renderTextRun($text);
        }
        return '';
    }
}
