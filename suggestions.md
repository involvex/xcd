# xcd - Feature Suggestions & Enhancements

This document collects feature ideas, enhancements, and improvements for the xcd PowerShell module. Items are organized by priority and include implementation notes.

---

## 🎯 High Priority

### 1. Fuzzy Directory Jump (zoxide/fzf Integration)
**Description**: Allow `xcd foo` to jump to the best matching directory using frecency (frequency + recency) algorithm.

**Implementation Options**:
- **Option A**: Integrate with [zoxide](https://github.com/ajeetdsouza/zoxide) - call `zoxide query $path` and `cd` to result
- **Option B**: Native PowerShell implementation using SQLite database (`$env:LOCALAPPDATA\xcd\jump.db`)
- **Option C**: Use `fzf` for interactive selection when multiple matches

**Config**:
```json
{
  "JumpEnabled": true,
  "JumpTool": "zoxide",  // "zoxide", "native", "fzf"
  "JumpMinScore": 0.5
}
```

**Code Location**: Add in `xcd` function after path resolution, before directory check.

---

### 2. Recent Directories / Frecency Tracking
**Description**: Track visited directories and show recent/frequent ones on empty `xcd` invocation.

**Features**:
- SQLite or JSON-based history at `~/.xcd_history.json`
- Score = frequency × recency decay
- Show top 10 on `xcd` with no args (configurable)
- `xcd -Recent` to list all with scores
- `xcd --clear-history` to reset

**Config**:
```json
{
  "TrackHistory": true,
  "HistorySize": 1000,
  "ShowRecentOnEmpty": true,
  "RecentCount": 10
}
```

**Code Location**: New `Add-XcdHistory`, `Get-XcdRecent` functions; modify `Show-XcdDirectory`.

---

### 3. Enhanced Directory Listing
**Description**: Improve `xcd` (no args) output with more information and viewing options.

**Features**:
- File sizes (human-readable: 1.2K, 5.4M)
- Colorized git status (green=clean, yellow=modified, red=untracked, cyan=staged)
- Tree view: `xcd -Tree` or `xcd -t` (depth configurable)
- Long format: `xcd -l` (permissions, owner, modified time)
- Sort options: `xcd -Sort Size`, `-Sort Time`, `-Sort Name`, `-Sort Type`
- Column view for wide terminals

**Config**:
```json
{
  "ListingFormat": "default",  // default, long, tree, columns
  "TreeDepth": 2,
  "ShowSizes": true,
  "HumanReadableSizes": true,
  "SortBy": "Name",  // Name, Size, Time, Type
  "SortDescending": false
}
```

**Code Location**: Rewrite `Show-XcdDirectory` with parameter set support.

---

## 🔧 Medium Priority

### 4. Color Schemes Implementation
**Description**: Implement the `Colors` config option (currently placeholder: default/dark/light).

**Themes**:
- **default**: Terminal default colors
- **dark**: Optimized for dark backgrounds (bright cyan, green, yellow)
- **light**: Optimized for light backgrounds (dark blue, dark green, brown)
- **custom**: User-defined color map

**Implementation**:
```powershell
$colorSchemes = @{
    default = @{ Dir='Cyan'; File='White'; GitClean='Green'; GitDirty='Yellow'; GitUntracked='Red'; Size='Gray' }
    dark    = @{ Dir='BrightCyan'; File='White'; GitClean='BrightGreen'; GitDirty='BrightYellow'; GitUntracked='BrightRed'; Size='Gray' }
    light   = @{ Dir='DarkBlue'; File='Black'; GitClean='DarkGreen'; GitDirty='DarkGoldenrod'; GitUntracked='DarkRed'; Size='DarkGray' }
}
```

**Code Location**: New `Get-XcdColors` function; use in `Show-XcdDirectory`, `Invoke-XcdMarkdown`.

---

### 5. Bookmarks / Named Directories
**Description**: Save and jump to frequently used directories with short names.

**Commands**:
```powershell
xcd -Bookmark work ~/projects/work     # Save bookmark
xcd -Bookmark home ~                   # Save bookmark
xcd work                               # Jump to bookmark
xcd -ListBookmarks                     # Show all
xcd -RemoveBookmark work               # Delete
```

**Storage**: `~/.xcd_bookmarks.json` (name → path mapping)

**Config**:
```json
{
  "Bookmarks": { "work": "~/projects/work", "home": "~" }
}
```

**Code Location**: New parameter set `Bookmark` in `xcd` function; helper functions.

---

### 6. Archive / Compressed File Viewing
**Description**: View contents of archives without extracting.

**Supported Formats**: `.zip`, `.tar`, `.tar.gz`, `.tgz`, `.rar`, `.7z`

**Tools**: `7z`, `tar`, `unzip` (check availability)

**Behavior**:
- `xcd archive.zip` → list contents with sizes
- `xcd archive.zip/file.txt` → extract and view specific file
- `xcd -Extract archive.zip` → extract to temp and cd into it

**Code Location**: Add to `Invoke-XcdFile` dispatcher; new `Invoke-XcdArchive` function.

---

### 7. PDF / Document Preview
**Description**: Basic preview for PDF and Office documents.

**Tools**:
- PDF: `pdftotext` (poppler), `mutool` (mupdf)
- DOCX/XLSX/PPTX: `pandoc`, `antiword`, `catdoc`

**Behavior**:
- `xcd doc.pdf` → extract text (first N pages)
- `xcd report.docx` → convert to markdown and render

**Config**:
```json
{
  "PdfViewer": "auto",  // auto, pdftotext, mutool, none
  "DocViewer": "auto",  // auto, pandoc, none
  "MaxPreviewPages": 3
}
```

---

### 8. Interactive Mode (REPL)
**Description**: Enter an interactive session for rapid navigation.

**Commands inside REPL**:
```
xcd> ls                 # List current dir
xcd> cd projects        # Navigate
xcd> ..                 # Go up
xcd> ~                  # Home
xcd> history            # Show recent
xcd> bookmarks          # Show bookmarks
xcd> config             # Show config
xcd> help               # Show help
xcd> exit               # Quit (returns to shell at last dir)
```

**Implementation**: `xcd -Interactive` or `xcd -i` starts loop using `ReadLine` or native `Read-Host`.

---

### 9. File Search & Filter in Listings
**Description**: Filter directory listings by pattern.

**Usage**:
```powershell
xcd -Filter "*.ts"      # Only TypeScript files
xcd -Filter "test*"     # Prefix match
xcd -Regex "test.*\.ts$" # Regex filter
xcd -NoDirs             # Files only
xcd -NoFiles            # Directories only
```

**Code Location**: Add parameters to `Show-XcdDirectory`.

---

### 10. Git Enhanced Features
**Description**: Deeper git integration beyond porcelain status.

**Features**:
- Show branch name in prompt/header: `xcd` → `main ✓ ~/projects/repo`
- Show ahead/behind count: `main ↑2 ↓1`
- `xcd -GitLog` or `xcd -g` → show recent commits (one-line)
- `xcd -GitDiff` → show unstaged changes
- `xcd -GitStatus` → detailed status (like `git status`)

**Code Location**: New functions `Get-XcdGitInfo`, `Show-XcdGitLog`, etc.

---

## 💡 Low Priority / Nice to Have

### 11. Plugin System
**Description**: Allow users to add custom file handlers without modifying core.

**Structure**:
```
~/.xcd/plugins/
  ├── myplugin.psm1      # Exports Invoke-XcdMyType
  └── plugin.json        # Metadata: extensions, priority, description
```

**Hook Points**:
- `OnFileView` - handle custom extensions
- `OnDirectoryList` - add columns/modify output
- `OnPathResolve` - custom path expansion
- `OnConfigLoad` - extend config schema

**API**:
```powershell
# In plugin.psm1
function Invoke-XcdMyType { param($Path) ... }
Export-ModuleMember -Function Invoke-XcdMyType

# Register in plugin.json
{
  "name": "myplugin",
  "extensions": [".myext"],
  "handler": "Invoke-XcdMyType"
}
```

---

### 12. Shell Completion for Other Shells
**Description**: Generate completion scripts for bash, zsh, fish.

**Approach**: PowerShell script that outputs completion definitions:
```powershell
xcd --generate-completion bash > /etc/bash_completion.d/xcd
xcd --generate-completion zsh  > ~/.zfunc/_xcd
xcd --generate-completion fish > ~/.config/fish/completions/xcd.fish
```

**Source**: Reuse tab completion logic from `Register-ArgumentCompleter`.

---

### 13. Performance: Async / Background Operations
**Description**: Non-blocking operations for slow tasks.

**Targets**:
- Git status on large repos → run async, update display when ready
- Directory size calculation → background job
- Image preview → don't block if catimg slow

**Implementation**: PowerShell Jobs (`Start-Job`, `Receive-Job`) or `ThreadJob` module.

---

### 14. Network / Remote Path Support
**Description**: Handle SSH, SMB, HTTP paths.

**Examples**:
```powershell
xcd ssh://user@host:/path      # SSHFS or direct SSH ls
xcd smb://server/share/path    # SMB mount
xcd https://github.com/user/repo  # Browse repo via GitHub API
```

**Requirements**: SSHFS/WinFsp on Windows; `ssh`, `smbclient` tools.

---

### 15. Configuration Profiles
**Description**: Multiple named configurations for different contexts.

**Usage**:
```powershell
xcd -Profile work      # Use work profile
xcd -Profile personal  # Use personal profile
xcd -SaveProfile work  # Save current as profile
```

**Storage**: `~/.xcd_profiles.json` (name → config object)

---

### 16. Directory Stack / Push/Pop
**Description**: Enhanced directory stack management.

**Commands**:
```powershell
xcd -Push        # Push current to stack, cd to target
xcd -Pop         # Pop from stack and cd
xcd -Stack       # Show stack
xcd -ClearStack  # Clear stack
```

**Integration**: Works with `Push-Location`/`Pop-Location` internally.

---

### 17. Verbose / Debug Logging
**Description**: Structured logging for troubleshooting.

**Features**:
- `xcd -Verbose` → show resolved path, viewer selected, timing
- `xcd -Debug` → detailed trace
- Log to file: `XCD_LOG_FILE=~/xcd.log`

**Config**:
```json
{
  "LogLevel": "Info",  // None, Error, Warn, Info, Debug, Trace
  "LogFile": null      // null = stderr, or path
}
```

---

### 18. Custom Columns in Directory Listing
**Description**: User-defined columns via script blocks.

**Config**:
```json
{
  "CustomColumns": [
    { "Name": "Owner", "Script": "$_.GetAccessControl().Owner" },
    { "Name": "Attr", "Script": "$_.Attributes" }
  ]
}
```

**Security**: Restrict to safe script blocks or use allowlist.

---

### 19. Integration with Terminal Multiplexers
**Description**: Detect and integrate with tmux, screen, wezterm.

**Features**:
- Auto-rename tmux window to current directory
- Send `cd` to other panes: `xcd -SyncPanes ~/projects`
- Wezterm/Windows Terminal: set tab title

---

### 20. AI-Assisted Features (Experimental)
**Description**: Optional AI-powered enhancements.

**Ideas**:
- `xcd -Smart "project with typescript config"` → finds matching dir
- `xcd -Explain` → explains current directory structure
- `xcd -Suggest` → suggests next action based on context

**Requirements**: Local LLM (ollama, llama.cpp) or API key; opt-in only.

---

## 📦 Packaging & Distribution

### 21. PowerShell Gallery Publishing
**Tasks**:
- [ ] Add proper license file
- [ ] Add module icon
- [ ] Configure `Publish-Module` in CI/CD
- [ ] Semantic versioning automation
- [ ] Release notes generation

### 22. Package Manager Support
- **Scoop**: Create bucket manifest
- **Chocolatey**: Create nuspec
- **Winget**: Submit to Microsoft Store
- **Homebrew**: Tap formula (for macOS/Linux)

### 23. Binary Distribution (Optional)
**Idea**: Compile to standalone executable using `PS2EXE` or similar for users without PowerShell 7+.

---

## 🧪 Testing & Quality

### 24. Pester Test Suite
**Coverage Targets**:
- Path resolution (~, $env:, relative, spaces, special chars)
- Config loading/saving/merging
- File type detection & viewer dispatch
- Directory listing output format
- Tab completion results
- Error handling paths
- Git status parsing
- Edge cases (symlinks, junctions, UNC paths)

**Structure**:
```
tests/
├── Xcd.Tests.ps1
├── PathResolution.Tests.ps1
├── Config.Tests.ps1
├── Viewers.Tests.ps1
└── Integration.Tests.ps1
```

### 25. CI/CD Pipeline
**GitHub Actions**:
- Test on Windows (PS 7.4, 7.5), Linux (PS 7.4), macOS (PS 7.4)
- Lint with PSScriptAnalyzer
- Validate manifest
- Generate test coverage report
- Auto-release on tag

---

## 🔒 Security Considerations

### 26. Path Traversal Protection
**Current**: Uses `GetUnresolvedProviderPathFromPSPath` which is safe.

**Additional**:
- Validate resolved path stays within allowed roots (configurable)
- Warn on symlink/junction traversal
- Block access to sensitive paths (configurable blocklist)

### 27. Config File Security
- Validate JSON schema on load
- Ignore unknown keys (already done)
- Warn on world-writable config file
- Optional config encryption (DPAPI on Windows)

---

## 🎨 UX Polish

### 28. Progress Indicators
- Spinner for slow operations (large dir listing, git status)
- Progress bar for recursive operations

### 29. Better Error Messages
- Did you mean? suggestions for typos
- Actionable hints (install missing tool, fix config)

### 30. Man Page / Help Improvements
- `Get-Help xcd -Online` → GitHub wiki
- `xcd --help` short form
- Interactive help browser

---

## 📋 Implementation Priority Matrix

| Feature | Effort | Impact | Dependencies | Suggested Order |
|---------|--------|--------|--------------|-----------------|
| Fuzzy Jump (zoxide) | Low | High | zoxide installed | 1 |
| Recent Directories | Medium | High | None | 2 |
| Enhanced Listing | Medium | High | None | 3 |
| Color Schemes | Low | Medium | None | 4 |
| Bookmarks | Low | High | None | 5 |
| Archive Viewing | Medium | Medium | 7z/tar | 6 |
| PDF Preview | Medium | Low | pdftotext/pandoc | 7 |
| Interactive Mode | Medium | Medium | None | 8 |
| File Filtering | Low | Medium | None | 9 |
| Git Enhanced | Medium | Medium | git | 10 |
| Plugin System | High | High | Architecture change | Later |
| Other Shell Completions | Medium | Low | None | Later |
| Profiles | Medium | Low | None | Later |

---

## 🛠 Technical Debt & Refactoring

1. **Split Xcd.psm1** into multiple files:
   - `Xcd.Core.psm1` - main function, path resolution
   - `Xcd.Config.psm1` - config management
   - `Xcd.Viewers.psm1` - file viewers
   - `Xcd.Directory.psm1` - directory listing
   - `Xcd.Completion.psm1` - tab completion
   - `Xcd.Git.psm1` - git integration
   - Use nested modules or dot-source

2. **Add PSScriptAnalyzer rules** to CI

3. **Strict mode**: `Set-StrictMode -Version Latest` in module

4. **Parameter validation**: Add `ValidateSet`, `ValidatePattern` attributes

5. **Documentation**: Update comment-based help for all new parameters

---

## 📝 Contribution Guidelines for New Features

When implementing a new feature:

1. **Check Plan.md** - avoid duplicates
2. **Design first** - consider config options, parameter sets, backward compatibility
3. **Write tests** - Pester tests for new functionality
4. **Update docs** - Readme.md, comment-based help, Plan.md
5. **Follow patterns** - config access via `$script:XcdConfig`, error handling with try/catch
6. **Performance** - avoid blocking operations in hot paths
7. **Cross-platform** - test on Windows, Linux, macOS

---

*Last updated: 2026-09-14*
*Generated from codebase analysis of xcd v1.0.0*