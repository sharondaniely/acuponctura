<#
.SYNOPSIS
    Merges course Markdown files into master files for NotebookLM upload.

.DESCRIPTION
    Walks each configured source directory recursively, sorts .md files by path,
    and concatenates them with source path headers and horizontal rules.
    Also builds 00-curriculum-overview.md from root README.md and CURRICULUM.md.

.PARAMETER RepoRoot
    Path to the acuponctura repository root. Defaults to parent of scripts/.

.PARAMETER OutputDir
    Output folder name under RepoRoot. Default: export-for-ai
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = "",
    [string] $OutputDir = "export-for-ai"
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$outFull = Join-Path $RepoRoot $OutputDir
if (-not (Test-Path -LiteralPath $outFull)) {
    New-Item -ItemType Directory -Path $outFull | Out-Null
}

function Write-Utf8BomFile {
    param([string] $Path, [string] $Content)
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

$script:HasPathGetRelativePath = $false
try {
    $null = [IO.Path]::GetRelativePath(
        [IO.Path]::Combine($RepoRoot, "a"),
        [IO.Path]::Combine($RepoRoot, "a\b")
    )
    $script:HasPathGetRelativePath = $true
} catch {
    $script:HasPathGetRelativePath = $false
}

if (-not $script:HasPathGetRelativePath) {
    Add-Type -TypeDefinition @"
using System;
using System.IO;
public static class PathRel {
    public static string GetRelativePath(string from, string to) {
        from = Path.GetFullPath(from.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar);
        to = Path.GetFullPath(to);
        var fromUri = new Uri(from);
        var toUri = new Uri(to);
        return Uri.UnescapeDataString(fromUri.MakeRelativeUri(toUri).ToString()).Replace('/', Path.DirectorySeparatorChar);
    }
}
"@
}

function Get-RelativePathSafe {
    param([string]$From, [string]$To)
    if ($script:HasPathGetRelativePath) {
        return [IO.Path]::GetRelativePath($From, $To)
    }
    return [PathRel]::GetRelativePath($From, $To)
}

function Merge-DirectoryMarkdown {
    param(
        [string] $SourceDirAbsolute,
        [string] $OutputFileAbsolute,
        [string] $TitleForHeader
    )

    if (-not (Test-Path -LiteralPath $SourceDirAbsolute)) {
        Write-Warning "Skip missing directory: $SourceDirAbsolute"
        return
    }

    $mdFiles = Get-ChildItem -LiteralPath $SourceDirAbsolute -Recurse -File -Filter "*.md" |
        Sort-Object { $_.FullName }

    $folderName = [IO.Path]::GetFileName($SourceDirAbsolute)
    $count = $mdFiles.Count
    $headerLine = "_Merged from: ``$folderName`` - $count file(s)_"

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# $TitleForHeader")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine($headerLine)
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")

    foreach ($f in $mdFiles) {
        $rel = (Get-RelativePathSafe -From $SourceDirAbsolute -To $f.FullName) -replace '\\', '/'
        [void]$sb.AppendLine("## Source: ``$rel``")
        [void]$sb.AppendLine("")
        $raw = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
        if ($null -eq $raw) { $raw = "" }
        [void]$sb.AppendLine($raw.TrimEnd())
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("---")
        [void]$sb.AppendLine("")
    }

    Write-Utf8BomFile -Path $OutputFileAbsolute -Content ($sb.ToString())
    Write-Host "Wrote $count files -> $OutputFileAbsolute"
}

function Merge-ExplicitFiles {
    param(
        [string[]] $RelativePathsFromRepoRoot,
        [string] $OutputFileAbsolute,
        [string] $DocumentTitle
    )

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# $DocumentTitle")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")

    foreach ($rel in $RelativePathsFromRepoRoot) {
        $full = Join-Path $RepoRoot $rel
        if (-not (Test-Path -LiteralPath $full)) {
            Write-Warning "Missing file, skipping: $rel"
            continue
        }
        [void]$sb.AppendLine("## Source: ``$rel``")
        [void]$sb.AppendLine("")
        $raw = Get-Content -LiteralPath $full -Raw -Encoding UTF8
        if ($null -eq $raw) { $raw = "" }
        [void]$sb.AppendLine($raw.TrimEnd())
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("---")
        [void]$sb.AppendLine("")
    }

    Write-Utf8BomFile -Path $OutputFileAbsolute -Content ($sb.ToString())
    Write-Host "Wrote curriculum overview -> $OutputFileAbsolute"
}

$bundles = @(
    @{ Dir = "year-1-foundations";   Out = "01-year-1-foundations-master.md";   Title = "Year 1 - Foundations (Acupuncture Course)" }
    @{ Dir = "year-2-intermediate"; Out = "02-year-2-intermediate-master.md"; Title = "Year 2 - Intermediate (Acupuncture Course)" }
    @{ Dir = "year-3-clinical";     Out = "03-year-3-clinical-master.md";     Title = "Year 3 - Clinical (Acupuncture Course)" }
    @{ Dir = "year-4-advanced";     Out = "04-year-4-advanced-master.md";     Title = "Year 4 - Advanced (Acupuncture Course)" }
    @{ Dir = "year-5-mastery";      Out = "05-year-5-mastery-master.md";      Title = "Year 5 - Mastery (Acupuncture Course)" }
    @{ Dir = "case-studies";        Out = "06-case-studies-master.md";        Title = "Case Studies (Acupuncture Course)" }
    @{ Dir = "diagnostic-tool";     Out = "07-diagnostic-tool-master.md";     Title = "Diagnostic Tool (Acupuncture Course)" }
)

Write-Host "Repo root: $RepoRoot"
Write-Host "Output:    $outFull"

Merge-ExplicitFiles `
    -RelativePathsFromRepoRoot @("README.md", "CURRICULUM.md") `
    -OutputFileAbsolute (Join-Path $outFull "00-curriculum-overview.md") `
    -DocumentTitle "Course overview and curriculum map"

foreach ($b in $bundles) {
    $src = Join-Path $RepoRoot $b.Dir
    $dst = Join-Path $outFull $b.Out
    Merge-DirectoryMarkdown -SourceDirAbsolute $src -OutputFileAbsolute $dst -TitleForHeader $b.Title
}

Write-Host "Done."
