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

.PARAMETER Format
    Directory listing format: default, long, tree, columns.

.PARAMETER Depth
    Tree view depth (default: 2, config: TreeDepth).

.PARAMETER Long
    Shortcut for -Format long (detailed listing like ls -l).

.PARAMETER Tree
    Shortcut for -Format tree (tree view).

.PARAMETER Sort
    Sort field: Name, Size, Time, Type (default: Name, config: SortBy).

.PARAMETER Descending
    Reverse sort order (config: SortDescending).

.PARAMETER Sizes
    Show file sizes (default: true, config: ShowSizes).

.PARAMETER NoSizes
    Hide file sizes.

.PARAMETER EditConfig
    Open ~/.xcd.json in editor ($EDITOR, code, notepad).

.PARAMETER ShowConfig
    Display current configuration.

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

.EXAMPLE
    xcd -Format tree
    Shows directory tree view (depth 2).

.EXAMPLE
    xcd -Format tree -Depth 3
    Shows directory tree view with depth 3.

.EXAMPLE
    xcd -Format long
    Shows detailed listing with permissions, owner, size, time.

.EXAMPLE
    xcd -Sort Size -Descending
    Lists files sorted by size, largest first.

.EXAMPLE
    xcd -Format columns
    Shows directory in column layout.

.NOTES
    Requires PowerShell 7+ for best experience.
    Optional dependencies: glow, mdcat, bat, bun, catimg, git.
    Configure via ~/.xcd.json or environment variables:
    - XCD_MD_VIEWER: markdown viewer (glow, mdcat, bun, bat)
    - XCD_IMAGE_VIEWER: image viewer (catimg)
    - XCD_SHOW_HIDDEN: show hidden files (true/false)
    - XCD_GIT_STATUS: show git status in listing (true/false)
    - XCD_COLORS: color scheme (default, dark, light)
    - XCD_ICONS: show icons (true/false)
    - XCD_LISTING_FORMAT: default format (default, long, tree, columns)
    - XCD_TREE_DEPTH: tree view depth (integer)
    - XCD_SHOW_SIZES: show file sizes (true/false)
    - XCD_HUMAN_READABLE: human-readable sizes (true/false)
    - XCD_SORT_BY: default sort field (Name, Size, Time, Type)
    - XCD_SORT_DESC: reverse sort order (true/false)
    - XCD_SHOW_PERMISSIONS: show permissions in long format (true/false)
    - XCD_SHOW_OWNER: show owner in long format (true/false)
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
        [switch]$ShowConfig,

        [Parameter(ParameterSetName = 'Listing')]
        [ValidateSet('default','long','tree','columns')]
        [string]$Format = 'default',

        [Parameter(ParameterSetName = 'Listing')]
        [int]$Depth = 2,

        [Parameter(ParameterSetName = 'Listing')]
        [switch]$Long,

        [Parameter(ParameterSetName = 'Listing')]
        [switch]$Tree,

        [Parameter(ParameterSetName = 'Listing')]
        [ValidateSet('Name','Size','Time','Type')]
        [string]$Sort = 'Name',

        [Parameter(ParameterSetName = 'Listing')]
        [switch]$Descending,

        [Parameter(ParameterSetName = 'Listing')]
        [switch]$Sizes,

        [Parameter(ParameterSetName = 'Listing')]
        [switch]$NoSizes
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
        # Determine format from shorthand switches
        $format = $Format
        if ($Long) { $format = 'long' }
        if ($Tree) { $format = 'tree' }

        # Determine sort
        $sortBy = $Sort
        $sortDesc = $Descending.IsPresent

        # Determine sizes
        $showSizes = $true
        if ($NoSizes.IsPresent) { $showSizes = $false }
        elseif ($Sizes.IsPresent) { $showSizes = $true }

        return Show-XcdDirectory -Format $format -Depth $Depth -SortBy $sortBy -SortDescending $sortDesc -ShowSizes $showSizes
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
        MarkdownViewer       = 'auto'   # auto, glow, mdcat, bun, bat, cat
        ImageViewer          = 'auto'   # auto, catimg
        ShowHidden           = $true
        GitStatus            = $true
        Colors               = 'default' # default, dark, light
        Icons                = $true
        ListingFormat        = 'default' # default, long, tree, columns
        TreeDepth            = 1
        ShowSizes            = $true
        HumanReadableSizes   = $true
        SortBy               = 'Name'    # Name, Size, Time, Type
        SortDescending       = $false
        ShowPermissions      = $false
        ShowOwner            = $false
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
    if ($env:XCD_MD_VIEWER)          { $envConfig.MarkdownViewer = $env:XCD_MD_VIEWER }
    if ($env:XCD_IMAGE_VIEWER)       { $envConfig.ImageViewer = $env:XCD_IMAGE_VIEWER }
    if ($env:XCD_SHOW_HIDDEN)        { $envConfig.ShowHidden = [bool]::Parse($env:XCD_SHOW_HIDDEN) }
    if ($env:XCD_GIT_STATUS)         { $envConfig.GitStatus = [bool]::Parse($env:XCD_GIT_STATUS) }
    if ($env:XCD_COLORS)             { $envConfig.Colors = $env:XCD_COLORS }
    if ($env:XCD_ICONS)              { $envConfig.Icons = [bool]::Parse($env:XCD_ICONS) }
    if ($env:XCD_LISTING_FORMAT)     { $envConfig.ListingFormat = $env:XCD_LISTING_FORMAT }
    if ($env:XCD_TREE_DEPTH)         { $envConfig.TreeDepth = [int]$env:XCD_TREE_DEPTH }
    if ($env:XCD_SHOW_SIZES)         { $envConfig.ShowSizes = [bool]::Parse($env:XCD_SHOW_SIZES) }
    if ($env:XCD_HUMAN_READABLE)     { $envConfig.HumanReadableSizes = [bool]::Parse($env:XCD_HUMAN_READABLE) }
    if ($env:XCD_SORT_BY)            { $envConfig.SortBy = $env:XCD_SORT_BY }
    if ($env:XCD_SORT_DESC)          { $envConfig.SortDescending = [bool]::Parse($env:XCD_SORT_DESC) }
    if ($env:XCD_SHOW_PERMISSIONS)   { $envConfig.ShowPermissions = [bool]::Parse($env:XCD_SHOW_PERMISSIONS) }
    if ($env:XCD_SHOW_OWNER)         { $envConfig.ShowOwner = [bool]::Parse($env:XCD_SHOW_OWNER) }

    $merged = @{}
    foreach ($key in $defaultConfig.Keys) {
        $merged[$key] = if ($envConfig.ContainsKey($key)) { $envConfig[$key] } else { $defaultConfig[$key] }
    }
    return $merged
}

