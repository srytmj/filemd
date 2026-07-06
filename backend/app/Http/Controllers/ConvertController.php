<?php

namespace App\Http\Controllers;

use App\Http\Requests\ConvertRequest;
use App\Services\ConvertService;
use Illuminate\Http\JsonResponse;
use InvalidArgumentException;
use Throwable;

class ConvertController extends Controller
{
    public function __construct(private ConvertService $service) {}

    public function handle(ConvertRequest $request): JsonResponse
    {
        $files = $request->file('files');

        if (count($files) === 1) {
            $file = $files[0];
            try {
                $markdown = $this->service->convertFile($file);
                return response()->json([
                    'type'     => 'single',
                    'filename' => $file->getClientOriginalName(),
                    'markdown' => $markdown,
                ]);
            } catch (InvalidArgumentException $e) {
                return response()->json([
                    'error'    => true,
                    'message'  => 'File type not supported.',
                    'filename' => $file->getClientOriginalName(),
                ], 422);
            } catch (Throwable) {
                return response()->json([
                    'error'    => true,
                    'message'  => 'Conversion failed.',
                    'filename' => $file->getClientOriginalName(),
                ], 500);
            }
        }

        $results = [];
        foreach ($files as $file) {
            try {
                $markdown = $this->service->convertFile($file);
                $results[] = [
                    'filename' => $file->getClientOriginalName(),
                    'markdown' => $markdown,
                ];
            } catch (InvalidArgumentException) {
                $results[] = [
                    'filename' => $file->getClientOriginalName(),
                    'error'    => true,
                    'message'  => 'File type not supported.',
                ];
            } catch (Throwable) {
                $results[] = [
                    'filename' => $file->getClientOriginalName(),
                    'error'    => true,
                    'message'  => 'Conversion failed.',
                ];
            }
        }

        return response()->json([
            'type'  => 'multiple',
            'files' => $results,
        ]);
    }
}
