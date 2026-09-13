**Kurzfassung:** In PowerShell (`pwsh`) funktioniert dies am schnellsten direkt über eine Funktion in deiner `$PROFILE`. Eine reine **Bun CLI** kann das Verzeichnis deiner Shell nicht direkt wechseln (da Kindprozesse den Parent-Prozess nicht verändern können) – Bun kann aber als Entscheider-Engine genutzt werden, wenn ein kleiner PWSH-Wrapper die Befehle ausführt. Gute Kurznamen dafür sind **`scd`** (Smart CD), **`c`** oder **`gcd`**.

---

### 1. Pure PowerShell Lösung (Direkt im `$PROFILE`)

Füge dies in deine PowerShell-Profile-Datei ein (`code $PROFILE` in Terminal eingeben):

```powershell
function cd {
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

```

---

### 2. Bun CLI Varianten-Architektur

Da Node/Bun in einem Kindprozess läuft, kann ein Aufruf von `bun run smartcd.ts /pfad` die Shell selbst nicht navigieren. Bun muss das **Kommando als Text ausgeben**, das die Shell dann ausführt.

#### `smartcd.ts` (Bun Engine)

```typescript
import { existsSync, statSync } from "fs";

const target = Bun.argv[2];

if (!target) {
  console.log("ACTION:LS");
  process.exit(0);
}

if (existsSync(target)) {
  const stat = statSync(target);
  if (stat.isFile()) {
    if (target.endsWith(".md")) {
      console.log(`ACTION:BUN_MD|${target}`);
    } else {
      console.log(`ACTION:CAT|${target}`);
    }
    process.exit(0);
  }
  if (stat.isDirectory()) {
    console.log(`ACTION:CD|${target}`);
    process.exit(0);
  }
}

console.log(`ACTION:CD|${target}`);

```

#### PWSH-Wrapper in `$PROFILE`

```powershell
function scd {
    param([string]$Path)
    $output = bun run "C:\path\to\smartcd.ts" "$Path"
    
    if ($output -match '^ACTION:(?<cmd>[^|]+)(\|(?<target>.*))?$') {
        $action = $Matches['cmd']
        $target = $Matches['target']

        switch ($action) {
            "LS"     { Get-ChildItem }
            "CD"     { Set-Location -Path $target }
            "CAT"    { Get-Content -Path $target }
            "BUN_MD" { bun $target }
        }
    }
}

```

---

### 3. Namensvorschläge für den Befehl

* **`scd`** (*Smart CD*) – Die intuitivste Wahl, behält den Bezug zu `cd` bei.
* **`c`** – Minimalistisches Single-Char Alias für maximale Geschwindigkeit.
* **`gcd`** (*Go CD* / *Get CD*) – Schnell zu tippen auf der Home-Row.
* **`xcd`** (*Extended CD*) – Signalisiert erweiterte Funktionalität.
* **`v`** (*Visit*) – Navigiert oder betrachtet Dateiinhalte je nach Typ.