# ============================================================================
# Helper Functions for Enhanced Directory Listing
# ============================================================================

function Get-XcdColorScheme {
    param([string]$Scheme = 'default')

    $schemes = @{
        default = @{
            Dir          = 'Cyan'
            File         = 'White'
            Size         = 'Gray'
            Time         = 'Gray'
            Permissions  = 'DarkGray'
            Owner        = 'DarkGray'
            GitClean     = 'Green'
            GitModified  = 'Yellow'
            GitUntracked = 'Red'
            GitStaged    = 'Cyan'
            TreeBranch   = 'DarkGray'
            TreeConnector= 'DarkGray'
        }
        dark = @{
            Dir          = 'BrightCyan'
            File         = 'White'
            Size         = 'Gray'
            Time         = 'Gray'
            Permissions  = 'DarkGray'
            Owner        = 'DarkGray'
            GitClean     = 'BrightGreen'
            GitModified  = 'BrightYellow'
            GitUntracked = 'BrightRed'
            GitStaged    = 'BrightCyan'
            TreeBranch   = 'Gray'
            TreeConnector= 'Gray'
        }
        light = @{
            Dir          = 'DarkBlue'
            File         = 'Black'
            Size         = 'DarkGray'
            Time         = 'DarkGray'
            Permissions  = 'Gray'
            Owner        = 'Gray'
            GitClean     = 'DarkGreen'
            GitModified  = 'DarkGoldenrod'
            GitUntracked = 'DarkRed'
            GitStaged    = 'DarkCyan'
            TreeBranch   = 'Gray'
            TreeConnector= 'Gray'
        }
    }
    return $schemes[$Scheme] ?? $schemes.default
}

