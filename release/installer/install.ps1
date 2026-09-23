#requires -Version 5.1
<#
    Cry of Fear: Enhanced - installer. Started by Install.cmd, which sits in the
    Cry of Fear folder next to this script's "cof-enhanced" folder:

        <Cry of Fear>\Install.cmd
        <Cry of Fear>\cof-enhanced\install.ps1        (this file)
        <Cry of Fear>\cof-enhanced\files\...          what gets installed
        <Cry of Fear>\cof-enhanced\MANIFEST.sha256    hash of every file in files\

    What it does:
      1. checks that it is in a Steam Cry of Fear folder (CoFLaunchApp.exe and
         the Steam version's cryoffear\cl_dlls\hl.dll) and that the game is
         not running and the folder is writable; refuses otherwise, changing
         nothing;
      2. checks every file it is about to install against MANIFEST.sha256;
      3. copies every game file it is about to replace into
         cof-enhanced-backup\ - once: an existing backup is never overwritten,
         so running it again (an upgrade) keeps the original files safe;
      4. copies the files, and writes the two files it makes from your own
         game (cryoffear\gameinfo.txt from liblist.gam, and
         cryoffear\maps\c_game_menu1.ent from the menu map);
      5. checks every installed file again, writes cof-enhanced-install.log and
         cof-enhanced-version.txt.
    No administrator rights are requested. Saves and settings are not touched.
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$GameDir)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'installer-common.ps1')

$RetailHlDll = '0036B91C01E92ED205513F52563053A55A66A32D257EFB5F476B8F1F3DDE0E63'

$here     = $PSScriptRoot
$filesDir = Join-Path $here 'files'
$release  = Read-KeyValue (Join-Path $here 'release.txt')
$version  = if ($release.ContainsKey('version')) { $release['version'] } else { 'unknown' }
$commit   = if ($release.ContainsKey('commit')) { $release['commit'] } else { 'unknown' }

