# Local server to view the site at http://localhost:8000 (Windows).
# Started by lancer-site.bat. Close the window to stop the site.
$root = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$types = @{
  '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
  '.js' = 'text/javascript; charset=utf-8'; '.json' = 'application/json'
  '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'
  '.gif' = 'image/gif'; '.svg' = 'image/svg+xml'; '.webp' = 'image/webp'
  '.ico' = 'image/x-icon'; '.woff2' = 'font/woff2'
}

$listener = $null
foreach ($port in 8000..8010) {
  try {
    $candidate = New-Object System.Net.HttpListener
    $candidate.Prefixes.Add("http://localhost:$port/")
    $candidate.Start()
    $listener = $candidate
    break
  } catch { }
}

if (-not $listener) {
  Write-Host "Impossible de demarrer le serveur local : ouverture de index.html directement."
  Start-Process (Join-Path $root 'index.html')
  Start-Sleep -Seconds 5
  exit 1
}

$url = "http://localhost:$port/"
Write-Host ""
Write-Host "  Site en ligne sur $url"
Write-Host "  Laisse cette fenetre ouverte. Ferme-la pour arreter le site."
Write-Host ""
try { Start-Process $url } catch { }

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $res = $ctx.Response
  try {
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if ($rel -eq '' -or $rel.EndsWith('/')) { $rel += 'index.html' }
    $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
    if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $full -PathType Leaf)) {
      $bytes = [IO.File]::ReadAllBytes($full)
      $ext = [IO.Path]::GetExtension($full).ToLower()
      $res.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { 'application/octet-stream' }
      $res.ContentLength64 = $bytes.Length
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $res.StatusCode = 404
    }
  } catch {
    $res.StatusCode = 500
  } finally {
    $res.Close()
  }
}
