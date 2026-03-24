<#
.SYNOPSIS
    Audits point images: cross-references files on disk with markdown references.

.DESCRIPTION
    Scans all PNG files under images/ and all ![...] references in markdown files.
    Produces a CSV tracking file for systematic review of image accuracy.

.PARAMETER RepoRoot
    Path to the acuponctura repository root. Defaults to parent of scripts/.

.PARAMETER OutputCsv
    Output CSV path. Default: images/image-audit.csv
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = "",
    [string] $OutputCsv = ""
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
if (-not $OutputCsv) {
    $OutputCsv = Join-Path $RepoRoot "images\image-audit.csv"
}

Write-Host "Repo root : $RepoRoot"
Write-Host "Output CSV: $OutputCsv"

$imagesDir = Join-Path $RepoRoot "images"

# --- 1. Collect all image files on disk ---
$diskFiles = Get-ChildItem -LiteralPath $imagesDir -Recurse -File -Filter "*.png" |
    ForEach-Object {
        $rel = $_.FullName.Substring($RepoRoot.Length).TrimStart('\', '/') -replace '\\', '/'
        [PSCustomObject]@{
            FullPath     = $_.FullName
            RelativePath = $rel
        }
    }

Write-Host "Found $($diskFiles.Count) image files on disk."

# --- 2. Parse all markdown files for image references ---
$mdFiles = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Filter "*.md" |
    Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' }

$mdRefs = @()
foreach ($md in $mdFiles) {
    $mdRelPath = $md.FullName.Substring($RepoRoot.Length).TrimStart('\', '/') -replace '\\', '/'
    $mdDir = $md.DirectoryName
    $lineNum = 0
    foreach ($line in (Get-Content -LiteralPath $md.FullName -Encoding UTF8)) {
        $lineNum++
        if ($line -match '!\[([^\]]*)\]\(([^)]+)\)') {
            $altText = $Matches[1]
            $rawPath = $Matches[2]

            if ($rawPath -match '^https?://') { continue }

            # Extract the canonical images/ path from the raw relative path.
            # Some markdown files have too many ../ levels, so instead of resolving
            # via filesystem (which would go above repo root), extract the images/
            # portion directly from the relative reference.
            $relTarget = $null
            if ($rawPath -match '(images/.+)$') {
                $relTarget = $Matches[1] -replace '\\', '/'
            } else {
                $absTarget = [IO.Path]::GetFullPath((Join-Path $mdDir $rawPath))
                if ($absTarget.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $relTarget = $absTarget.Substring($RepoRoot.Length).TrimStart('\', '/') -replace '\\', '/'
                } else {
                    $relTarget = $rawPath -replace '\\', '/'
                }
            }

            $mdRefs += [PSCustomObject]@{
                AltText      = $altText
                RawPath      = $rawPath
                ResolvedPath = $relTarget
                MarkdownFile = $mdRelPath
                LineNumber   = $lineNum
            }
        }
    }
}

Write-Host "Found $($mdRefs.Count) image references in $($mdFiles.Count) markdown files."

# --- 3. Build unified audit records ---
$diskLookup = @{}
foreach ($d in $diskFiles) {
    $diskLookup[$d.RelativePath] = $d
}

$refsByImage = @{}
foreach ($r in $mdRefs) {
    if (-not $refsByImage.ContainsKey($r.ResolvedPath)) {
        $refsByImage[$r.ResolvedPath] = @()
    }
    $refsByImage[$r.ResolvedPath] += $r
}

$allPaths = @{}
foreach ($k in $diskLookup.Keys)  { $allPaths[$k] = $true }
foreach ($k in $refsByImage.Keys) { $allPaths[$k] = $true }

$records = @()
foreach ($path in ($allPaths.Keys | Sort-Object)) {
    $onDisk = $diskLookup.ContainsKey($path)
    $refs   = if ($refsByImage.ContainsKey($path)) { $refsByImage[$path] } else { @() }
    $inMd   = $refs.Count -gt 0

    $channel = ""
    $point   = ""
    if ($path -match 'images/points/([A-Z]+)/([A-Z]+\d+)\.png$') {
        $channel = $Matches[1]
        $point   = $Matches[2]
    }

    $category = if ($path -match 'images/points/')      { "point" }
                elseif ($path -match 'images/theory/')       { "theory" }
                elseif ($path -match 'images/meridians/')    { "meridian" }
                elseif ($path -match 'images/foundations/')   { "foundation" }
                elseif ($path -match 'images/techniques/')   { "technique" }
                elseif ($path -match 'images/diagnosis/')    { "diagnosis" }
                elseif ($path -match 'images/microsystems/') { "microsystem" }
                else                                         { "other" }

    $mdFileList = ($refs | ForEach-Object { $_.MarkdownFile }) -join "; "

    $status = "needs-review"
    if (-not $onDisk -and $inMd) { $status = "missing-file" }
    if ($onDisk -and -not $inMd) { $status = "unreferenced" }

    $records += [PSCustomObject]@{
        Point        = $point
        Channel      = $channel
        Category     = $category
        ImagePath    = $path
        FileExists   = if ($onDisk) { "yes" } else { "no" }
        Referenced   = if ($inMd)   { "yes" } else { "no" }
        ReferencedIn = $mdFileList
        Status       = $status
        Notes        = ""
    }
}

# --- 4. Write CSV ---
$records | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8

$stats = @{
    Total        = $records.Count
    NeedsReview  = ($records | Where-Object Status -eq "needs-review").Count
    MissingFile  = ($records | Where-Object Status -eq "missing-file").Count
    Unreferenced = ($records | Where-Object Status -eq "unreferenced").Count
}

Write-Host ""
Write-Host "=== Audit Summary ==="
Write-Host "Total images:         $($stats.Total)"
Write-Host "Needs review:         $($stats.NeedsReview)"
Write-Host "Missing file on disk: $($stats.MissingFile)"
Write-Host "On disk, unreferenced:$($stats.Unreferenced)"
Write-Host ""
Write-Host "CSV written to: $OutputCsv"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Open the CSV in Excel or a text editor"
Write-Host "  2. For each row, change Status to: correct | incorrect | remove | needs-fix | regenerate"
Write-Host "  3. Add notes in the Notes column"
Write-Host "  4. Run Remove-IncorrectImages.ps1 to handle rows marked 'incorrect' or 'remove'"
Write-Host "  5. Run Generate-ImagePrompts.ps1 to create prompts for rows marked 'regenerate'"
