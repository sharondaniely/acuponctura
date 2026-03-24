<#
.SYNOPSIS
    Extracts point data from markdown and generates structured prompts for image regeneration.

.DESCRIPTION
    Parses all meridian channel markdown files, extracts location/landmark data for each
    acupuncture point, and produces a JSON file with structured prompts suitable for
    AI image generation (DALL-E, GPT-4o, Midjourney, etc.).

    Prompts target a simplified schematic diagram style rather than realistic anatomy,
    reducing the chance of anatomical inaccuracies.

.PARAMETER RepoRoot
    Path to the acuponctura repository root. Defaults to parent of scripts/.

.PARAMETER AuditCsv
    Optional path to the audit CSV. If provided, only generates prompts for rows
    with Status = 'regenerate' or 'needs-fix'. If omitted, generates for all points.

.PARAMETER OutputJson
    Output JSON path. Default: scripts/image-prompts.json

.PARAMETER Channel
    Optional: only generate prompts for a specific channel (e.g., 'SI', 'LU').
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = "",
    [string] $AuditCsv = "",
    [string] $OutputJson = "",
    [string] $Channel = ""
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
if (-not $OutputJson) {
    $OutputJson = Join-Path $RepoRoot "scripts\image-prompts.json"
}

$filterPoints = $null
if ($AuditCsv -and (Test-Path -LiteralPath $AuditCsv)) {
    $auditData = Import-Csv -LiteralPath $AuditCsv -Encoding UTF8
    $filterPoints = @{}
    $auditData |
        Where-Object { $_.Status -in @('regenerate', 'needs-fix') -and $_.Category -eq 'point' } |
        ForEach-Object { $filterPoints[$_.Point] = $true }
    Write-Host "Audit CSV filter: $($filterPoints.Count) points marked for regeneration."
}

$bodyRegionMap = @{
    "LU"  = "upper chest and medial arm (anterior-radial side)"
    "LI"  = "hand, forearm, and face (radial/lateral side)"
    "ST"  = "face, chest, abdomen, and leg (anterior surface)"
    "SP"  = "foot, leg, and abdomen (medial side)"
    "HT"  = "axilla and medial arm (ulnar side)"
    "SI"  = "hand, arm, shoulder, and face (ulnar/posterior side)"
    "BL"  = "head, back, and posterior leg"
    "KI"  = "foot sole, medial leg, chest, and abdomen"
    "PC"  = "chest and medial arm (between LU and HT)"
    "TE"  = "hand, forearm, and head (dorsal/lateral side)"
    "GB"  = "head, lateral torso, and lateral leg"
    "LR"  = "foot, medial leg, and lateral ribcage"
    "DU"  = "midline of the back and head (posterior)"
    "REN" = "midline of the front (anterior)"
}

$channelNames = @{
    "LU"  = "Lung"
    "LI"  = "Large Intestine"
    "ST"  = "Stomach"
    "SP"  = "Spleen"
    "HT"  = "Heart"
    "SI"  = "Small Intestine"
    "BL"  = "Bladder"
    "KI"  = "Kidney"
    "PC"  = "Pericardium"
    "TE"  = "Triple Energizer"
    "GB"  = "Gallbladder"
    "LR"  = "Liver"
    "DU"  = "Du Mai (Governing Vessel)"
    "REN" = "Ren Mai (Conception Vessel)"
}

function Extract-SectionText {
    param(
        [string] $Content,
        [string] $SectionMarker
    )
    $escaped = [regex]::Escape($SectionMarker)
    # Flexible bold-end pattern: handles **text**: , **text:**, **text**:, etc.
    $boldEnd = '[:\*\s]*'
    $patterns = @(
        # Pattern 1: h4 header or bold, content on NEXT lines
        "(?:####\s*$escaped|\*\*$escaped$boldEnd)\s*\r?\n([\s\S]*?)(?=\r?\n(?:####|\*\*[^\d*]|!\[|---))",
        # Pattern 2: bold marker with content on SAME line
        "\*\*$escaped$boldEnd\s*(.+?)(?:\r?\n\r?\n|\r?\n(?:####|\*\*|!\[|---))",
        # Pattern 3: plain text marker with content on next line
        "(?:$escaped[:\s]*)\r?\n(.+?)(?:\r?\n\r?\n)"
    )
    foreach ($p in $patterns) {
        if ($Content -match $p) {
            return $Matches[1].Trim()
        }
    }
    return ""
}

