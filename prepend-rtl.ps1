# Prepend <div dir="rtl"> to all Markdown files for GitBook/GitHub RTL rendering.
# Skips files that already start with the RTL wrapper (after optional UTF-8 BOM).

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$prefix = "<div dir=`"rtl`">`r`n`r`n"
$updated = 0
$skipped = 0

Get-ChildItem -Path $root -Filter '*.md' -Recurse -File |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
    ForEach-Object {
        $path = $_.FullName
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $encoding = [System.Text.UTF8Encoding]::new($false)
        $text = $encoding.GetString($bytes)

        # Strip UTF-8 BOM if present
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $text = $encoding.GetString($bytes, 3, $bytes.Length - 3)
        }

        if ($text.StartsWith('<div dir="rtl">')) {
            $skipped++
            return
        }

        $newText = $prefix + $text
        [System.IO.File]::WriteAllText($path, $newText, $encoding)
        $updated++
    }

Write-Host "Updated: $updated markdown file(s). Skipped (already RTL): $skipped." -ForegroundColor Green
