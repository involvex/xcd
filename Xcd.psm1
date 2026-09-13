<#
.SYNOPSIS
    Smart directory navigation and file viewing (extended cd).

.DESCRIPTION
    Enhanced cd replacement that intelligently handles paths:
    - No arguments: lists current directory with git status
    - Directory: changes to it (Set-Location)
    - Markdown file: opens in preferred terminal viewer
    - Image file: displays in terminal (catimg)
    - Other file: displays with syntax highlighting (bat) or raw content
    - Supports ~, environment variables, and relative paths

.PARAMETER Path
    Target path. Supports ~, $env:VAR, relative paths. If omitted, lists current directory.
    Accepts multiple arguments joined as a single path (ValueFromRemainingArguments).

.EXAMPLE
    xcd
    Lists current directory with enhanced output.

.EXAMPLE
    xcd ~/projects
    Changes to $HOME/projects.

.EXAMPLE
    xcd ./README.md
    Opens README.md in markdown viewer (glow, mdcat, bat, or fallback).

.EXAMPLE
    xcd src/main.ts
    Displays TypeScript file with syntax highlighting (bat) or Get-Content.

.EXAMPLE
    xcd image.png
    Displays image in terminal using catimg.

.NOTES
    Requires PowerShell 7+ for best experience.
    Optional dependencies: glow, mdcat, bat, bun, catimg, git.
    Configure via ~/.xcd.json or environment variables:
    - XCD_MD_VIEWER: markdown viewer (glow, mdcat, bun, bat)
    - XCD_IMAGE_VIEWER: image viewer (catimg)
    - XCD_SHOW_HIDDEN: show hidden files (true/false)
    - XCD_GIT_STATUS: show git status in listing (true/false)
    - XCD_COLORS: color scheme (default, dark, light)
#>

function xcd {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(
            Position = 0,
            ValueFromRemainingArguments = $true,
            ParameterSetName = 'Path'
        )]
        [string[]]$Path,

        [Parameter(ParameterSetName = 'Config')]
        [switch]$EditConfig,

        [Parameter(ParameterSetName = 'Config')]
        [switch]$ShowConfig
    )

    # Load config
    $script:XcdConfig = Get-XcdConfig

    # --- Config management ---
    if ($EditConfig) {
        return Edit-XcdConfig
    }
    if ($ShowConfig) {
        return Show-XcdConfig
    }

    # --- Resolve target path ---
    $target = Resolve-XcdPath -Path $Path
    if (-not $target) {
        return Show-XcdDirectory
    }

    # --- Handle based on type ---
    if (Test-Path -Path $target -PathType Leaf) {
        return Invoke-XcdFile -Path $target
    }
    if (Test-Path -Path $target -PathType Container) {
        return Set-Location -Path $target
    }

    # Fallback: let PowerShell handle it (aliases, drives, etc.)
    try {
        Set-Location -Path $target -ErrorAction Stop
    }
    catch {
        Write-Error "xcd: Cannot navigate to '$target': $($_.Exception.Message)"
        return 1
    }
}

# ============================================================================
# Config Management
# ============================================================================

function Get-XcdConfig {
    $configPath = Join-Path $HOME '.xcd.json'
$defaultConfig = @{
        MarkdownViewer  = 'auto'   # auto, glow, mdcat, bun, bat, cat
        ImageViewer     = 'auto'   # auto, catimg
        ShowHidden      = $true
        GitStatus       = $true
        Colors          = 'default' # default, dark, light
        Icons           = $true
    }

    if (Test-Path $configPath) {
        try {
            $json = Get-Content $configPath -Raw | ConvertFrom-Json
            $merged = @{}
            foreach ($key in $defaultConfig.Keys) {
                $merged[$key] = if ($json.PSObject.Properties[$key]) { $json.$key } else { $defaultConfig[$key] }
            }
            return $merged
        }
        catch {
            Write-Warning "xcd: Failed to parse $configPath, using defaults"
            return $defaultConfig
        }
    }

    # Check environment variables as fallback
    $envConfig = @{}
    if ($env:XCD_MD_VIEWER)     { $envConfig.MarkdownViewer = $env:XCD_MD_VIEWER }
    if ($env:XCD_IMAGE_VIEWER)  { $envConfig.ImageViewer = $env:XCD_IMAGE_VIEWER }
    if ($env:XCD_SHOW_HIDDEN)   { $envConfig.ShowHidden = [bool]::Parse($env:XCD_SHOW_HIDDEN) }
    if ($env:XCD_GIT_STATUS)    { $envConfig.GitStatus = [bool]::Parse($env:XCD_GIT_STATUS) }
    if ($env:XCD_COLORS)        { $envConfig.Colors = $env:XCD_COLORS }
    if ($env:XCD_ICONS)         { $envConfig.Icons = [bool]::Parse($env:XCD_ICONS) }

    $merged = @{}
    foreach ($key in $defaultConfig.Keys) {
        $merged[$key] = if ($envConfig.ContainsKey($key)) { $envConfig[$key] } else { $defaultConfig[$key] }
    }
    return $merged
}

function Save-XcdConfig {
    param([hashtable]$Config)
    $configPath = Join-Path $HOME '.xcd.json'
    try {
        $Config | ConvertTo-Json -Depth 3 | Set-Content $configPath -Encoding utf8
        Write-Host "Config saved to $configPath"
    }
    catch {
        Write-Error "xcd: Failed to save config: $($_.Exception.Message)"
        return 1
    }
}

function Edit-XcdConfig {
    $configPath = Join-Path $HOME '.xcd.json'
    if (-not (Test-Path $configPath)) {
        $defaultConfig = Get-XcdConfig
        Save-XcdConfig $defaultConfig
    }
    $editor = if ($env:EDITOR) { $env:EDITOR } elseif ($env:VISUAL) { $env:VISUAL } elseif (Get-Command code -ErrorAction SilentlyContinue) { 'code' } elseif (Get-Command notepad -ErrorAction SilentlyContinue) { 'notepad' } else { 'notepad' }
    & $editor $configPath
}

