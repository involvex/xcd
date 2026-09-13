# Agents.md - xcd Development Guide

This file guides AI agents working on the xcd PowerShell module.

## Project Structure

```
xcd/
├── Xcd.psd1       # Module manifest (version, metadata)
├── Xcd.psm1       # Module implementation (single file)
├── Readme.md      # User documentation
├── Plan.md        # Roadmap & status
├── .gitignore     # Git ignore rules
└── Agents.md      # This file
```

## Module Architecture

**Entry point**: `xcd` function (exported)

- Parameter sets: `Path` (default), `Config` (`-EditConfig`, `-ShowConfig`)
- `ValueFromRemainingArguments` allows unquoted paths with spaces

**Private helpers** (not exported):

- `Resolve-XcdPath` - Path expansion (`~`, `$env:`, relative)
- `Get-XcdConfig` / `Save-XcdConfig` - Config loading/saving
- `Show-XcdDirectory` - Enhanced `ls` with git status
- `Invoke-XcdFile` - Dispatcher by extension
- `Invoke-XcdMarkdown` / `Invoke-XcdImage` - Viewers
- `Edit-XcdConfig` / `Show-XcdConfig` - Config UI

**Config**: `~/.xcd.json` + env var overrides (`XCD_*`)

**Tab completion**: Registered on import via `Register-ArgumentCompleter`

## Development Workflow

```powershell
# Test changes
Import-Module D:\repos\xcd\Xcd.psd1 -Force
xcd                    # Test listing
xcd Plan.md            # Test markdown
xcd .git               # Test directory nav
xcd -ShowConfig        # Test config

# Check help
Get-Help xcd -Full
```

## Key Patterns

1. **Config access**: Use `$script:XcdConfig` (loaded once at module import)
2. **Error handling**: Try/catch with `Write-Error`, return non-zero exit code
3. **Viewer fallback**: Priority chain with graceful degradation
4. **Path resolution**: Always use `ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath`
5. **Icons/emoji**: Check `$script:XcdConfig.Icons` before emitting

## Adding New File Types

1. Add extension to `Invoke-XcdFile` dispatcher
2. Create `Invoke-Xcd<Type>` handler
3. Add to tab completion extensions list
4. Add config option if viewer is configurable
5. Update Readme.md

## Testing Checklist

- [ ] `xcd` (no args) - directory listing with git status
- [ ] `xcd ~` - home directory expansion
- [ ] `xcd $env:TEMP` - env var expansion
- [ ] `xcd path with spaces` - unquoted multi-arg
- [ ] `xcd file.md` - markdown viewer chain
- [ ] `xcd file.ts` - bat syntax highlight
- [ ] `xcd image.png` - catimg preview
- [ ] `xcd -ShowConfig` - config display
- [ ] `xcd -EditConfig` - opens editor
- [ ] Tab completion: dirs, .md, images
- [ ] `Get-Help xcd` - full help renders
- [ ] Config persistence: edit JSON, restart, verify

## Common Issues

| Issue | Fix |
| ------- | ----- |
| Config not loading | Check JSON syntax, `ConvertFrom-Json` errors |
| Tab completion missing | Re-import module (`-Force`), check `Register-ArgumentCompleter` |
| Viewer not found | Verify `Get-Command` checks, check PATH |
| Git status missing | Ensure `.git` exists, `git status --porcelain` works |
| Icons garbled | Set `Icons: false` in config, or use terminal with emoji support |

## Versioning

Update `ModuleVersion` in `Xcd.psd1` for releases. Follow SemVer.

## Publishing (Future)

```powershell
Publish-Module -Path D:\repos\xcd -NuGetApiKey $key
```
