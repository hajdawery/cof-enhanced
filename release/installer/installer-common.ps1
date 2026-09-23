#requires -Version 5.1
# Cry of Fear: Enhanced - shared helpers for install.ps1 and uninstall.ps1.
# Dot-sourced by both; ships in the release archive next to them. ASCII only
# (Windows PowerShell 5.1 reads a BOM-less script in the ANSI code page).
#
# Files the installer keeps in the game folder:
#   cof-enhanced-backup\                 the game files it replaced, copied once
#   cof-enhanced-backup\backed-up-files.tsv   path <TAB> sha256 of each backup
#   cof-enhanced-backup\installed-files.tsv   path <TAB> sha256 <TAB> kind of
#                                        every file it installed or generated
#                                        (a path may appear more than once while
#                                        an upgrade is in progress)
#   cof-enhanced-backup\created-folders.txt   folders it created (removed again
#                                        by the uninstaller when empty)
#   cof-enhanced-install.log             what every install/uninstall run did
#   cof-enhanced-version.txt             the installed version

Set-StrictMode -Version 2

$script:LogLines = New-Object System.Collections.Generic.List[string]

function Say([string]$Message = '') {
    Write-Host $Message
    $script:LogLines.Add($Message)
}

function Say-Warn([string]$Message) {
    Write-Host $Message -ForegroundColor Yellow
    $script:LogLines.Add("WARNING: $Message")
}

function Say-Error([string]$Message) {
    Write-Host ''
    Write-Host $Message -ForegroundColor Red
    $script:LogLines.Add("ERROR: $Message")
}

function Save-Log([string]$LogFile, [string]$Title) {
    try {
        $head = @('', ('=' * 72), ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Title), ('=' * 72))
        [IO.File]::AppendAllText($LogFile, (($head + $script:LogLines) -join "`r`n") + "`r`n")
    } catch {
        Write-Host "(Could not write the log file $LogFile : $($_.Exception.Message))"
    }
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToUpperInvariant()
}

function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

# MANIFEST.sha256: "<sha256>  <path relative to the game folder, / separators>"
function Read-Manifest([string]$Path) {
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if (-not $line -or $line.StartsWith('#')) { continue }
        if ($line -notmatch '^([0-9A-Fa-f]{64}) [ *](.+)$') { throw "Bad line in MANIFEST.sha256: $line" }
        $rel = $Matches[2].Trim().Replace('/', '\')
        if ($rel.StartsWith('\') -or $rel.Contains(':') -or ($rel -split '\\') -contains '..') { throw "Unsafe path in MANIFEST.sha256: $rel" }
        $list.Add([pscustomobject]@{ Path = $rel; Hash = $Matches[1].ToUpperInvariant() })
    }
    return ,$list
}

# key=value lines
function Read-KeyValue([string]$Path) {
    $h = @{}
    if (Test-Path -LiteralPath $Path) {
        foreach ($line in [IO.File]::ReadAllLines($Path)) {
            if ($line -match '^\s*([^=#]+?)\s*=\s*(.*)$') { $h[$Matches[1]] = $Matches[2].Trim() }
        }
    }
    return $h
}

# installed-files.tsv -> hashtable path(lowercase) -> @{ Path; Hashes(list); Kind }
function Read-State([string]$Path) {
    $state = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $state }
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if (-not $line -or $line.StartsWith('#')) { continue }
        $c = $line -split "`t"
        if ($c.Count -lt 2) { continue }
        $key = $c[0].ToLowerInvariant()
        if (-not $state.ContainsKey($key)) {
            $state[$key] = [pscustomobject]@{ Path = $c[0]; Hashes = (New-Object System.Collections.Generic.List[string]); Kind = $(if ($c.Count -ge 3) { $c[2] } else { 'file' }) }
        }
        if (-not $state[$key].Hashes.Contains($c[1].ToUpperInvariant())) { $state[$key].Hashes.Add($c[1].ToUpperInvariant()) }
    }
    return $state
}

function Write-State([string]$Path, $State) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# path<TAB>sha256<TAB>kind - files installed by Cry of Fear: Enhanced (used by Uninstall.cmd)')
    foreach ($k in ($State.Keys | Sort-Object)) {
        foreach ($h in $State[$k].Hashes) { $lines.Add($State[$k].Path + "`t" + $h + "`t" + $State[$k].Kind) }
    }
    [IO.File]::WriteAllLines($Path, $lines)
}

# backed-up-files.tsv -> hashtable path(lowercase) -> @{ Path; Hash }
function Read-BackupList([string]$Path) {
    $list = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $list }
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if (-not $line -or $line.StartsWith('#')) { continue }
        $c = $line -split "`t"
        if ($c.Count -ge 2) { $list[$c[0].ToLowerInvariant()] = [pscustomobject]@{ Path = $c[0]; Hash = $c[1].ToUpperInvariant() } }
    }
    return $list
}

function Write-BackupList([string]$Path, $List) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# path<TAB>sha256 - original game files saved before Cry of Fear: Enhanced replaced them')
    foreach ($k in ($List.Keys | Sort-Object)) { $lines.Add($List[$k].Path + "`t" + $List[$k].Hash) }
    [IO.File]::WriteAllLines($Path, $lines)
}

function Read-Lines([string]$Path) {
    if (Test-Path -LiteralPath $Path) { return @([IO.File]::ReadAllLines($Path) | Where-Object { $_ -and -not $_.StartsWith('#') }) }
    return @()
}

# Processes started from this game folder (the game, the launcher, the old engine).
function Get-GameProcesses([string]$GameDir) {
    $prefix = $GameDir.TrimEnd('\') + '\'
    @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) })
}

function Test-Writable([string]$Dir) {
    $probe = Join-Path $Dir ('cof-enhanced-write-test-{0}.tmp' -f [Guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::WriteAllText($probe, 'test')
        Remove-Item -LiteralPath $probe -Force
        return $true
    } catch {
        return $false
    }
}

# Delete a file even if it is read-only. Deleting (instead of overwriting in
# place) also means a hard-linked file is never written through.
function Remove-FileForce([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReadOnly) { $item.Attributes = $item.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly) }
        Remove-Item -LiteralPath $Path -Force
    }
}

function Copy-FileFresh([string]$Source, [string]$Destination) {
    $dir = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Remove-FileForce $Destination
    [IO.File]::Copy($Source, $Destination)
    # a file extracted from a downloaded zip carries the "downloaded from the
    # internet" mark; drop it so Windows does not warn when Steam starts it
    Unblock-File -LiteralPath $Destination -ErrorAction SilentlyContinue
}

function Write-BytesFresh([string]$Destination, [byte[]]$Bytes) {
    $dir = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Remove-FileForce $Destination
    [IO.File]::WriteAllBytes($Destination, $Bytes)
}

function Assert-NoReparsePoint([string]$GameDir, [string]$Rel) {
    # never write through a junction or symbolic link inside the game folder
    $p = Join-Path $GameDir $Rel
    $root = $GameDir.TrimEnd('\')
    while ($p -and $p.Length -gt $root.Length) {
        if (Test-Path -LiteralPath $p) {
            if ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "$p is a link or junction; refusing to write through it." }
        }
        $p = Split-Path -Parent $p
    }
}
