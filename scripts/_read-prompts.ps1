$json = Get-Content "c:\#personal\acuponctura\scripts\image-prompts.json" -Raw | ConvertFrom-Json
$points = @("SI3", "SI8", "SI11", "SI19")
foreach ($p in $points) {
    $item = $json | Where-Object { $_.pointId -eq $p }
    if ($item) {
        Write-Host "=== $p ==="
        Write-Host "Location: $($item.location)"
        Write-Host "HowToFind: $($item.howToFind)"
        Write-Host ""
    }
}