$GameDir     = [IO.Path]::GetFullPath($GameDir.Trim().TrimEnd('\', '.'))
$backupDir   = Join-Path $GameDir 'cof-enhanced-backup'
$stateFile   = Join-Path $backupDir 'installed-files.tsv'
$backupFile  = Join-Path $backupDir 'backed-up-files.tsv'
$dirsFile    = Join-Path $backupDir 'created-folders.txt'
$logFile     = Join-Path $GameDir 'cof-enhanced-install.log'
$versionFile = Join-Path $GameDir 'cof-enhanced-version.txt'
$canLog      = $false

function Stop-Install([string]$Message, [int]$Code = 1) {
    Say-Error $Message
    if ($script:canLog) { Save-Log $script:logFile "Install $version - STOPPED" }
    exit $Code
}

Say "Cry of Fear: Enhanced $version - installer"
Say "Folder: $GameDir"
Say ''

# --- 1. the right folder -----------------------------------------------------
if (-not (Test-Path -LiteralPath (Join-Path $here 'MANIFEST.sha256')) -or -not (Test-Path -LiteralPath $filesDir)) {
    Stop-Install "The cof-enhanced folder next to Install.cmd is incomplete. Extract the WHOLE zip again (not just Install.cmd) and run Install.cmd again. Nothing was changed."
}
$launcher = Join-Path $GameDir 'CoFLaunchApp.exe'
$hlDll    = Join-Path $GameDir 'cryoffear\cl_dlls\hl.dll'
if (-not (Test-Path -LiteralPath $launcher) -or -not (Test-Path -LiteralPath $hlDll)) {
    Stop-Install ("This is not a Cry of Fear folder: CoFLaunchApp.exe and cryoffear\cl_dlls\hl.dll are missing here.`r`n" +
        "Extract the zip straight into your Cry of Fear folder (in Steam: right-click Cry of Fear > Manage > Browse local files; " +
        "usually ...\steamapps\common\Cry of Fear) so that Install.cmd sits next to CoFLaunchApp.exe, then run it from there.`r`nNothing was changed.")
}
$hlHash = Get-Sha256 $hlDll
if ($hlHash -ne $RetailHlDll) {
    Stop-Install ("cryoffear\cl_dlls\hl.dll is not the Steam version of Cry of Fear (1.6); it may have been replaced by another mod or an old cheat pack.`r`n" +
        "In Steam: right-click Cry of Fear > Properties > Installed Files > Verify integrity of game files, then run Install.cmd again.`r`nNothing was changed.")
}
foreach ($need in 'cryoffear\liblist.gam', 'cryoffear\maps\c_game_menu1.bsp') {
    if (-not (Test-Path -LiteralPath (Join-Path $GameDir $need))) {
        Stop-Install "$need is missing from this Cry of Fear folder. Verify the game files in Steam, then run Install.cmd again. Nothing was changed."
    }
}

# --- 2. not running, writable ------------------------------------------------
$running = @(Get-GameProcesses $GameDir)
if ($running.Count) {
    Stop-Install ("Cry of Fear is running from this folder ({0}). Close the game, then run Install.cmd again. Nothing was changed." -f (($running | ForEach-Object { $_.Name }) -join ', '))
}
if (-not (Test-Writable $GameDir) -or -not (Test-Writable (Join-Path $GameDir 'cryoffear'))) {
    Stop-Install ("Windows does not let this account write to this folder, so nothing can be installed here.`r`n" +
        "This installer does not ask for administrator rights. Move the Steam library to a folder you can write to, " +
        "or, if you trust this download, right-click Install.cmd and choose 'Run as administrator'.`r`nNothing was changed.")
}
$canLog = $true

# --- 3. what we are going to install ----------------------------------------
$manifest = Read-Manifest (Join-Path $here 'MANIFEST.sha256')
Say ("Checking the {0} files in the download..." -f $manifest.Count)
$bad = @()
foreach ($m in $manifest) {
    $src = Join-Path $filesDir $m.Path
    if (-not (Test-Path -LiteralPath $src) -or (Get-Sha256 $src) -ne $m.Hash) { $bad += $m.Path }
}
if ($bad.Count) {
    Stop-Install ("The download is damaged or incomplete ({0} files do not match, e.g. {1}). Download the zip again, extract all of it, and run Install.cmd again. Nothing was changed." -f $bad.Count, $bad[0])
}

# the two files made from the player's own game
function Get-GameInfoBytes {
    $keys = [ordered]@{}
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $GameDir 'cryoffear\liblist.gam'))) {
        $l = $line.Trim()
        if (-not $l -or $l.StartsWith('//')) { continue }
        if ($l -match '^(\S+)\s+"([^"]*)"') { $keys[$Matches[1].ToLowerInvariant()] = $Matches[2] }
        elseif ($l -match '^(\S+)\s+(\S+)') { $keys[$Matches[1].ToLowerInvariant()] = $Matches[2] }
    }
    function V($k, $d) { if ($keys.Contains($k) -and $keys[$k]) { $keys[$k] } else { $d } }
    $lines = @(
        "// Cry of Fear: Enhanced $version - written by Install.cmd from this folder's liblist.gam,",
        '// plus the keys the new menu needs (startmap "c_intro", render_picbutton_text 1).',
        '// Uninstall.cmd removes it. If Steam ever makes liblist.gam newer than this file,',
        '// the engine rewrites this file without those keys: run Install.cmd again.',
        'basedir ""',
        'gamedir "cryoffear"',
        ('title "{0}"' -f (V 'game' 'Cry of Fear')),
        'startmap "c_intro"',
        ('trainmap "{0}"' -f (V 'trainmap' 'coft_1')),
        ('version {0}' -f (V 'version' '1.6')),
        ('size {0}' -f (V 'size' '0')),
        ('url_info "{0}"' -f (V 'url_info' 'http://www.cry-of-fear.com')),
        ('type "{0}"' -f (V 'type' 'singleplayer_only')),
        'dllpath "cl_dlls"',
        ('gamedll "{0}"' -f (V 'gamedll' 'cl_dlls/hl.dll')),
        ('icon "{0}"' -f (V 'icon' 'coficon')),
        ('mp_filter "{0}"' -f (V 'mpfilter' 'c_')),
        'render_picbutton_text 1'
    )
    return ,([Text.Encoding]::ASCII.GetBytes(($lines -join "`r`n") + "`r`n"))
}

# maps\c_game_menu1.ent: the menu map's own entity list minus the entity that
# opens the old menu (cof_gamemenu). Same output as scripts\make-cof-ent-override.py.
function Get-EntOverrideBytes([string]$Bsp, [string[]]$Drop) {
    $fs = [IO.File]::OpenRead($Bsp)
    try {
        $br = New-Object IO.BinaryReader($fs)
        $ver = $br.ReadInt32()
        if ($ver -ne 30) { throw "unexpected BSP version $ver in $Bsp" }
        $ofs = $br.ReadInt32(); $len = $br.ReadInt32()
        $fs.Position = $ofs
        $blob = $br.ReadBytes($len)
    } finally { $fs.Dispose() }
    $n = [Array]::IndexOf($blob, [byte]0)
    if ($n -lt 0) { $n = $blob.Length }
    $latin = [Text.Encoding]::GetEncoding(28591)
    $text = $latin.GetString($blob, 0, $n)
    $blocks = New-Object System.Collections.Generic.List[string]
    $depth = 0; $start = 0
    for ($i = 0; $i -lt $text.Length; $i++) {
        $ch = $text[$i]
        if ($ch -eq '{') { if ($depth -eq 0) { $start = $i }; $depth++ }
        elseif ($ch -eq '}') { $depth--; if ($depth -eq 0) { $blocks.Add($text.Substring($start, $i - $start + 1)) } }
    }
    $kept = New-Object System.Collections.Generic.List[string]
    $removed = 0
    foreach ($b in $blocks) {
        $cls = ''
        foreach ($line in ($b -split "\r\n|\n|\r")) {
            $t = $line.Trim()
            if ($t.StartsWith('"classname"')) { $parts = $t.Split('"'); if ($parts.Count -gt 3) { $cls = $parts[3] }; break }
        }
        if ($Drop -contains $cls) { $removed++ } else { $kept.Add($b) }
    }
    if ($removed -lt 1) { throw "no $($Drop -join ',') entity found in $Bsp" }
    return ,($latin.GetBytes(($kept -join "`n") + "`n"))
}

