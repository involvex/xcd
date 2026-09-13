<#
.SYNOPSIS
    Smart directory navigation and file viewing (extended cd).

.DESCRIPTION
    Enhanced cd replacement that intelligently handles paths:
    - No arguments: lists current directory with git status
    - Directory: changes to it (Set-Location)
    - Markdown file: opens in preferred terminal viewer
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

.NOTES
    Requires PowerShell 7+ for best experience.
    Optional dependencies: glow, mdcat, bat, fzf, git.
    Configure markdown viewer via $env:XCD_MD_VIEWER (e.g., "glow", "mdcat", "bat", "bun").
#>

function xcd {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(
            Position = 0,
            ValueFromRemainingArguments = $true,
            ParameterSetName = 'Path'
        )]
        [string[]]$Path
    )

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
    try {
        $items = Get-ChildItem -Force -ErrorAction Stop |
            Sort-Object { $_.PSIsContainer }, Name

        # Check for git repo
        $gitStatus = @{}
        if (Test-Path .git) {
            $gitOutput = git status --porcelain 2>$null
            if ($LASTEXITCODE -eq 0) {
                foreach ($line in $gitOutput -split "`n") {
                    if ($line -match '^(..)\s+(.+)$') {
                        $gitStatus[$matches[2]] = $matches[1]
                    }
                }
            }
        }

        foreach ($item in $items) {
            $mode = $item.Mode.ToString()
            $name = $item.Name
            $git = if ($gitStatus.ContainsKey($name)) { " [$($gitStatus[$name])]" } else { "" }
            $type = if ($item.PSIsContainer) { "📁" } else { "📄" }
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

function Invoke-XcdMarkdown {
    param([string]$Path)

    # Viewer priority: env var > glow > mdcat > bat > Get-Content
    $viewer = $env:XCD_MD_VIEWER

    if ($viewer) {
        if (Get-Command $viewer -ErrorAction SilentlyContinue) {
            try { return & $viewer $Path }
            catch { Write-Warning "xcd: Viewer '$viewer' failed, trying fallbacks..." }
        }
        else {
            Write-Warning "xcd: Configured viewer '$viewer' not found, trying fallbacks..."
        }
    }

    if (Get-Command glow -ErrorAction SilentlyContinue) {
        try { return glow $Path }
        catch { }
    }
    if (Get-Command mdcat -ErrorAction SilentlyContinue) {
        try { return mdcat $Path }
        catch { }
    }
    if (Get-Command bat -ErrorAction SilentlyContinue) {
        try { return bat --language=md --style=plain --color=always $Path }
        catch { }
    }
    if (Get-Command batcat -ErrorAction SilentlyContinue) {
        try { return batcat --language=md --style=plain --color=always $Path }
        catch { }
    }
    if (Get-Command bun -ErrorAction SilentlyContinue) {
        # Only if user has a markdown runner registered
        try { return bun $Path }
        catch { }
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
    ($dirs + $files) | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Export-ModuleMember -Function xcd