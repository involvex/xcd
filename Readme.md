# xcd - Smart Directory Navigation

Extended `cd` for PowerShell with intelligent file handling, markdown/image viewing, and git-aware directory listings.

## Features

- **Smart navigation**: `xcd` with no args lists directory, directory paths `cd` into them
- **File viewing**: Markdown (glow/mdcat/bat), images (catimg), code (bat syntax highlight)
- **Path expansion**: `~`, `$env:VAR`, relative paths, spaces without quotes
- **Git awareness**: Shows git status (clean/modified/untracked) in directory listings
- **Configurable**: Persistent `~/.xcd.json` + environment variable overrides
- **Tab completion**: Directories, `.md` files, and image files
- **Full help**: `Get-Help xcd` with examples

## Installation

```powershell
# Option 1: Copy to module path (recommended)
$modPath = "$env:USERPROFILE\Documents\PowerShell\Modules\Xcd"
Copy-Item D:\repos\xcd\* -Destination $modPath -Recurse -Force

# In your $PROFILE:
Import-Module Xcd
# Optional: replace cd entirely
Set-Alias cd xcd

# Option 2: Direct import (development)
Import-Module D:\repos\xcd\Xcd.psd1
```

## Usage

```powershell
# Directory listing with git status
xcd
xcd ~
xcd ./src

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
  "Icons": true
}
```

### Options

| Key | Values | Description |
| ----- | -------- | ------------- |
| `MarkdownViewer` | `auto`, `glow`, `mdcat`, `bat`, `bun`, `cat` | Markdown renderer priority |
| `ImageViewer` | `auto`, `catimg` | Image preview tool |
| `ShowHidden` | `true`, `false` | Show hidden files in listing |
| `GitStatus` | `true`, `false` | Show git porcelain status |
| `Colors` | `default`, `dark`, `light` | Color scheme (future) |
| `Icons` | `true`, `false` | Show 📁/📄 icons |

### Environment Variable Overrides

Any config key can be overridden via `XCD_<KEY>` (e.g., `$env:XCD_MD_VIEWER = 'glow'`).

## Dependencies

Optional but recommended:

| Tool | Purpose | Install |
| ------ | --------- | --------- |
| `glow` | Best markdown rendering | `scoop install glow` / `brew install glow` |
| `mdcat` | Fast markdown with images | `cargo install mdcat` |
| `bat` | Syntax highlighting | `scoop install bat` / `brew install bat` |
| `catimg` | Terminal image preview | `Import-Module I:\dev\catimg\catimg.ps1` |
| `git` | Git status in listings | Built-in |

## Requirements

- PowerShell 7.0+
- Windows / Linux / macOS

## License

MIT