$generated = [ordered]@{}
try {
    $generated['cryoffear\gameinfo.txt'] = Get-GameInfoBytes
    $generated['cryoffear\maps\c_game_menu1.ent'] = Get-EntOverrideBytes (Join-Path $GameDir 'cryoffear\maps\c_game_menu1.bsp') @('cof_gamemenu')
} catch {
    Stop-Install "Could not read your game's liblist.gam or menu map: $($_.Exception.Message). Nothing was changed."
}

# every target: path -> new hash, kind
$targets = [ordered]@{}
foreach ($m in $manifest) { $targets[$m.Path.ToLowerInvariant()] = [pscustomobject]@{ Path = $m.Path; Hash = $m.Hash; Kind = 'file' } }
foreach ($k in $generated.Keys) { $targets[$k.ToLowerInvariant()] = [pscustomobject]@{ Path = $k; Hash = (Get-BytesSha256 $generated[$k]); Kind = 'generated' } }
try {
    foreach ($t in $targets.Values) { Assert-NoReparsePoint $GameDir $t.Path }
} catch { Stop-Install "$($_.Exception.Message) Nothing was changed." }

# --- 4. previous install (upgrade) -------------------------------------------
$state   = Read-State $stateFile
$backups = Read-BackupList $backupFile
$created = New-Object System.Collections.Generic.List[string]
foreach ($d in (Read-Lines $dirsFile)) { if (-not $created.Contains($d)) { $created.Add($d) } }
if ($state.Count) {
    $old = Read-KeyValue $versionFile
    Say ("Found an earlier install ({0}); upgrading it in place. The backup of your original files is kept as it is." -f $(if ($old.ContainsKey('version')) { $old['version'] } else { 'unknown version' }))
} else {
    Say 'No earlier install found; installing.'
}

