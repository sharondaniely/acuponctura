<#
.SYNOPSIS
    Adds external reference links and Wikimedia channel charts to acupuncture point markdown files.

.DESCRIPTION
    For each point in a channel markdown file:
    - Adds a reference links block after the existing image with links to
      AcuMeridianPoints and YinYangHouse online atlases.
    For each channel file:
    - Downloads the CC-BY-4.0 Wikimedia Commons historical channel chart
      into images/references/
    - Inserts a reference to this chart in section 1.2 (Channel Path)

.PARAMETER RepoRoot
    Path to the acuponctura repository root. Defaults to parent of scripts/.

.PARAMETER Channel
    Channel code to process (e.g., 'SI', 'LU'). If omitted, processes all channels.

.PARAMETER SkipDownload
    If set, skips downloading Wikimedia chart images (use if already downloaded).

.PARAMETER DryRun
    If set, shows what would be changed without modifying files.
#>
[CmdletBinding()]
param(
    [string] $RepoRoot = "",
    [string] $Channel = "",
    [switch] $SkipDownload,
    [switch] $DryRun
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$refsDir = Join-Path $RepoRoot "images\references"
if (-not (Test-Path -LiteralPath $refsDir)) {
    New-Item -ItemType Directory -Path $refsDir | Out-Null
}

# --- Channel metadata ---
$channelData = @{
    "LU" = @{
        File = "02-lung-channel.md"
        AcuMeridianSlug = "lung"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/56/Chinese_MS_acu-moxa_point_chart%3B_Lung_channel_Wellcome_L0039516.jpg/960px-Chinese_MS_acu-moxa_point_chart%3B_Lung_channel_Wellcome_L0039516.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
    "LI" = @{
        File = "03-large-intestine.md"
        AcuMeridianSlug = "large-intestine"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/2/26/Chinese_MS_acu-moxa_point_chart%3B_Large_Intestine_Wellcome_L0039517.jpg/960px-Chinese_MS_acu-moxa_point_chart%3B_Large_Intestine_Wellcome_L0039517.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
    "ST" = @{
        File = "04-stomach-channel.md"
        AcuMeridianSlug = "stomach"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Chinese_MS_acu-moxa_point_chart%3B_Stomach_Wellcome_L0039518.jpg/960px-Chinese_MS_acu-moxa_point_chart%3B_Stomach_Wellcome_L0039518.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
    "SP" = @{
        File = "05-spleen-channel.md"
        AcuMeridianSlug = "spleen"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/60/Chinese_MS_acu-moxa_point_chart%3B_Spleen_channel_Wellcome_L0039519.jpg/960px-Chinese_MS_acu-moxa_point_chart%3B_Spleen_channel_Wellcome_L0039519.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
    "HT" = @{
        File = "06-heart-channel.md"
        AcuMeridianSlug = "heart"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Chinese_MS_acu-moxa_point_chart%3BHeart_channel_Wellcome_L0039520.jpg/960px-Chinese_MS_acu-moxa_point_chart%3BHeart_channel_Wellcome_L0039520.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
    "SI" = @{
        File = "07-small-intestine.md"
        AcuMeridianSlug = "small-intestine"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ac/Acupuncture_chart%2C_small_intestine_channel_of_hand_taiyang_Wellcome_L0037835.jpg/800px-Acupuncture_chart%2C_small_intestine_channel_of_hand_taiyang_Wellcome_L0037835.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
    "KI" = @{
        File = "09-kidney-channel.md"
        AcuMeridianSlug = "kidney"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/1/16/Chinese_MS_acu-moxa_point_chart%3B_Kidney_channel_Wellcome_L0039523.jpg/960px-Chinese_MS_acu-moxa_point_chart%3B_Kidney_channel_Wellcome_L0039523.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
    "PC" = @{
        File = "10-pericardium.md"
        AcuMeridianSlug = "pericardium"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Chinese_MS_acu-moxa_point_chart%3B_Pericardium_channel_Wellcome_L0039524.jpg/960px-Chinese_MS_acu-moxa_point_chart%3B_Pericardium_channel_Wellcome_L0039524.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
    "TE" = @{
        File = "11-triple-energizer.md"
        AcuMeridianSlug = "triple-energizer"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c7/Chinese_MS_acu-moxa_point_chart%3B_Triple_Burner_channel_Wellcome_L0039525.jpg/960px-Chinese_MS_acu-moxa_point_chart%3B_Triple_Burner_channel_Wellcome_L0039525.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
    "GB" = @{
        File = "12-gallbladder.md"
        AcuMeridianSlug = "gallbladder"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e9/Chinese_MS_acu-moxa_point_chart%3B_Gall_bladder_channel_Wellcome_L0039514.jpg/960px-Chinese_MS_acu-moxa_point_chart%3B_Gall_bladder_channel_Wellcome_L0039514.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
    "LR" = @{
        File = "13-liver-channel.md"
        AcuMeridianSlug = "liver"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/Chinese_MS_acu-moxa_point_chart%3B_Liver_channel_Wellcome_L0039515.jpg/960px-Chinese_MS_acu-moxa_point_chart%3B_Liver_channel_Wellcome_L0039515.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
    "DU" = @{
        File = "14-extraordinary-vessels.md"
        AcuMeridianSlug = "governing-vessel"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/e/ed/Channel_chart%3B_dumai_%28Governor_Vessel%29%2C_Chinese_woodcut_Wellcome_L0037913.jpg/960px-Channel_chart%3B_dumai_%28Governor_Vessel%29%2C_Chinese_woodcut_Wellcome_L0037913.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
    "REN" = @{
        File = "14-extraordinary-vessels.md"
        AcuMeridianSlug = "conception-vessel"
        WikiThumbUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f4/Acupuncture_chart%2C_renmai_%28the_Director_Vessel%29_Wellcome_L0037828.jpg/960px-Acupuncture_chart%2C_renmai_%28the_Director_Vessel%29_Wellcome_L0037828.jpg"
        WikiAttribution = "Wellcome Collection, CC-BY-4.0"
    }
}

# Pinyin fallback for channels whose headers lack romanized pinyin (LU, LI, ST)
$pinyinFallback = @{
    "LU1" = "zhongfu"; "LU2" = "yunmen"; "LU3" = "tianfu"; "LU4" = "xiabai"
    "LU5" = "chize"; "LU6" = "kongzui"; "LU7" = "lieque"; "LU8" = "jingqu"
    "LU9" = "taiyuan"; "LU10" = "yuji"; "LU11" = "shaoshang"
    "LI1" = "shangyang"; "LI2" = "erjian"; "LI3" = "sanjian"; "LI4" = "hegu"
    "LI5" = "yangxi"; "LI6" = "pianli"; "LI7" = "wenliu"; "LI8" = "xialian"
    "LI9" = "shanglian"; "LI10" = "shousanli"; "LI11" = "quchi"; "LI12" = "zhouliao"
    "LI13" = "shouwuli"; "LI14" = "binao"; "LI15" = "jianyu"; "LI16" = "jugu"
    "LI17" = "tianding"; "LI18" = "futu"; "LI19" = "kouheliao"; "LI20" = "yingxiang"
    "ST1" = "chengqi"; "ST2" = "sibai"; "ST3" = "juliao"; "ST4" = "dicang"
    "ST5" = "daying"; "ST6" = "jiache"; "ST7" = "xiaguan"; "ST8" = "touwei"
    "ST9" = "renying"; "ST10" = "shuitu"; "ST11" = "qishe"; "ST12" = "quepen"
    "ST13" = "qihu"; "ST14" = "kufang"; "ST15" = "wuyi"; "ST16" = "yingchuang"
    "ST17" = "ruzhong"; "ST18" = "rugen"; "ST19" = "burong"; "ST20" = "chengman"
    "ST21" = "liangmen"; "ST22" = "guanmen"; "ST23" = "taiyi"; "ST24" = "huaroumen"
    "ST25" = "tianshu"; "ST26" = "wailing"; "ST27" = "daju"; "ST28" = "shuidao"
    "ST29" = "guilai"; "ST30" = "qichong"; "ST31" = "biguan"; "ST32" = "futu"
    "ST33" = "yinshi"; "ST34" = "liangqiu"; "ST35" = "dubi"; "ST36" = "zusanli"
    "ST37" = "shangjuxu"; "ST38" = "tiaokou"; "ST39" = "xiajuxu"; "ST40" = "fenglong"
    "ST41" = "jiexi"; "ST42" = "chongyang"; "ST43" = "xiangu"; "ST44" = "neiting"
    "ST45" = "lidui"
}

function Remove-Diacritics {
    param([string] $Text)
    $normalized = $Text.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $normalized.ToCharArray()) {
        $cat = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
        if ($cat -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    return $sb.ToString()
}

function Get-PinyinSlug {
    param([string] $Pinyin)
    $clean = Remove-Diacritics -Text $Pinyin
    $clean = $clean.Trim() -replace '\s+', '' -replace '[^a-zA-Z]', ''
    return $clean.ToLower()
}

function Build-AcuMeridianUrl {
    param([string] $ChannelSlug, [string] $PointCode, [int] $PointNum, [string] $PinyinSlug)
    $code = $PointCode.ToLower()
    return "https://acumeridianpoints.com/$ChannelSlug/$code-$PointNum-$PinyinSlug/"
}

function Build-YinYangHouseUrl {
    param([string] $PointCode, [int] $PointNum)
    $code = $PointCode.ToLower()
    return "https://yinyanghouse.com/theory/acupuncturepoints/$code$PointNum/"
}

# --- Process channels ---
$meridiansDir = Join-Path $RepoRoot "year-1-foundations\module-02-meridians"
$channelsToProcess = if ($Channel) { @($Channel.ToUpper()) } else { $channelData.Keys | Sort-Object }

$totalPoints = 0
$totalFiles = 0
$chartsDownloaded = 0

foreach ($ch in $channelsToProcess) {
    if (-not $channelData.ContainsKey($ch)) {
        Write-Warning "Unknown channel: $ch"
        continue
    }

    $info = $channelData[$ch]
    $mdPath = Join-Path $meridiansDir $info.File

    if (-not (Test-Path -LiteralPath $mdPath)) {
        Write-Warning "File not found: $mdPath"
        continue
    }

    Write-Host "Processing $ch channel: $($info.File)"

    # --- Download Wikimedia chart ---
    $chartFile = Join-Path $refsDir "$ch-channel-chart-wellcome.jpg"
    if (-not $SkipDownload -and -not (Test-Path -LiteralPath $chartFile)) {
        if (-not $DryRun) {
            Write-Host "  Downloading Wikimedia chart for $ch..."
            try {
                Invoke-WebRequest -Uri $info.WikiThumbUrl -OutFile $chartFile -ErrorAction Stop
                $chartsDownloaded++
                Write-Host "  Downloaded: $chartFile"
            } catch {
                Write-Warning "  Failed to download chart for $ch`: $_"
            }
        } else {
            Write-Host "  [DRY RUN] Would download chart for $ch"
        }
    } elseif (Test-Path -LiteralPath $chartFile) {
        Write-Host "  Chart already exists: $chartFile"
    }

    # --- Read and modify markdown ---
    $content = [System.IO.File]::ReadAllText($mdPath, [System.Text.Encoding]::UTF8)

    # Extract point headers and their pinyin
    $headerPattern = '(?m)^###\s+(([A-Z]{2,3})(\d+))\s*[-\u2014\u2013]\s*(.+?)(?:\r?\n)'
    $headerMatches = [regex]::Matches($content, $headerPattern)

    $pointsAdded = 0

    # Process in reverse order so insertion indices stay valid
    $matchList = @()
    foreach ($m in $headerMatches) { $matchList += $m }
    [Array]::Reverse($matchList)

    foreach ($m in $matchList) {
        $pointId = $m.Groups[1].Value.Trim()
        $channelCode = $m.Groups[2].Value
        $pointNum = [int]$m.Groups[3].Value
        $headerRest = $m.Groups[4].Value.Trim()

        if ($channelCode -ne $ch) { continue }

        # Extract romanized pinyin from header (last segment after ` - `)
        $pinyinRoman = ""
        $parts = $headerRest -split '\s*[-\u2014\u2013]\s*'
        foreach ($part in $parts) {
            $trimmed = $part.Trim().Trim('"', [char]0x201C, [char]0x201D)
            if ($trimmed -match '^[A-Za-z\u00C0-\u024F\s]+$' -and $trimmed.Length -gt 1) {
                $pinyinRoman = $trimmed
            }
        }

        if (-not $pinyinRoman) {
            if ($headerRest -match '\)\s*[-\u2014\u2013]\s*([A-Za-z\u00C0-\u024F\s]+)') {
                $pinyinRoman = $Matches[1].Trim()
            }
        }

        $pinyinSlug = if ($pinyinRoman) { Get-PinyinSlug -Pinyin $pinyinRoman } else { "" }

        # Fallback to hardcoded pinyin lookup for channels without romanized pinyin in headers
        if (-not $pinyinSlug -and $pinyinFallback.ContainsKey($pointId)) {
            $pinyinSlug = $pinyinFallback[$pointId]
        }

        # Find the image line for this point
        $sectionStart = $m.Index + $m.Length
        $sectionEnd = $content.Length
        for ($i = $matchList.IndexOf($m) - 1; $i -ge 0; $i--) {
            if ($matchList[$i].Index -gt $m.Index) {
                $sectionEnd = $matchList[$i].Index
                break
            }
        }
        # Actually, since we reversed, the "next" point (in file order) has a smaller index in matchList
        # Re-find section end by searching forward in original content
        $nextHeaderIdx = $content.IndexOf("`n### ", $sectionStart)
        if ($nextHeaderIdx -gt 0) { $sectionEnd = $nextHeaderIdx }

        $section = $content.Substring($sectionStart, $sectionEnd - $sectionStart)

        # Find the image line position
        $imgPattern = "!\[$pointId\]"
        $imgMatch = [regex]::Match($section, $imgPattern)
        if (-not $imgMatch.Success) { continue }

        # Find the end of the image line
        $imgAbsPos = $sectionStart + $imgMatch.Index
        $lineEnd = $content.IndexOf("`n", $imgAbsPos)
        if ($lineEnd -lt 0) { $lineEnd = $content.Length }

        # Build reference links
        $acuUrl = if ($pinyinSlug) {
            Build-AcuMeridianUrl -ChannelSlug $info.AcuMeridianSlug -PointCode $channelCode -PointNum $pointNum -PinyinSlug $pinyinSlug
        } else { "" }
        $yyhUrl = Build-YinYangHouseUrl -PointCode $channelCode -PointNum $pointNum

        $linkParts = @()
        if ($acuUrl) { $linkParts += "[AcuMeridianPoints]($acuUrl)" }
        $linkParts += "[YinYangHouse]($yyhUrl)"
        $linksStr = $linkParts -join " | "

        # Check if reference links already exist
        $afterImg = $content.Substring($lineEnd, [Math]::Min(300, $content.Length - $lineEnd))
        if ($afterImg -match 'AcuMeridianPoints') {
            continue
        }

        if ($afterImg -match '(?s)(\r?\n\r?\n> \*\*External References:\*\*\s*\[YinYangHouse\][^\n]+)') {
            # Upgrade existing YinYangHouse-only link to include AcuMeridianPoints
            if ($acuUrl) {
                $oldBlock = $Matches[1]
                $newBlock = "`n`n> **External References:** $linksStr"
                if ($DryRun) {
                    Write-Host "  [DRY RUN] UPGRADE $pointId : $linksStr"
                } else {
                    $content = $content.Remove($lineEnd, $oldBlock.Length)
                    $content = $content.Insert($lineEnd, $newBlock)
                }
                $pointsAdded++
            }
            continue
        }

        if ($afterImg -match 'YinYangHouse') {
            continue
        }

        $refBlock = "`n`n> **External References:** $linksStr"

        if ($DryRun) {
            Write-Host "  [DRY RUN] $pointId : $linksStr"
        } else {
            $content = $content.Insert($lineEnd, $refBlock)
        }
        $pointsAdded++
    }

    # --- Insert channel chart reference in section 1.2 ---
    $chartInserted = $false
    if ((Test-Path -LiteralPath $chartFile) -or $DryRun) {
        $chartRelPath = "../../../images/references/$ch-channel-chart-wellcome.jpg"
        $chartMarker = "$ch-channel-chart-wellcome"

        if ($content -notmatch [regex]::Escape($chartMarker)) {
            $insertPattern = '(?m)(###\s*1\.2\s+[^\n]+\n)'
            if ($content -match $insertPattern) {
                $insertPos = $content.IndexOf($Matches[0]) + $Matches[0].Length
                $chartBlock = "`n> **Historical Reference Chart** ($($info.WikiAttribution)):`n> ![$ch Channel Chart]($chartRelPath)`n"

                if ($DryRun) {
                    Write-Host "  [DRY RUN] Would insert channel chart in section 1.2"
                } else {
                    $content = $content.Insert($insertPos, $chartBlock)
                    $chartInserted = $true
                }
            }
        }
    }

    if (-not $DryRun -and ($pointsAdded -gt 0 -or $chartInserted)) {
        [System.IO.File]::WriteAllText($mdPath, $content, [System.Text.UTF8Encoding]::new($false))
    }

    Write-Host "  Points with references added: $pointsAdded"
    $totalPoints += $pointsAdded
    $totalFiles++
}

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Channels processed:  $totalFiles"
Write-Host "Points with links:   $totalPoints"
Write-Host "Charts downloaded:   $chartsDownloaded"
if ($DryRun) { Write-Host "[DRY RUN] No files were modified." }
