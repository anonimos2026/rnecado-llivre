# Servidor HTTP Estático em PowerShell (.NET HttpListener)
$workspaceRoot = $PSScriptRoot
$mercadoLivreFolder = Join-Path $workspaceRoot "Mercado Livre"

$portsToTry = @(3000, 8080, 5000, 5500, 8000, 8081)
$listener = $null
$selectedPort = $null

foreach ($p in $portsToTry) {
    try {
        $tempListener = New-Object System.Net.HttpListener
        $tempListener.Prefixes.Add("http://localhost:$p/")
        $tempListener.Start()
        $listener = $tempListener
        $selectedPort = $p
        break
    } catch {
        if ($tempListener) {
            $tempListener.Close()
        }
    }
}

if (-not $listener) {
    Write-Error "Não foi possível iniciar o servidor em nenhuma das portas testadas ($($portsToTry -join ', '))."
    exit 1
}

Write-Host "===================================================="
Write-Host "Servidor HTTP rodando com sucesso!"
Write-Host "URL Principal: http://localhost:$selectedPort/vibration"
Write-Host "Pasta servida: $mercadoLivreFolder"
Write-Host "===================================================="

$mimeTypes = @{
    ".html"  = "text/html; charset=utf-8"
    ".htm"   = "text/html; charset=utf-8"
    ".css"   = "text/css; charset=utf-8"
    ".js"    = "application/javascript; charset=utf-8"
    ".json"  = "application/json; charset=utf-8"
    ".png"   = "image/png"
    ".jpg"   = "image/jpeg"
    ".jpeg"  = "image/jpeg"
    ".webp"  = "image/webp"
    ".gif"   = "image/gif"
    ".svg"   = "image/svg+xml"
    ".ico"   = "image/x-icon"
    ".woff"  = "font/woff"
    ".woff2" = "font/woff2"
    ".ttf"   = "font/ttf"
    ".eot"   = "application/vnd.ms-fontobject"
    ".mp4"   = "video/mp4"
    ".webm"  = "video/webm"
    ".mp3"   = "audio/mpeg"
    ".pdf"   = "application/pdf"
    ".txt"   = "text/plain; charset=utf-8"
}

try {
    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response

            # Adiciona cabeçalhos CORS e controle de cache
            $response.AddHeader("Access-Control-Allow-Origin", "*")
            $response.AddHeader("Cache-Control", "no-cache, no-store, must-revalidate")

            $rawUrl = [System.Uri]::UnescapeDataString($request.RawUrl.Split('?')[0])
            $cleanPath = $rawUrl.Trim('/')

            # Verifica se a rota finaliza com /vibration
            $isVibration = ($cleanPath -ieq "vibration" -or $cleanPath.EndsWith("/vibration", [System.StringComparison]::OrdinalIgnoreCase) -or $cleanPath -ieq "vibration/index.html")

            $targetFile = $null

            if ($isVibration) {
                # A página é exibida na URL /vibration
                $targetFile = Join-Path $mercadoLivreFolder "index.html"
            } elseif ([string]::IsNullOrWhiteSpace($cleanPath) -or $cleanPath -ieq "index.html") {
                # Redireciona a raiz para /vibration para não dar página fora do ar
                $response.StatusCode = 302
                $response.RedirectLocation = "/vibration"
                $response.Close()
                continue
            } else {
                # Trata arquivos estáticos (CSS, JS, imagens, fontes, etc.)
                $assetPath = $cleanPath

                # Remove prefixo 'vibration/' se for requisição relativa originada em /vibration/
                if ($assetPath.StartsWith("vibration/", [System.StringComparison]::OrdinalIgnoreCase)) {
                    $assetPath = $assetPath.Substring(10).TrimStart('/')
                }

                # Remove prefixo 'Mercado Livre/' se vier na URL
                if ($assetPath.StartsWith("Mercado Livre/", [System.StringComparison]::OrdinalIgnoreCase)) {
                    $assetPath = $assetPath.Substring(14).TrimStart('/')
                }

                $cand1 = Join-Path $mercadoLivreFolder $assetPath
                $cand2 = Join-Path $workspaceRoot $assetPath

                if (Test-Path $cand1 -PathType Leaf) {
                    $targetFile = $cand1
                } elseif (Test-Path $cand2 -PathType Leaf) {
                    $targetFile = $cand2
                }
            }

            if ($targetFile -and (Test-Path $targetFile -PathType Leaf)) {
                $ext = [System.IO.Path]::GetExtension($targetFile).ToLower()
                $mime = $mimeTypes[$ext]
                if (-not $mime) { $mime = "application/octet-stream" }

                $bytes = [System.IO.File]::ReadAllBytes($targetFile)
                $response.ContentType = $mime
                $response.ContentLength64 = $bytes.Length
                $response.StatusCode = 200
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $response.StatusCode = 404
                $msgText = "<!DOCTYPE html><html><head><meta charset='utf-8'><title>404 - Não Encontrado</title></head><body style='font-family:sans-serif;padding:60px;text-align:center;'><h1>404 - Não Encontrado</h1><p>Esta página só está disponível com a URL finalizando em <b>/vibration</b>.</p><p><a href='/vibration' style='color:#3483fa;font-size:18px;'>Acessar /vibration</a></p></body></html>"
                $msg = [System.Text.Encoding]::UTF8.GetBytes($msgText)
                $response.ContentType = "text/html; charset=utf-8"
                $response.ContentLength64 = $msg.Length
                $response.OutputStream.Write($msg, 0, $msg.Length)
            }

            $response.Close()
        } catch {
            # Ignora erros normais de conexão encerrada pelo navegador
        }
    }
} finally {
    if ($listener) {
        $listener.Stop()
        $listener.Close()
    }
}
