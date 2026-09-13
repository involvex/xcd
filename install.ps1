[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$NoProfile
)

$ErrorActionPreference = 'Stop'
Write-Host "xcd Installer" -ForegroundColor Cyan
Write-Host "=============" -ForegroundColor Cyan
Write-Host ""

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "xcd requires PowerShell 7+. Current version: $($PSVersionTable.PSVersion)"
    Write-Host "Install PowerShell 7+ from: https://github.com/PowerShell/PowerShell" -ForegroundColor Yellow
    exit 1
}

$repoOwner = 'involvex'
$repoName = 'xcd'
$branch = 'main'
$baseUrl = "https://raw.githubusercontent.com/$repoOwner/$repoName/refs/heads/$branch"

$moduleName = 'Xcd'
$modulePath = Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules\Xcd'
$files = @('Xcd.psd1', 'Xcd.psm1', 'Readme.md', 'Plan.md', 'Agents.md')

# Check if already installed
if ((Test-Path $modulePath) -and (-not $Force)) {
    Write-Host "xcd is already installed at: $modulePath" -ForegroundColor Yellow
    Write-Host "Use -Force to reinstall." -ForegroundColor Yellow
    exit 0
}

# Create module directory
Write-Host "Installing to: $modulePath" -ForegroundColor Green
if (-not (Test-Path $modulePath)) {
    New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
}

# Download files
Write-Host "Downloading module files..." -ForegroundColor Green
$failed = @()
foreach ($file in $files) {
    $url = "$baseUrl/$file"
    $dest = Join-Path $modulePath $file
    try {
        Write-Host "  $file..." -NoNewline
        Invoke-RestMethod -Uri $url -OutFile $dest -ErrorAction Stop
        Write-Host " OK" -ForegroundColor Green
    }
    catch {
        Write-Host " FAILED" -ForegroundColor Red
        $failed += $file
        Write-Error "Failed to download ${file}: $($_.Exception.Message)"
    }
}

if ($failed.Count -gt 0) {
    Write-Error "Installation incomplete. Failed files: $($failed -join ', ')"
    exit 1
}

# Verify installation
Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Green
try {
    Import-Module $modulePath -Force -ErrorAction Stop
    $version = (Get-Module Xcd).Version
    Write-Host "  Module version: $version" -ForegroundColor Green
    Write-Host "  Module path: $modulePath" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import module: $($_.Exception.Message)"
    exit 1
}

# Profile instructions
$profilePath = $PROFILE.CurrentUserAllHosts
$importLine = "Import-Module Xcd"

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Cyan
Write-Host ""

if (-not $NoProfile) {
    if (Test-Path $profilePath) {
        $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($profileContent -notmatch [regex]::Escape($importLine)) {
            Write-Host "Add the following to your PowerShell profile ($profilePath):" -ForegroundColor Yellow
            Write-Host "  $importLine" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Or run this to append it automatically:" -ForegroundColor Yellow
            Write-Host "  Add-Content -Path `'$profilePath`' -Value `'$importLine`'" -ForegroundColor Cyan
        }
        else {
            Write-Host "xcd is already in your profile." -ForegroundColor Green
        }
    }
    else {
        Write-Host "No profile found at $profilePath" -ForegroundColor Yellow
        Write-Host "Create one and add:" -ForegroundColor Yellow
        Write-Host "  $importLine" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "Quick test:" -ForegroundColor Green
Write-Host "  xcd              # List current directory with git status" -ForegroundColor Cyan
Write-Host "  xcd -ShowConfig  # Show configuration" -ForegroundColor Cyan
Write-Host ""
Write-Host "Optional: Replace cd entirely" -ForegroundColor Yellow
Write-Host "  Set-Alias cd xcd" -ForegroundColor Cyan