function Show-XcdConfig {
    $configPath = Join-Path $HOME '.xcd.json'
    $config = $script:XcdConfig
    Write-Host "xcd configuration:" -ForegroundColor Cyan
    Write-Host "  Config file: $configPath"
    Write-Host "  Exists: $(Test-Path $configPath)"
    Write-Host ""
    $config.GetEnumerator() | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)"
    }
}

# ============================================================================
# Helper Functions (private, not exported)
# ============================================================================

function Resolve-XcdPath {
    param([string[]]$Path)

    if (-not $Path -or ($Path.Count -eq 1 -and [string]::IsNullOrWhiteSpace($Path[0]))) {
        return $null
    }

    # Join remaining arguments as a single path (handles spaces without quotes)
    $raw = ($Path -join ' ').Trim()

    # Expand ~ to $HOME
    if ($raw -like '~*') {
        $raw = $raw -replace '^~', $HOME
    }

    # Expand environment variables ($env:VAR or ${env:VAR})
    $raw = $ExecutionContext.InvokeCommand.ExpandString($raw)

    # Resolve relative to current location
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($raw)

    return $resolved
}

function Show-XcdDirectory {
    param(
        [switch]$ForceHidden = $false
    )

    try {
        $showHidden = $script:XcdConfig.ShowHidden -or $ForceHidden
        $items = Get-ChildItem -Force:$showHidden -ErrorAction Stop |
            Sort-Object { $_.PSIsContainer }, Name

        # Check for git repo
        $gitStatus = @{}
        if ($script:XcdConfig.GitStatus -and (Test-Path .git)) {
            $gitOutput = git status --porcelain 2>$null
            if ($LASTEXITCODE -eq 0) {
                foreach ($line in $gitOutput -split "`n") {
                    if ($line -match '^(..)\s+(.+)$') {
                        $gitStatus[$matches[2]] = $matches[1]
                    }
                }
            }
        }

        $useIcons = $script:XcdConfig.Icons

        foreach ($item in $items) {
            $mode = $item.Mode.ToString()
            $name = $item.Name
            $git = if ($gitStatus.ContainsKey($name)) { " [$($gitStatus[$name])]" } else { "" }
            $type = if ($item.PSIsContainer) {
                if ($useIcons) { "📁" } else { "[DIR]" }
            } else {
                if ($useIcons) { "📄" } else { "[FILE]" }
            }
            Write-Host "$type $mode  $name$git"
        }
    }
    catch {
        Write-Error "xcd: Failed to list directory: $($_.Exception.Message)"
        return 1
    }
}

function Invoke-XcdFile {
    param([string]$Path)

    $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()

    # Image files
    $imageExts = @('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp', '.ico', '.tiff', '.tif', '.svg')
    if ($imageExts -contains $ext) {
        return Invoke-XcdImage -Path $Path
    }

    if ($ext -eq '.md') {
        return Invoke-XcdMarkdown -Path $Path
    }

    # Try bat for syntax highlighting, fallback to Get-Content
    if (Get-Command bat -ErrorAction SilentlyContinue) {
        try { return bat --style=plain --color=always $Path }
        catch { }
    }
    if (Get-Command batcat -ErrorAction SilentlyContinue) {
        try { return batcat --style=plain --color=always $Path }
        catch { }
    }

    Get-Content -Path $Path -Raw
}

function Invoke-XcdImage {
    param([string]$Path)

    $viewer = $script:XcdConfig.ImageViewer

    if ($viewer -eq 'auto' -or $viewer -eq 'catimg') {
        if (Get-Command catimg -ErrorAction SilentlyContinue) {
            try { return catimg $Path }
            catch { }
        }
    }

    # Fallback: show file info
    $item = Get-Item $Path
    Write-Host "Image: $($item.Name) ($([math]::Round($item.Length/1KB,1)) KB)"
    Write-Host "Dimensions: Use catimg module for preview"
}

function Invoke-XcdMarkdown {
    param([string]$Path)

    $viewer = $script:XcdConfig.MarkdownViewer

    # If auto, use priority order
    if ($viewer -eq 'auto') {
        $viewerPriority = @('glow', 'mdcat', 'bun', 'bat', 'cat')
    }
    else {
        $viewerPriority = @($viewer)
    }

    foreach ($v in $viewerPriority) {
        if ($v -eq 'cat') {
            Get-Content -Path $Path -Raw
            return
        }
        if ($v -eq 'bun') {
                try {
                    if ($IsWindows) {
                        & cmd.exe /c bun $Path
                    }
                    else {
                        bun $Path
                    }
                    return
                }
                catch { }
            }
        if (Get-Command $v -ErrorAction SilentlyContinue) {
            try {
                if ($v -eq 'bat' -or $v -eq 'batcat') {
                    return & $v --language=md --style=plain --color=always $Path
                }
                else {
                    return & $v $Path
                }
            }
            catch { }
        }
    }

    # Final fallback
    Get-Content -Path $Path -Raw
}

# ============================================================================
# Tab Completion (register when module is imported)
# ============================================================================

Register-ArgumentCompleter -CommandName xcd -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $dirs = Get-ChildItem -Directory -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    $files = Get-ChildItem -File -Filter "*.md" -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    $imageFiles = Get-ChildItem -File -Include "*.png","*.jpg","*.jpeg","*.gif","*.bmp","*.webp","*.ico","*.tiff","*.tif","*.svg" -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    ($dirs + $files + $imageFiles) | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Export-ModuleMember -Function xcd