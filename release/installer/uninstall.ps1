#requires -Version 5.1
<#
    Cry of Fear: Enhanced - uninstaller. Started by Uninstall.cmd in the Cry of
    Fear folder.

      1. removes every file the installer put in (listed, with its SHA-256, in
         cof-enhanced-backup\installed-files.tsv) - but only while the file is
         still exactly what was installed; a file changed since is left in
         place and reported;
      2. puts the original game files back from cof-enhanced-backup\;
      3. removes the folders the installer created, if they are empty;
      4. removes cof-enhanced-version.txt and the backup folder once it is
         empty, and appends to cof-enhanced-install.log.
    Saves, settings and anything else the game wrote are left alone.
#>
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$GameDir)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'installer-common.ps1')

$GameDir     = [IO.Path]::GetFullPath($GameDir.Trim().TrimEnd('\', '.'))
$backupDir   = Join-Path $GameDir 'cof-enhanced-backup'
$stateFile   = Join-Path $backupDir 'installed-files.tsv'
$backupFile  = Join-Path $backupDir 'backed-up-files.tsv'
$dirsFile    = Join-Path $backupDir 'created-folders.txt'
$logFile     = Join-Path $GameDir 'cof-enhanced-install.log'
$versionFile = Join-Path $GameDir 'cof-enhanced-version.txt'
$installed   = Read-KeyValue $versionFile
$version     = if ($installed.ContainsKey('version')) { $installed['version'] } else { 'unknown version' }

Say "Cry of Fear: Enhanced - uninstaller"
Say "Folder: $GameDir"
Say ''

if (-not (Test-Path -LiteralPath $stateFile)) {
    Say-Error ("Cry of Fear: Enhanced is not installed in this folder (cof-enhanced-backup\installed-files.tsv not found).`r`n" +
        "Run Uninstall.cmd from the Cry of Fear folder you installed into. Nothing was changed.")
    exit 1
}
$running = @(Get-GameProcesses $GameDir)
if ($running.Count) {
    Say-Error ("Cry of Fear is running from this folder ({0}). Close the game, then run Uninstall.cmd again. Nothing was changed." -f (($running | ForEach-Object { $_.Name }) -join ', '))
    exit 1
}
if (-not (Test-Writable $GameDir)) {
    Say-Error "Windows does not let this account write to this folder, so nothing can be removed. Nothing was changed."
    exit 1
}

$state   = Read-State $stateFile
$backups = Read-BackupList $backupFile
Say "Removing Cry of Fear: Enhanced $version ($($state.Count) files)..."

$nRemoved = 0; $nRestored = 0; $kept = @(); $keptBackups = @{}
try {
    foreach ($key in ($state.Keys | Sort-Object)) {
        $e = $state[$key]
        $p = Join-Path $GameDir $e.Path
        Assert-NoReparsePoint $GameDir $e.Path
        $b = if ($backups.ContainsKey($key)) { $backups[$key] } else { $null }
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            $cur = Get-Sha256 $p
            if ($e.Hashes.Contains($cur)) {
                Remove-FileForce $p
                $nRemoved++
            } elseif ($b -and $cur -eq $b.Hash) {
                # already the original again (for example after Steam verified the game files)
                Say "  $($e.Path) is already the original game file"
                continue
            } else {
                $kept += $e.Path
                if ($b) { $keptBackups[$key] = $true }
                Say-Warn "$($e.Path) was changed after it was installed; left in place (not removed, original not restored)."
                continue
            }
        }
        if ($b) {
            $src = Join-Path $backupDir $b.Path
            if (-not (Test-Path -LiteralPath $src -PathType Leaf) -or (Get-Sha256 $src) -ne $b.Hash) {
                $keptBackups[$key] = $true
                Say-Warn "The backup of $($b.Path) is missing or damaged; it was not restored. Verify the game files in Steam."
                continue
            }
            Copy-FileFresh $src $p
            if ((Get-Sha256 $p) -ne $b.Hash) { throw "restoring $($b.Path) failed" }
            Say "  restored the original $($b.Path)"
            $nRestored++
        }
    }

    # backups that belong to no installed file (should not happen): restore if the slot is free
    foreach ($key in $backups.Keys) {
        if ($state.ContainsKey($key)) { continue }
        $p = Join-Path $GameDir $backups[$key].Path
        if (-not (Test-Path -LiteralPath $p)) {
            Copy-FileFresh (Join-Path $backupDir $backups[$key].Path) $p
            Say "  restored the original $($backups[$key].Path)"; $nRestored++
        } else { $keptBackups[$key] = $true }
    }

    # empty folders the installer created, deepest first
    $nDirs = 0
    foreach ($d in (Read-Lines $dirsFile | Sort-Object { $_.Length } -Descending)) {
        $full = Join-Path $GameDir $d
        if ((Test-Path -LiteralPath $full -PathType Container) -and -not (Get-ChildItem -LiteralPath $full -Force | Select-Object -First 1)) {
            Remove-Item -LiteralPath $full -Force; $nDirs++
        }
    }

    # tidy the backup folder: drop restored copies, keep anything still needed
    foreach ($key in $backups.Keys) {
        if ($keptBackups.ContainsKey($key)) { continue }
        $f = Join-Path $backupDir $backups[$key].Path
        if (Test-Path -LiteralPath $f) { Remove-FileForce $f }
    }
    if ($keptBackups.Count -eq 0 -and $kept.Count -eq 0) {
        foreach ($f in $stateFile, $backupFile, $dirsFile, (Join-Path $backupDir 'uninstall.ps1'), (Join-Path $backupDir 'installer-common.ps1')) { Remove-FileForce $f }
        # empty sub-folders of the backup, then the backup folder itself
        Get-ChildItem -LiteralPath $backupDir -Recurse -Directory -Force | Sort-Object { $_.FullName.Length } -Descending |
            Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force | Select-Object -First 1) } |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
        if (-not (Get-ChildItem -LiteralPath $backupDir -Force | Select-Object -First 1)) { Remove-Item -LiteralPath $backupDir -Force }
        Remove-FileForce $versionFile
    } else {
        # keep only what is still relevant, so a later run can finish the job
        $left = @{}
        foreach ($k in $state.Keys) { if ($kept -contains $state[$k].Path) { $left[$k] = $state[$k] } }
        Write-State $stateFile $left
        $lb = @{}
        foreach ($k in $keptBackups.Keys) { $lb[$k] = $backups[$k] }
        Write-BackupList $backupFile $lb
    }

    Say ''
    Say ("Removed {0} files, restored {1} original game files, removed {2} empty folders." -f $nRemoved, $nRestored, $nDirs)
    if ($kept.Count) {
        Say-Warn ("{0} changed files were left in place: {1}. Delete them yourself if you do not need them, or verify the game files in Steam." -f $kept.Count, ($kept -join ', '))
    }
    Say 'Your saves and settings were not touched.'
    Save-Log $logFile "Uninstall $version - OK"
    Write-Host ''
    Write-Host 'Cry of Fear: Enhanced has been removed. Cry of Fear starts with its original engine again.' -ForegroundColor Green
    Write-Host 'You can delete Install.cmd, Uninstall.cmd, README.txt and the cof-enhanced folder now.'
    exit 0
} catch {
    Say-Error ("Uninstall failed: {0}`r`nNothing more was changed after this point; run Uninstall.cmd again, or verify the game files in Steam." -f $_.Exception.Message)
    Save-Log $logFile "Uninstall $version - FAILED"
    exit 2
}
