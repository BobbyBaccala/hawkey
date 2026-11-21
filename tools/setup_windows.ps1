# One-time setup of Hawkey for Claude Code on Windows.
# Run from any folder:  powershell -ExecutionPolicy Bypass -File setup_windows.ps1
# It clones (or updates) the repo, puts Godot 4.6.2 next to it and on PATH for
# this user, checks Blender and Claude Code, then tells you how to start.
param(
    [string]$Root = "$env:USERPROFILE\Documents\Hawkey",
    [string]$Branch = "prototype/skating-puck-lab"
)
$ErrorActionPreference = "Stop"
$repo = Join-Path $Root "hawkey"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git is missing. Install it from https://git-scm.com/download/win, then run this again." -ForegroundColor Yellow
    exit 1
}
New-Item -ItemType Directory -Force $Root | Out-Null
if (-not (Test-Path (Join-Path $repo ".git"))) {
    git clone https://github.com/BobbyBaccala/hawkey.git $repo
}
Push-Location $repo
git fetch origin
git checkout $Branch
git pull --rebase origin $Branch
Pop-Location

# Godot 4.6.2 (the version the tests are run with).
$godotDir = Join-Path $Root "godot-4.6.2"
$godotExe = Join-Path $godotDir "Godot_v4.6.2-stable_win64_console.exe"
if (-not (Test-Path $godotExe)) {
    New-Item -ItemType Directory -Force $godotDir | Out-Null
    $zip = Join-Path $godotDir "godot.zip"
    Invoke-WebRequest "https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_win64.exe.zip" -OutFile $zip
    Expand-Archive $zip -DestinationPath $godotDir -Force
    Remove-Item $zip
}
# A "godot" command on PATH for this user (copy of the console build).
$shim = Join-Path $godotDir "godot.exe"
if (-not (Test-Path $shim)) { Copy-Item $godotExe $shim }
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$godotDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$godotDir", "User")
    $env:Path += ";$godotDir"
}

$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
if (Test-Path $blender) { Write-Host "Blender found: $blender" } else { Write-Host "Blender 5.2 not found (only needed for model jobs)." -ForegroundColor Yellow }

Write-Host "Importing the Godot project (first time takes a few minutes)..."
Push-Location $repo
& $shim --headless --import | Out-Null
Pop-Location

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "Claude Code is not installed yet. Install it (see https://docs.claude.com/en/docs/claude-code), then:" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Ready. Start working with:" -ForegroundColor Green
Write-Host "  cd `"$repo`""
Write-Host "  claude"
Write-Host "Then type /next-run (or /next-run goalie pads) to do a run."
