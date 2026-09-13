function xcd {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string]$Path
    )

    # 1. Ohne Argument -> Verzeichnisinhalt anzeigen
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Get-ChildItem
        return
    }

    # Pfad auflösen
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

    # 2. Pfad ist eine Datei -> Ausführen / Anzeigen
    if (Test-Path -Path $resolved -PathType Leaf) {
        if ($resolved -like "*.md") {
            bun $resolved
        } else {
            Get-Content $resolved
        }
        return
    }

    # 3. Pfad ist ein Ordner -> Wechseln
    if (Test-Path -Path $resolved -PathType Container) {
        Set-Location -Path $resolved
        return
    }

    # Fallback für Standard-Verhalten / Alias-Pfade
    Set-Location -Path $Path
}