function Get-PointSections {
    param([string] $FilePath)

    $content = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
    if (-not $content) { return @() }

    $points = @()
    $headerPattern = '(?m)^###\s+(([A-Z]{2,3})(\d+))\s*[-\u2014\u2013]\s*(.+?)(?:\r?\n)'
    $headerMatches = [regex]::Matches($content, $headerPattern)

    for ($i = 0; $i -lt $headerMatches.Count; $i++) {
        $m = $headerMatches[$i]
        $pointId = $m.Groups[1].Value.Trim()
        $channelCode = $m.Groups[2].Value
        $pointNum = [int]$m.Groups[3].Value
        $headerRest = $m.Groups[4].Value.Trim()

        $startIdx = $m.Index + $m.Length
        $endIdx = if ($i + 1 -lt $headerMatches.Count) { $headerMatches[$i + 1].Index } else { $content.Length }
        $section = $content.Substring($startIdx, $endIdx - $startIdx)

        $chineseName = ""
        $pinyin = ""
        if ($headerRest -match '([^\(]+)\s*[\(]([^)]+)[\)]') {
            $chineseName = $Matches[1].Trim()
            $pinyin = $Matches[2].Trim()
        }

        $location = Extract-SectionText -Content $section -SectionMarker ([char]0x05DE + [char]0x05D9 + [char]0x05E7 + [char]0x05D5 + [char]0x05DD + " " + [char]0x05D0 + [char]0x05E0 + [char]0x05D8 + [char]0x05D5 + [char]0x05DE + [char]0x05D9)
        $howToFind = Extract-SectionText -Content $section -SectionMarker ([char]0x05D0 + [char]0x05D9 + [char]0x05DA + " " + [char]0x05DC + [char]0x05DE + [char]0x05E6 + [char]0x05D5 + [char]0x05D0 + " " + [char]0x05D0 + [char]0x05EA + " " + [char]0x05D4 + [char]0x05E0 + [char]0x05E7 + [char]0x05D5 + [char]0x05D3 + [char]0x05D4)

        $specialCat = ""
        $specialMarker = [char]0x05E7 + [char]0x05D8 + [char]0x05D2 + [char]0x05D5 + [char]0x05E8 + [char]0x05D9 + [char]0x05D4 + " " + [char]0x05DE + [char]0x05D9 + [char]0x05D5 + [char]0x05D7 + [char]0x05D3 + [char]0x05EA
        if ($section -match ("\*\*" + [regex]::Escape($specialMarker) + "\*?\*?:?\s*(.+)")) {
            $specialCat = $Matches[1].Trim()
        }

        $needling = ""
        $depthMarker = [char]0x05E2 + [char]0x05D5 + [char]0x05DE + [char]0x05E7 + " " + [char]0x05D3 + [char]0x05E7 + [char]0x05D9 + [char]0x05E8 + [char]0x05D4
        if ($section -match ("\*\*" + [regex]::Escape($depthMarker) + ":?\*?\*?:?\s*(.+)")) {
            $needling = $Matches[1].Trim()
        }

        $points += [PSCustomObject]@{
            PointId      = $pointId
            ChannelCode  = $channelCode
            PointNumber  = $pointNum
            ChineseName  = $chineseName
            Pinyin       = $pinyin
            Location     = $location
            HowToFind    = $howToFind
            Needling     = $needling
            SpecialCat   = $specialCat
        }
    }

    return $points
}

