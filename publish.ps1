Set-Location "C:\#personal\acuponctura"
git add -A
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
git commit -m "Update content - $timestamp"
git push
Write-Host "`nDone! GitBook will update in a few seconds." -ForegroundColor Green
