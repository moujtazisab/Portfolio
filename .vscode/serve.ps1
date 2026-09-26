$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$rootPrefix = $root.TrimEnd('\') + '\'
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add('http://127.0.0.1:5500/')

try {
    $listener.Start()
    Write-Output 'Portfolio server listening on http://127.0.0.1:5500'

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $response = $context.Response

        try {
            if ($context.Request.Url.AbsolutePath -eq '/__stop') {
                $stopMessage = [System.Text.Encoding]::UTF8.GetBytes('Portfolio server stopping')
                $response.StatusCode = 200
                $response.ContentType = 'text/plain; charset=utf-8'
                $response.ContentLength64 = $stopMessage.Length
                $response.OutputStream.Write($stopMessage, 0, $stopMessage.Length)
                $listener.Stop()
                continue
            }

            $relativePath = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
            if ([string]::IsNullOrWhiteSpace($relativePath)) {
                $relativePath = 'MainPage.html'
            }

            $relativePath = $relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $filePath = [System.IO.Path]::GetFullPath((Join-Path $root $relativePath))

            if (-not $filePath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $response.StatusCode = 403
            } elseif (-not [System.IO.File]::Exists($filePath)) {
                $response.StatusCode = 404
            } else {
                $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
                $contentType = switch ($extension) {
                    '.html' { 'text/html; charset=utf-8' }
                    '.css' { 'text/css; charset=utf-8' }
                    '.js' { 'text/javascript; charset=utf-8' }
                    '.json' { 'application/json; charset=utf-8' }
                    '.svg' { 'image/svg+xml' }
                    '.png' { 'image/png' }
                    '.jpg' { 'image/jpeg' }
                    '.jpeg' { 'image/jpeg' }
                    '.pdf' { 'application/pdf' }
                    default { 'application/octet-stream' }
                }

                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                $response.StatusCode = 200
                $response.ContentType = $contentType
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
        } catch {
            $response.StatusCode = 500
        } finally {
            $response.Close()
        }
    }
} finally {
    $listener.Close()
    Write-Output 'Portfolio server stopped'
}