function Format-XcdSize {
    param([long]$Bytes, [bool]$HumanReadable = $true)
    if (-not $HumanReadable -or $Bytes -lt 1024) { return "$Bytes B" }
    $units = 'B','KB','MB','GB','TB'
    $i = [math]::Floor([math]::Log($Bytes, 1024))
    $size = [math]::Round($Bytes / [math]::Pow(1024, $i), 1)
    return "$size $($units[$i])"
}

function Get-XcdGitStatusColor {
    param([string]$Status, [hashtable]$Colors)
    switch -Regex ($Status) {
        '^\?\?'   { return $Colors.GitUntracked }
        '^M'      { return $Colors.GitModified }
        '^A'      { return $Colors.GitStaged }
        '^D'      { return $Colors.GitModified }
        '^R'      { return $Colors.GitModified }
        '^\sM'    { return $Colors.GitModified }
        '^\sD'    { return $Colors.GitModified }
        '^!!'     { return $Colors.GitUntracked }
        default   { return $Colors.GitClean }
    }
}

function Sort-XcdItems {
    param([System.IO.FileSystemInfo[]]$Items, [string]$SortBy, [bool]$Descending)
    $scriptBlock = switch ($SortBy) {
        'Size'  { { $_.Length } }
        'Time'  { { $_.LastWriteTime } }
        'Type'  { { if ($_.PSIsContainer) { 0 } else { 1 } }, { $_.Name } }
        default { { $_.Name } }
    }
    $sorted = $Items | Sort-Object $scriptBlock
    if ($Descending) { return $sorted[($sorted.Count-1)..0] }
    return $sorted
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

# ============================================================================
# Directory Listing Format Renderers
# ============================================================================

function Format-XcdDefaultView {
    param(
        [System.IO.FileSystemInfo[]]$Items,
        [hashtable]$GitStatus,
        [hashtable]$Colors,
        [hashtable]$Config
    )

    $useIcons = $Config.Icons
    $showSizes = $Config.ShowSizes
    $humanReadable = $Config.HumanReadableSizes

    foreach ($item in $Items) {
        $mode = $item.Mode.ToString()
        $name = $item.Name
        $gitCode = if ($GitStatus.ContainsKey($name)) { $GitStatus[$name] } else { '' }
        $git = if ($gitCode) { " [$gitCode]" } else { '' }

        if ($item.PSIsContainer) {
            $type = if ($useIcons) { "📁" } else { "[DIR]" }
            $typeColor = $Colors.Dir
            $sizeStr = ''
            $timeStr = ''
        } else {
            $type = if ($useIcons) { "📄" } else { "[FILE]" }
            $typeColor = $Colors.File
            $sizeStr = if ($showSizes) { " $(Format-XcdSize $item.Length $humanReadable)" } else { '' }
            $timeStr = " $($item.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))"
        }

        $gitColor = if ($gitCode) { Get-XcdGitStatusColor $gitCode $Colors } else { $Colors.GitClean }

        # Build output with colors
        Write-Host -NoNewline "$type " -ForegroundColor $typeColor
        Write-Host -NoNewline "$mode" -ForegroundColor $Colors.Permissions
        if ($showSizes -and -not $item.PSIsContainer) {
            Write-Host -NoNewline "$sizeStr" -ForegroundColor $Colors.Size
        }
        Write-Host -NoNewline "$timeStr " -ForegroundColor $Colors.Time
        Write-Host -NoNewline "$name"
        if ($gitCode) {
            Write-Host -NoNewline "$git" -ForegroundColor $gitColor
        }
        Write-Host ""
    }
}

function Format-XcdLongView {
    param(
        [System.IO.FileSystemInfo[]]$Items,
        [hashtable]$GitStatus,
        [hashtable]$Colors,
        [hashtable]$Config
    )

    $useIcons = $Config.Icons
    $showSizes = $Config.ShowSizes
    $humanReadable = $Config.HumanReadableSizes
    $showPerms = $Config.ShowPermissions
    $showOwner = $Config.ShowOwner

    foreach ($item in $Items) {
        $name = $item.Name
        $gitCode = if ($GitStatus.ContainsKey($name)) { $GitStatus[$name] } else { '' }
        $git = if ($gitCode) { " [$gitCode]" } else { '' }

        $perms = $item.Mode.ToString()
        $owner = ''
        if ($showOwner) {
            try { $owner = $item.GetAccessControl().Owner } catch { $owner = 'unknown' }
        }
        $sizeStr = if ($showSizes -and -not $item.PSIsContainer) { Format-XcdSize $item.Length $humanReadable } else { '' }
        $timeStr = $item.LastWriteTime.ToString('yyyy-MM-dd HH:mm')

        $gitColor = if ($gitCode) { Get-XcdGitStatusColor $gitCode $Colors } else { $Colors.GitClean }
        $typeColor = if ($item.PSIsContainer) { $Colors.Dir } else { $Colors.File }

        # Permissions
        if ($showPerms) { Write-Host -NoNewline "$perms " -ForegroundColor $Colors.Permissions }
        # Owner
        if ($showOwner) { Write-Host -NoNewline "$owner " -ForegroundColor $Colors.Owner }
        # Size
        if ($showSizes) { Write-Host -NoNewline "$sizeStr " -ForegroundColor $Colors.Size }
        # Time
        Write-Host -NoNewline "$timeStr " -ForegroundColor $Colors.Time
        # Name
        Write-Host -NoNewline "$name" -ForegroundColor $typeColor
        # Git
        if ($gitCode) { Write-Host -NoNewline "$git" -ForegroundColor $gitColor }
        Write-Host ""
    }
}

function Format-XcdTreeView {
    param(
        [System.IO.DirectoryInfo]$RootDir,
        [hashtable]$GitStatus,
        [hashtable]$Colors,
        [hashtable]$Config,
        [int]$CurrentDepth = 0,
        [string]$Prefix = '',
        [bool]$IsLast = $true
    )

    if ($CurrentDepth -ge $Config.TreeDepth) { return }

    $showHidden = $Config.ShowHidden
    $useIcons = $Config.Icons
    $showSizes = $Config.ShowSizes
    $humanReadable = $Config.HumanReadableSizes

    try {
        $items = Get-ChildItem -Path $RootDir.FullName -Force:$showHidden -ErrorAction Stop |
            Sort-Object { $_.PSIsContainer }, Name
    }
    catch {
        return
    }

    $count = $items.Count
    for ($i = 0; $i -lt $count; $i++) {
        $item = $items[$i]
        
        # Skip .git directory to avoid deep recursion
        if ($item.Name -eq '.git' -and $item.PSIsContainer) { continue }

        $isLastItem = ($i -eq $count - 1)
        
        if ($isLastItem) { $connector = '└── ' } else { $connector = '├── ' }
        if ($isLastItem) { $nextPrefix = $Prefix + '    ' } else { $nextPrefix = $Prefix + '│   ' }

        $name = $item.Name
        $gitCode = if ($GitStatus.ContainsKey($name)) { $GitStatus[$name] } else { '' }
        $git = if ($gitCode) { " [$gitCode]" } else { '' }

        if ($item.PSIsContainer) {
            if ($useIcons) { $type = "📁" } else { $type = "[DIR]" }
            $typeColor = $Colors.Dir
            $sizeStr = ''
        } else {
            if ($useIcons) { $type = "📄" } else { $type = "[FILE]" }
            $typeColor = $Colors.File
            if ($showSizes) { $sizeStr = " $(Format-XcdSize $item.Length $humanReadable)" } else { $sizeStr = '' }
        }

        $gitColor = if ($gitCode) { Get-XcdGitStatusColor $gitCode $Colors } else { $Colors.GitClean }

        Write-Host -NoNewline "$Prefix$connector" -ForegroundColor $Colors.TreeConnector
        Write-Host -NoNewline "$type " -ForegroundColor $typeColor
        Write-Host -NoNewline "$name"
        if ($showSizes -and -not $item.PSIsContainer) {
            Write-Host -NoNewline "$sizeStr" -ForegroundColor $Colors.Size
        }
        if ($gitCode) {
            Write-Host -NoNewline "$git" -ForegroundColor $gitColor
        }
        Write-Host ""

        if ($item.PSIsContainer) {
            Format-XcdTreeView -RootDir $item -GitStatus $GitStatus -Colors $Colors -Config $Config `
                -CurrentDepth ($CurrentDepth + 1) -Prefix $nextPrefix -IsLast $isLastItem
        }
    }
}

function Format-XcdColumnsView {
    param(
        [System.IO.FileSystemInfo[]]$Items,
        [hashtable]$GitStatus,
        [hashtable]$Colors,
        [hashtable]$Config
    )

    $useIcons = $Config.Icons
    $showSizes = $Config.ShowSizes
    $humanReadable = $Config.HumanReadableSizes

    # Get console width
    try { $width = $Host.UI.RawUI.WindowSize.Width } catch { $width = 120 }
    if ($width -lt 40) { $width = 120 }

    # Calculate max name length + icon + git status
    $maxNameLen = 0
    foreach ($item in $Items) {
        $name = $item.Name
        $gitCode = if ($GitStatus.ContainsKey($name)) { $GitStatus[$name] } else { '' }
        $gitLen = if ($gitCode) { $gitCode.Length + 2 } else { 0 } # brackets
        $iconLen = if ($useIcons) { 2 } else { 5 } # emoji or [DIR]/[FILE]
        $sizeLen = if ($showSizes -and -not $item.PSIsContainer) { (Format-XcdSize $item.Length $humanReadable).Length + 1 } else { 0 }
        $total = $name.Length + $iconLen + $gitLen + $sizeLen + 2
        if ($total -gt $maxNameLen) { $maxNameLen = $total }
    }

    $colWidth = $maxNameLen + 2
    $cols = [math]::Max(1, [math]::Floor($width / $colWidth))
    $rows = [math]::Ceiling($Items.Count / $cols)

    for ($r = 0; $r -lt $rows; $r++) {
        $line = ''
        for ($c = 0; $c -lt $cols; $c++) {
            $idx = $c * $rows + $r
            if ($idx -ge $Items.Count) { break }
            $item = $Items[$idx]
            $name = $item.Name
            $gitCode = if ($GitStatus.ContainsKey($name)) { $GitStatus[$name] } else { '' }
            $git = if ($gitCode) { " [$gitCode]" } else { '' }

            if ($item.PSIsContainer) {
                $type = if ($useIcons) { "📁" } else { "[DIR]" }
                $typeColor = $Colors.Dir
                $sizeStr = ''
            } else {
                $type = if ($useIcons) { "📄" } else { "[FILE]" }
                $typeColor = $Colors.File
                $sizeStr = if ($showSizes) { " $(Format-XcdSize $item.Length $humanReadable)" } else { '' }
            }

            $entry = "$type $name$sizeStr$git"
            $line += $entry.PadRight($colWidth)
        }
        Write-Host $line
    }
}

# ============================================================================
# Directory Listing
# ============================================================================

function Show-XcdDirectory {
    param(
        [switch]$ForceHidden = $false,
        [ValidateSet('default','long','tree','columns')]
        [string]$Format = 'default',
        [int]$Depth = 2,
        [ValidateSet('Name','Size','Time','Type')]
        [string]$SortBy = 'Name',
        [bool]$SortDescending = $false,
        [bool]$ShowSizes = $true,
        [bool]$ShowPermissions = $false,
        [bool]$ShowOwner = $false
    )

    try {
        # Merge config with parameters (params take precedence)
        $showHidden = $script:XcdConfig.ShowHidden -or $ForceHidden
        $format = if ($PSBoundParameters.ContainsKey('Format')) { $Format } else { $script:XcdConfig.ListingFormat }
        $depth = if ($PSBoundParameters.ContainsKey('Depth')) { $Depth } else { $script:XcdConfig.TreeDepth }
        $sortBy = if ($PSBoundParameters.ContainsKey('SortBy')) { $SortBy } else { $script:XcdConfig.SortBy }
        $sortDesc = if ($PSBoundParameters.ContainsKey('SortDescending')) { $SortDescending } else { $script:XcdConfig.SortDescending }
        $showSizes = if ($PSBoundParameters.ContainsKey('ShowSizes')) { $ShowSizes } else { $script:XcdConfig.ShowSizes }
        $showPerms = if ($PSBoundParameters.ContainsKey('ShowPermissions')) { $ShowPermissions } else { $script:XcdConfig.ShowPermissions }
        $showOwner = if ($PSBoundParameters.ContainsKey('ShowOwner')) { $ShowOwner } else { $script:XcdConfig.ShowOwner }
        $humanReadable = $script:XcdConfig.HumanReadableSizes
        $useIcons = $script:XcdConfig.Icons

        # Get items
        $items = Get-ChildItem -Force:$showHidden -ErrorAction Stop

        # Sort items
        $items = Sort-XcdItems -Items $items -SortBy $sortBy -Descending $sortDesc

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

        # Get color scheme
        $colors = Get-XcdColorScheme -Scheme $script:XcdConfig.Colors

        # Build config hashtable for renderers
        $renderConfig = @{
            Icons               = $useIcons
            ShowSizes           = $showSizes
            HumanReadableSizes  = $humanReadable
            ShowPermissions     = $showPerms
            ShowOwner           = $showOwner
            TreeDepth           = $depth
        }

        # Dispatch to format renderer
        switch ($format) {
            'long'     { Format-XcdLongView -Items $items -GitStatus $gitStatus -Colors $colors -Config $renderConfig }
            'tree'     { Format-XcdTreeView -RootDir (Get-Item .) -GitStatus $gitStatus -Colors $colors -Config $renderConfig }
            'columns'  { Format-XcdColumnsView -Items $items -GitStatus $gitStatus -Colors $colors -Config $renderConfig }
            default    { Format-XcdDefaultView -Items $items -GitStatus $gitStatus -Colors $colors -Config $renderConfig }
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

    # Parameter name completions
    $paramNames = @(
        'Format', 'Depth', 'Long', 'Tree', 'Sort', 'Descending', 'Sizes', 'NoSizes',
        'EditConfig', 'ShowConfig',
        'Path'
    )

    # Format values
    $formatValues = @('default','long','tree','columns')
    # Sort values
    $sortValues = @('Name','Size','Time','Type')

    $dirs = Get-ChildItem -Directory -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    $files = Get-ChildItem -File -Filter "*.md" -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    $imageFiles = Get-ChildItem -File -Include "*.png","*.jpg","*.jpeg","*.gif","*.bmp","*.webp","*.ico","*.tiff","*.tif","*.svg" -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

    $allItems = $dirs + $files + $imageFiles + $paramNames + $formatValues + $sortValues

    $allItems | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Export-ModuleMember -Function xcd