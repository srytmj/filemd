<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class ConvertRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'files'   => ['required', 'array', 'min:1'],
            'files.*' => ['required', 'file', 'max:20480', 'mimes:pdf,docx,xlsx,pptx,txt,md,csv'],
        ];
    }

    public function messages(): array
    {
        return [
            'files.required'      => 'At least one file is required.',
            'files.*.file'        => 'Each upload must be a valid file.',
            'files.*.max'         => 'Each file must not exceed 20MB.',
            'files.*.mimes'       => 'Supported formats: PDF, DOCX, XLSX, PPTX, TXT, MD, CSV.',
        ];
    }
}
