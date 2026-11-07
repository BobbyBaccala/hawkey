# Hawkey Blender bridge: runs Blender scripts dropped into jobs\ headlessly
# and writes their logs and outputs to out\. Close this window to stop it.
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$jobs = Join-Path $root "jobs"; $out = Join-Path $root "out"; $done = Join-Path $root "done"
New-Item -ItemType Directory -Force -Path $jobs, $out, $done | Out-Null

function Find-Blender {
  $cmd = Get-Command blender -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $roots = @("$env:ProgramFiles\Blender Foundation", "${env:ProgramFiles(x86)}\Blender Foundation",
             "$env:LOCALAPPDATA\Programs\Blender Foundation",
             "${env:ProgramFiles(x86)}\Steam\steamapps\common\Blender", "$env:ProgramFiles\Steam\steamapps\common\Blender")
  $found = @()
  foreach ($r in $roots) { if (Test-Path $r) { $found += Get-ChildItem -Path $r -Recurse -Filter blender.exe -ErrorAction SilentlyContinue -Depth 2 } }
  $store = Get-ChildItem "$env:ProgramFiles\WindowsApps" -Directory -Filter "BlenderFoundation*" -ErrorAction SilentlyContinue
  foreach ($s in $store) { $found += Get-ChildItem $s.FullName -Filter blender.exe -ErrorAction SilentlyContinue }
  if ($found.Count -gt 0) { return ($found | Sort-Object FullName -Descending | Select-Object -First 1).FullName }
  return $null
}

$blender = Find-Blender
$status = Join-Path $root "status.txt"
if (-not $blender) {
  "NO_BLENDER: blender.exe not found. Put its full path on one line in blender_path.txt next to this script." | Set-Content $status
  $manual = Join-Path $root "blender_path.txt"
  if (Test-Path $manual) { $blender = (Get-Content $manual -First 1).Trim('"', ' ') }
}
if (-not $blender -or -not (Test-Path $blender)) {
  Write-Host "Blender not found. Create blender_path.txt with the path to blender.exe, then run again." -ForegroundColor Red
  Read-Host "Press Enter to close"; exit 1
}
"READY $blender $(Get-Date -Format s)" | Set-Content $status
Write-Host "Hawkey Blender bridge running with $blender" -ForegroundColor Green
Write-Host "Watching $jobs  (close this window to stop)"

while ($true) {
  Get-ChildItem $jobs -Filter *.ready -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
    $name = $_.BaseName
    $script = Join-Path $jobs "$name.py"
    $log = Join-Path $out "$name.log"
    Remove-Item $_.FullName -Force
    if (-not (Test-Path $script)) { "missing $name.py" | Set-Content $log; return }
    Write-Host "$(Get-Date -Format T)  running $name ..." -ForegroundColor Cyan
    "RUNNING $name $(Get-Date -Format s)" | Set-Content $status
    $p = Start-Process -FilePath $blender -ArgumentList @("-b", "--factory-startup", "--python-exit-code", "1", "--python", "`"$script`"", "--", "`"$root`"") `
         -NoNewWindow -PassThru -Wait -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    "exit $($p.ExitCode) $(Get-Date -Format s)" | Set-Content (Join-Path $out "$name.done")
    Move-Item $script (Join-Path $done "$name.py") -Force
    "READY $blender $(Get-Date -Format s)" | Set-Content $status
    Write-Host "$(Get-Date -Format T)  finished $name (exit $($p.ExitCode))"
  }
  Start-Sleep -Seconds 2
}