$meridiansDir = Join-Path $RepoRoot "year-1-foundations\module-02-meridians"
$mdFiles = Get-ChildItem -LiteralPath $meridiansDir -File -Filter "*.md" |
    Where-Object { $_.Name -match '^\d{2}-' -and $_.Name -ne '01-meridian-system.md' } |
    Sort-Object Name

Write-Host "Scanning $($mdFiles.Count) channel files in $meridiansDir"

$allPrompts = @()
$skipped = 0

foreach ($md in $mdFiles) {
    $points = Get-PointSections -FilePath $md.FullName

    foreach ($pt in $points) {
        if ($Channel -and $pt.ChannelCode -ne $Channel.ToUpper()) { continue }
        if ($filterPoints -and -not $filterPoints.ContainsKey($pt.PointId)) {
            $skipped++
            continue
        }

        $bodyRegion = if ($bodyRegionMap.ContainsKey($pt.ChannelCode)) { $bodyRegionMap[$pt.ChannelCode] } else { "body" }
        $chName = if ($channelNames.ContainsKey($pt.ChannelCode)) { $channelNames[$pt.ChannelCode] } else { $pt.ChannelCode }

        $locationText = if ($pt.Location) { $pt.Location } else { "(no location data extracted)" }
        $howToFindText = if ($pt.HowToFind) { $pt.HowToFind } else { "(no palpation steps extracted)" }

        $prompt = "Create a clean, simplified medical schematic diagram for acupuncture point $($pt.PointId) ($($pt.Pinyin)).`n"
        $prompt += "`nSTYLE REQUIREMENTS:`n"
        $prompt += "- Simple line-drawing style, similar to a medical textbook illustration`n"
        $prompt += "- Clean black outlines on white/light background`n"
        $prompt += "- Minimal anatomical detail: only show structures needed for point location`n"
        $prompt += "- Use a single red dot to mark the exact point location`n"
        $prompt += "- Label the point with `"$($pt.PointId)`" and key anatomical landmarks`n"
        $prompt += "- Include a thin blue line showing the $chName meridian path in this region`n"
        $prompt += "- Show cun measurements where relevant`n"
        $prompt += "- NO realistic shading, NO photorealistic rendering`n"
        $prompt += "- Professional, educational appearance`n"
        $prompt += "`nANATOMICAL CONTEXT:`n"
        $prompt += "- Body region: $bodyRegion`n"
        $prompt += "- Channel: $chName ($($pt.ChannelCode))`n"
        $prompt += "`nPOINT LOCATION:`n$locationText`n"
        $prompt += "`nLANDMARKS AND PALPATION:`n$howToFindText"

        $allPrompts += [PSCustomObject]@{
            point_id         = $pt.PointId
            channel          = $pt.ChannelCode
            channel_name     = $chName
            point_number     = $pt.PointNumber
            chinese_name     = $pt.ChineseName
            pinyin           = $pt.Pinyin
            location         = $locationText
            how_to_find      = $howToFindText
            needling         = $pt.Needling
            special_category = $pt.SpecialCat
            image_path       = "images/points/$($pt.ChannelCode)/$($pt.PointId).png"
            prompt           = $prompt
        }
    }
}

$json = $allPrompts | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($OutputJson, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "=== Generation Summary ==="
Write-Host "Total prompts generated: $($allPrompts.Count)"
if ($skipped -gt 0) { Write-Host "Skipped (not in audit filter): $skipped" }
Write-Host "Output: $OutputJson"

$byChannel = $allPrompts | Group-Object channel | Sort-Object Name
foreach ($g in $byChannel) {
    Write-Host "  $($g.Name): $($g.Count) points"
}

Write-Host ""
Write-Host "Usage:"
Write-Host "  - Use with OpenAI DALL-E API: feed each 'prompt' field to the API"
Write-Host "  - Use with ChatGPT: copy a prompt and paste in a conversation"
Write-Host "  - Filter by channel: -Channel SI"
Write-Host "  - Filter by audit:   -AuditCsv images\image-audit.csv"
