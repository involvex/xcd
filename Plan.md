# xcd - Smart Directory Navigation (Implementation Status)

## Current State: ✅ Working Module

**Structure:**

```
xcd/
├── Xcd.psd1       # Module manifest (v1.0.0)
├── Xcd.psm1       # Module implementation
├── Readme.md      # User documentation
├── Agents.md      # AI agent guide
├── Plan.md        # This file
└── .gitignore     # Git ignore rules
```

**Usage:**

```powershell
Import-Module D:\repos\xcd\Xcd.psd1
xcd                    # List directory with git status
xcd ~/projects         # Navigate (supports ~, $env:VAR)
xcd ./README.md        # View markdown (glow/mdcat/bat fallback)
xcd src/main.ts        # View code file (bat syntax highlight)
xcd image.png          # View image (catimg)
xcd -ShowConfig        # Display config
xcd -EditConfig        # Open ~/.xcd.json in editor
```

**Features Implemented:**

- ✅ Path resolution: `~`, `$env:VAR`, relative paths, spaces without quotes
- ✅ Directory listing with git status (porcelain)
- ✅ Markdown viewer priority: config → glow → mdcat → bat → cat fallback
- ✅ Image viewer: catimg (with file info fallback)
- ✅ Code file viewing: bat/batcat syntax highlighting fallback to Get-Content
- ✅ Tab completion (directories + *.md + image files)
- ✅ Full comment-based help (`Get-Help xcd`)
- ✅ Config file: `~/.xcd.json` with env var overrides (`XCD_*`)
- ✅ Config management: `xcd -ShowConfig`, `xcd -EditConfig`
- ✅ Proper module structure with manifest
- ✅ Error handling with friendly messages

---

## Remaining Enhancements (Priority Order)

### High

- [ ] **Fuzzy directory jump** - integrate zoxide/fzf for `xcd foo` → jump to best match
- [ ] **Recent directories** - track frecency, suggest on empty `xcd`
- [ ] **Better directory listing** - sizes, colorized git status, tree view option

### Medium

- [ ] **Alias `cd`** - optional `Set-Alias cd xcd` in profile
- [ ] **Color schemes** - implement `Colors` config (dark/light/default)
- [ ] **Tests** - Pester tests for each path type

### Low

- [ ] **Publish to PSGallery** - `Publish-Module`
- [ ] **Scoop/Chocolatey package** - for easy install
- [ ] **Cross-shell** - generate fish/zsh/bash completions from same logic

---

## On Bun CLI (Decision: Not Needed)

The hybrid Bun+PWSH approach adds latency and complexity. Pure PowerShell module:

- ✅ Direct shell navigation (no subprocess)
- ✅ Instant startup (no runtime spin-up)
- ✅ Native tab completion
- ✅ Full access to PS providers (HKLM:, Cert:, etc.)

Use Bun only if you need:

- Complex fuzzy finding (fzf-style UI)
- Cross-shell portability (would need wrappers per shell)
- Heavy computation better suited to JS/TS

---

## Quick Install (for user)

```powershell
# One-time: copy module to PSModulePath
$modPath = Join-Path $env:USERPROFILE 'Documents\PowerShell\Modules\Xcd'
Copy-Item D:\repos\xcd\* -Destination $modPath -Recurse -Force

# Then in profile:
Import-Module Xcd
# Optional: Set-Alias cd xcd
```
