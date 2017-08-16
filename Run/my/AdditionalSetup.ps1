Write-Host "Running additional setup.."

# if theres no local user then it's the first run
$firstRun = (Get-LocalUser | Where-Object { $_.Enabled }).Count -eq 0
$interactive = $env:NonInteractive -ne 'Y'

if ($interactive -and $firstRun -and $runningSpecificImage) {
    . (Join-Path $myPath '_createUser.ps1')
}