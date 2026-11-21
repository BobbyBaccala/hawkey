# Runs every tests/test_*.gd headless, two at a time, one log per suite in
# build/test-logs/. Exit code 1 if any suite failed.
#   powershell -File tools/run_tests.ps1 [-Jobs 2] [-Godot godot]
param([int]$Jobs = 2, [string]$Godot = "godot")
Set-Location (Join-Path $PSScriptRoot "..")
New-Item -ItemType Directory -Force build/test-logs | Out-Null
Remove-Item build/test-logs/* -ErrorAction SilentlyContinue
$running = @()
foreach ($s in Get-ChildItem tests/test_*.gd) {
    while (@($running | Where-Object { -not $_.HasExited }).Count -ge $Jobs) { Start-Sleep -Seconds 2 }
    $log = "build/test-logs/$($s.BaseName).log"
    $p = Start-Process -FilePath $Godot -ArgumentList "--headless", "--script", "tests/$($s.Name)" `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err" -NoNewWindow -PassThru
    $p | Add-Member -NotePropertyName Suite -NotePropertyValue $s.BaseName
    $running += $p
}
$results = @{}
foreach ($p in $running) { $p.WaitForExit(); $results[$p.Suite] = $p.ExitCode }
$bad = @($results.GetEnumerator() | Where-Object { $_.Value -ne 0 })
$fails = @(Select-String -Path build/test-logs/test_*.log -Pattern "FAIL" -List | ForEach-Object { $_.Path })
"suites: $($results.Count)"
if ($bad.Count) { "non-zero exits:"; $bad | ForEach-Object { "  $($_.Key) $($_.Value)" } }
if ($fails.Count) { "logs with FAIL lines:"; $fails }
if (-not $bad.Count -and -not $fails.Count) { "all passed"; exit 0 }
exit 1
