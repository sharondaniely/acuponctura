<#
.SYNOPSIS
    Removes or comments out image references marked as incorrect in the audit CSV.

.DESCRIPTION
    Reads the image-audit.csv and processes rows where Status is 'incorrect' or 'remove'.
    For each such image, finds all markdown files that reference it and either:
    - Comments out the image line (wraps in HTML comment)
    - Or removes the line entirely (with -Delete switch)

    IMPORTANT: Run Audit-PointImages.ps1 first, then review the CSV and mark images
    with Status = 'incorrect' or 'remove' before running this script.

.PARAMETER RepoRoot
    Path to the acuponctura repository root. Defaults to parent of scripts/.

.PARAMETER AuditCsv
    Path to the audit CSV. Default: images/image-audit.csv

.PARAMETER Delete
    If set, removes image lines entirely instead of commenting them out.

.PARAMETER DryRun
    If set, shows what would be changed without modifying files.
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = "",
    [string] $AuditCsv = "",
    [switch] $Delete,
    [switch] $DryRun
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
if (-not $AuditCsv) {
    $AuditCsv = Join-Path $RepoRoot "images\image-audit.csv"
}

if (-not (Test-Path -LiteralPath $AuditCsv)) {
    Write-Error "Audit CSV not found: $AuditCsv`nRun Audit-PointImages.ps1 first."
    return
}

$records = Import-Csv -LiteralPath $AuditCsv -Encoding UTF8
$toProcess = $records | Where-Object { $_.Status -in @('incorrect', 'remove') }

if ($toProcess.Count -eq 0) {
    Write-Host "No images marked as 'incorrect' or 'remove' in the audit CSV."
    Write-Host "Open $AuditCsv, change the Status column for images you want to remove, then re-run."
    return
}

Write-Host "Found $($toProcess.Count) image(s) to process."
if ($DryRun) { Write-Host "[DRY RUN] No files will be modified." }

$imagePaths = @{}
foreach ($rec in $toProcess) {
    $imagePaths[$rec.ImagePath] = $rec
}

$mdFiles = Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Filter "*.md" |
    Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' }

$changedFiles = @{}
$totalChanges = 0

foreach ($md in $mdFiles) {
    $lines = Get-Content -LiteralPath $md.FullName -Encoding UTF8
    $modified = $false
    $newLines = @()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $shouldProcess = $false

        if ($line -match '!\[([^\]]*)\]\(([^)]+)\)') {
            $rawPath = $Matches[2]
            if ($rawPath -match '(images/.+)$') {
                $resolvedPath = $Matches[1] -replace '\\', '/'
                if ($imagePaths.ContainsKey($resolvedPath)) {
                    $shouldProcess = $true
                }
            }
        }

        if ($shouldProcess) {
            $totalChanges++
            $mdRel = $md.FullName.Substring($RepoRoot.Length).TrimStart('\', '/') -replace '\\', '/'
            if ($DryRun) {
                $action = if ($Delete) { "DELETE" } else { "COMMENT" }
                Write-Host "  [$action] $mdRel line $($i + 1): $line"
            }

            if (-not $Delete) {
                $newLines += "<!-- REMOVED: $line -->"
            }
            $modified = $true

            if (-not $changedFiles.ContainsKey($mdRel)) {
                $changedFiles[$mdRel] = 0
            }
            $changedFiles[$mdRel]++
        } else {
            $newLines += $line
        }
    }

    if ($modified -and -not $DryRun) {
        $content = $newLines -join "`n"
        [System.IO.File]::WriteAllText($md.FullName, $content, [System.Text.UTF8Encoding]::new($false))
    }
}

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Images processed: $($toProcess.Count)"
Write-Host "Lines changed:    $totalChanges"
Write-Host "Files modified:   $($changedFiles.Count)"
foreach ($kv in $changedFiles.GetEnumerator() | Sort-Object Name) {
    Write-Host "  $($kv.Name): $($kv.Value) line(s)"
}

if (-not $DryRun -and $totalChanges -gt 0) {
    Write-Host ""
    Write-Host "Done. Remember to also run Merge-MarkdownForAI.ps1 to update the export files."
}
