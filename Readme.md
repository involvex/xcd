# xcd - Smart Directory Navigation

Extended `cd` for PowerShell with intelligent file handling, markdown/image viewing, and git-aware directory listings.

## Features

- **Smart navigation**: `xcd` with no args lists directory, directory paths `cd` into them
- **File viewing**: Markdown (glow/mdcat/bat), images (catimg), code (bat syntax highlight)
- **Path expansion**: `~`, `$env:VAR`, relative paths, spaces without quotes
- **Git awareness**: Shows git status (clean/modified/untracked) in directory listings
- **Enhanced listings**: Multiple formats (default, long, tree, columns), sorting, human-readable sizes, color schemes
- **Configurable**: Persistent `~/.xcd.json` + environment variable overrides
- **Tab completion**: Directories, `.md` files, image files, and parameter names
- **Full help**: `Get-Help xcd` with examples

## Installation

```powershell
# Option 1: One-liner install (recommended)
irm "https://raw.githubusercontent.com/involvex/xcd/refs/heads/main/install.ps1" | iex

# Option 2: Copy to module path (manual)
$modPath = "$env:USERPROFILE\Documents\PowerShell\Modules\Xcd"
Copy-Item D:\repos\xcd\* -Destination $modPath -Recurse -Force

# In your $PROFILE:
Import-Module Xcd
# Optional: replace cd entirely
Set-Alias cd xcd

# Option 3: Direct import (development)
Import-Module D:\repos\xcd\Xcd.psd1
```

The one-liner downloads and installs to `$env:USERPROFILE\Documents\PowerShell\Modules\Xcd`.
After installation, add `Import-Module Xcd` to your PowerShell profile (`$PROFILE`).

## Usage

```powershell
# Directory listing with git status
xcd
xcd ~
xcd ./src

# Enhanced directory listings
xcd -Format tree              # Tree view (depth 1 by default)
xcd -Format tree -Depth 3     # Tree view with custom depth
xcd -Format long              # Detailed listing (ls -l style)
xcd -Format columns           # Column layout
xcd -Sort Size -Descending    # Sort by size, largest first
xcd -Sort Time                # Sort by modification time
xcd -Sort Type                # Directories first, then files
xcd -Long                     # Shortcut for -Format long
xcd -Tree                     # Shortcut for -Format tree
xcd -NoSizes                  # Hide file sizes

# Navigate (like cd)
xcd ~/projects/my-app
xcd ..

# View files
xcd README.md          # Markdown viewer (glow/mdcat/bat fallback)
xcd src/main.ts        # Syntax highlighted code
xcd image.png          # Terminal image preview (catimg)
xcd document.pdf       # Raw content fallback

# Config management
xcd -ShowConfig        # Display current config
xcd -EditConfig        # Open ~/.xcd.json in $EDITOR/code/notepad
```

## Configuration

Create `~/.xcd.json` (or run `xcd -EditConfig`):

```json
{
  "MarkdownViewer": "auto",
  "ImageViewer": "auto",
  "ShowHidden": true,
  "GitStatus": true,
  "Colors": "default",
  "Icons": true,
  "ListingFormat": "default",
  "TreeDepth": 1,
  "ShowSizes": true,
  "HumanReadableSizes": true,
  "SortBy": "Name",
  "SortDescending": false,
  "ShowPermissions": false,
  "ShowOwner": false
}
```

### Options

| Key | Values | Description |
| ----- | -------- | ------------- |
| `MarkdownViewer` | `auto`, `glow`, `mdcat`, `bun`, `bat`, `cat` | Markdown renderer priority |
| `ImageViewer` | `auto`, `catimg` | Image preview tool |
| `ShowHidden` | `true`, `false` | Show hidden files in listing |
| `GitStatus` | `true`, `false` | Show git porcelain status |
| `Colors` | `default`, `dark`, `light` | Color scheme for output |
| `Icons` | `true`, `false` | Show 📁/📄 icons |
| `ListingFormat` | `default`, `long`, `tree`, `columns` | Default directory listing format |
| `TreeDepth` | `1-10` | Maximum depth for tree view |
| `ShowSizes` | `true`, `false` | Show file sizes in listings |
| `HumanReadableSizes` | `true`, `false` | Human-readable sizes (1.2K vs 1234) |
| `SortBy` | `Name`, `Size`, `Time`, `Type` | Default sort field |
| `SortDescending` | `true`, `false` | Reverse sort order |
| `ShowPermissions` | `true`, `false` | Show permissions in long format |
| `ShowOwner` | `true`, `false` | Show owner in long format |

### Environment Variable Overrides

Any config key can be overridden via `XCD_<KEY>` (e.g., `$env:XCD_MD_VIEWER = 'glow'`).

Listing-specific overrides:
- `XCD_LISTING_FORMAT`, `XCD_TREE_DEPTH`, `XCD_SHOW_SIZES`
- `XCD_HUMAN_READABLE`, `XCD_SORT_BY`, `XCD_SORT_DESC`
- `XCD_SHOW_PERMISSIONS`, `XCD_SHOW_OWNER`

## Dependencies

Optional but recommended:

| Tool | Purpose | Install |
| ------ | --------- | --------- |
| `glow` | Best markdown rendering | `scoop install glow` / `brew install glow` |
| `mdcat` | Fast markdown with images | `cargo install mdcat` |
| `bat` | Syntax highlighting | `scoop install bat` / `brew install bat` |
| `bun` | Fast markdown rendering | `scoop install bun` / `brew install bun` / `curl -fsSL https://bun.sh/install | bash` |
| `catimg` | Terminal image preview | `Import-Module I:\dev\catimg\catimg.ps1` |
| `git` | Git status in listings | Built-in |

## Requirements

- PowerShell 7.0+
- Windows / Linux / macOS

## License

MIT