try {
    if (-not (Test-Path -LiteralPath $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }
    # a copy of the uninstaller, so Uninstall.cmd works even after the
    # cof-enhanced folder has been deleted
    foreach ($f in 'uninstall.ps1', 'installer-common.ps1') { Copy-FileFresh (Join-Path $here $f) (Join-Path $backupDir $f) }

    # --- 5. back up what we replace (once) -----------------------------------
    $nBackedUp = 0
    foreach ($key in $targets.Keys) {
        $t = $targets[$key]
        $dst = Join-Path $GameDir $t.Path
        if (-not (Test-Path -LiteralPath $dst -PathType Leaf)) { continue }
        $cur = Get-Sha256 $dst
        $ours = ($cur -eq $t.Hash) -or ($state.ContainsKey($key) -and $state[$key].Hashes.Contains($cur))
        if ($ours) { continue }
        if ($backups.ContainsKey($key)) {
            Say "  kept the existing backup of $($t.Path) (not overwritten)"
            continue
        }
        $bak = Join-Path $backupDir $t.Path
        if (Test-Path -LiteralPath $bak -PathType Leaf) {
            # left by an interrupted earlier run: backups are always taken before
            # anything is replaced, so this copy is the original - keep it
            $backups[$key] = [pscustomobject]@{ Path = $t.Path; Hash = (Get-Sha256 $bak) }
            Write-BackupList $backupFile $backups
            Say "  kept the existing backup of $($t.Path) (not overwritten)"
            continue
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $bak) | Out-Null
        [IO.File]::Copy($dst, $bak, $false)
        if ((Get-Sha256 $bak) -ne $cur) { throw "the backup copy of $($t.Path) does not match the original" }
        $backups[$key] = [pscustomobject]@{ Path = $t.Path; Hash = $cur }
        Write-BackupList $backupFile $backups
        Say "  backed up $($t.Path)"
        $nBackedUp++
    }

    # folders we are about to create
    foreach ($t in $targets.Values) {
        $d = Split-Path -Parent $t.Path
        while ($d) {
            if (-not (Test-Path -LiteralPath (Join-Path $GameDir $d)) -and -not $created.Contains($d)) { $created.Add($d) }
            $d = Split-Path -Parent $d
        }
    }
    $dirLines = New-Object System.Collections.Generic.List[string]
    $dirLines.Add('# folders created by Cry of Fear: Enhanced (removed by Uninstall.cmd when empty)')
    foreach ($d in ($created | Sort-Object)) { $dirLines.Add($d) }
    [IO.File]::WriteAllLines($dirsFile, $dirLines)

    # record the new hashes next to the old ones before touching anything, so
    # Uninstall.cmd can clean up even after an interrupted run
    foreach ($key in $targets.Keys) {
        $t = $targets[$key]
        if (-not $state.ContainsKey($key)) { $state[$key] = [pscustomobject]@{ Path = $t.Path; Hashes = (New-Object System.Collections.Generic.List[string]); Kind = $t.Kind } }
        if (-not $state[$key].Hashes.Contains($t.Hash)) { $state[$key].Hashes.Add($t.Hash) }
        $state[$key].Kind = $t.Kind
    }
    Write-State $stateFile $state

    # --- 6. copy -------------------------------------------------------------
    Say ("Installing {0} files..." -f $targets.Count)
    $nCopied = 0; $nSame = 0
    foreach ($m in $manifest) {
        $dst = Join-Path $GameDir $m.Path
        if ((Test-Path -LiteralPath $dst -PathType Leaf) -and (Get-Sha256 $dst) -eq $m.Hash) { $nSame++; continue }
        Copy-FileFresh (Join-Path $filesDir $m.Path) $dst
        $nCopied++
    }
    $now = Get-Date
    foreach ($k in $generated.Keys) {
        $dst = Join-Path $GameDir $k
        Write-BytesFresh $dst $generated[$k]
        # the engine ignores gameinfo.txt / an .ent file older than liblist.gam / the map
        (Get-Item -LiteralPath $dst).LastWriteTime = $now
        Say "  wrote $k (made from your own game files)"
    }

    # files an earlier version installed that this one does not
    $nRemoved = 0
    foreach ($key in @($state.Keys)) {
        if ($targets.Contains($key)) { continue }
        $p = Join-Path $GameDir $state[$key].Path
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            if ($state[$key].Hashes.Contains((Get-Sha256 $p))) {
                Remove-FileForce $p; $nRemoved++
                Say "  removed $($state[$key].Path) (no longer part of Cry of Fear: Enhanced)"
                if ($backups.ContainsKey($key)) {
                    Copy-FileFresh (Join-Path $backupDir $state[$key].Path) $p
                    Say "  restored the original $($state[$key].Path)"
                }
            } else {
                Say-Warn "$($state[$key].Path) is no longer part of Cry of Fear: Enhanced but was changed after installing; left in place."
            }
        }
        $state.Remove($key)
    }

    # --- 7. verify -----------------------------------------------------------
    $failed = @()
    foreach ($t in $targets.Values) {
        $p = Join-Path $GameDir $t.Path
        if (-not (Test-Path -LiteralPath $p -PathType Leaf) -or (Get-Sha256 $p) -ne $t.Hash) { $failed += $t.Path }
    }
    if ($failed.Count) { throw ("{0} installed files do not match after copying, e.g. {1}" -f $failed.Count, $failed[0]) }

    # final state: only the hashes of this version
    foreach ($key in $targets.Keys) {
        $state[$key].Hashes.Clear(); $state[$key].Hashes.Add($targets[$key].Hash)
    }
    Write-State $stateFile $state
    $vtext = @(
        'product=Cry of Fear: Enhanced',
        "version=$version",
        "commit=$commit",
        ('installed={0}' -f (Get-Date -Format 's')),
        ('files={0}' -f $targets.Count),
        'uninstall=run Uninstall.cmd in this folder'
    )
    [IO.File]::WriteAllLines($versionFile, [string[]]$vtext)

    Say ''
    Say ("Verified all {0} files ({1} copied, {2} already up to date, {3} original files backed up this time, {4} old files removed)." -f $targets.Count, $nCopied, $nSame, $nBackedUp, $nRemoved)
    Say ("Original game files are kept in: {0} ({1} files)" -f $backupDir, $backups.Count)
    Save-Log $logFile "Install $version - OK"
    Write-Host ''
    Write-Host "Cry of Fear: Enhanced $version is installed." -ForegroundColor Green
    Write-Host 'Start Cry of Fear from Steam as usual. The version is shown in the top-right corner of the main menu.'
    Write-Host 'To remove it again, run Uninstall.cmd in this folder.'
    exit 0
} catch {
    Say-Error ("Installation failed: {0}`r`nYour original files are safe in cof-enhanced-backup. Run Install.cmd again, or run Uninstall.cmd to go back to the original game." -f $_.Exception.Message)
    Save-Log $logFile "Install $version - FAILED"
    exit 2
}
