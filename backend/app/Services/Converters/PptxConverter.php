<?php

namespace App\Services\Converters;

use PhpOffice\PhpPresentation\IOFactory;
use PhpOffice\PhpPresentation\Shape\RichText;
use PhpOffice\PhpPresentation\Shape\RichText\Paragraph;

class PptxConverter implements ConverterInterface
{
    public function convert(string $tmpPath, string $originalName): string
    {
        $presentation = IOFactory::load($tmpPath);
        $sections = [];

        foreach ($presentation->getAllSlides() as $i => $slide) {
            $slideNum = $i + 1;
            $title = '';
            $bullets = [];
            $notes = '';

            foreach ($slide->getShapeCollection() as $shape) {
                if (!($shape instanceof RichText)) {
                    continue;
                }

                $isTitle = str_contains(strtolower($shape->getName() ?? ''), 'title')
                    || ($shape->getPlaceholder() !== null && $shape->getPlaceholder()->getType() === 1);

                $text = $this->extractRichText($shape);

                if ($isTitle && $title === '') {
                    $title = $text;
                } else {
                    foreach ($shape->getParagraphCollection() as $para) {
                        $paraText = $this->extractParagraphText($para);
                        if ($paraText !== '') {
                            $bullets[] = '- ' . $paraText;
                        }
                    }
                }
            }

            // Notes
            $notesSlide = $slide->getNote();
            if ($notesSlide !== null) {
                foreach ($notesSlide->getShapeCollection() as $shape) {
                    if ($shape instanceof RichText) {
                        $noteText = $this->extractRichText($shape);
                        if ($noteText !== '') {
                            $notes = $noteText;
                        }
                    }
                }
            }

            $heading = "## Slide {$slideNum}" . ($title !== '' ? ": {$title}" : '');
            $lines = [$heading, ''];

            if (!empty($bullets)) {
                $lines = array_merge($lines, $bullets);
                $lines[] = '';
            }

            if ($notes !== '') {
                $lines[] = '> ' . str_replace("\n", "\n> ", $notes);
            }

            $sections[] = implode("\n", $lines);
        }

        return implode("\n\n", $sections);
    }

    private function extractRichText(RichText $shape): string
    {
        $parts = [];
        foreach ($shape->getParagraphCollection() as $para) {
            $text = $this->extractParagraphText($para);
            if ($text !== '') {
                $parts[] = $text;
            }
        }
        return implode("\n", $parts);
    }

    private function extractParagraphText(Paragraph $para): string
    {
        $parts = [];
        foreach ($para->getRichTextElements() as $el) {
            if (method_exists($el, 'getText')) {
                $parts[] = $el->getText();
            }
        }
        return implode('', $parts);
    }
}
