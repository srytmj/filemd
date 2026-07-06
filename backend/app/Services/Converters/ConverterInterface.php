<?php

namespace App\Services\Converters;

interface ConverterInterface
{
    public function convert(string $tmpPath, string $originalName): string;
}
