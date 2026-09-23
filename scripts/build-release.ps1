#requires -Version 5.1
<#
.SYNOPSIS
  Assemble the player release archive (cof-enhanced-<version>.zip), the
  source archive and SHA256SUMS.txt from a clean checkout and a folder of
  staged binaries.

.DESCRIPTION
  Inputs:
    -Repo       a checkout of this repository with no tracked changes; its HEAD
                is the release commit. Only files tracked at HEAD are used.
    -Binaries   a staged build (stage1\releases\<name>\ in the workspace) with
                SHA256SUMS.txt and BUILD-INFO.txt (binaries_commit=, stamp=):
                  CoFLaunchApp.exe  xash.dll  ref_gl.dll  vgui.dll
                  FileSystem_Stdio.dll  SDL2.dll  cryoffear\cl_dlls\menu.dll
                Every file is checked against SHA256SUMS.txt first. PDBs are
                never packed.
    -EngineTree optional: the patched Xash3D FWGS tree the binaries were built
                from; its sources (no build output, no .git, no submodule the
                Windows build does not link) go into the source archive.
    -CanonicalGame optional: an untouched Cry of Fear folder; the build fails
                if any file in the archive is byte-identical to a game file.

  The player archive, extracted into the Cry of Fear folder:

    Install.cmd, Uninstall.cmd, README.txt
    cof-enhanced\files\...           mirror of the game folder: what Install.cmd copies
    cof-enhanced\MANIFEST.sha256     SHA-256 of every file under files\
    cof-enhanced\install.ps1, uninstall.ps1, installer-common.ps1, release.txt
    cof-enhanced\SOURCE.txt, CHEATS.md, LICENSE, LICENSING.md,
    cof-enhanced\THIRD-PARTY-NOTICES.md, DISCLAIMER.md, licenses\

  The payload (files\) is: the binaries above; from gamedata\cryoffear the
  fonts + OFL.txt, gfx\fonts (Inter + OFL.txt), gfx\shell\kb_def.lst,
  resource\cryoffear_english.txt, scripts\chapterbackgrounds.txt; and every
  language pack under languages\ (checked against its MANIFEST.tsv) as
  cryoffear\languages\<pack>\. cryoffear\gameinfo.txt and
  cryoffear\maps\c_game_menu1.ent are NOT shipped: the installer writes them
  from the player's own liblist.gam and menu map. See release/RELEASE-MANIFEST.md.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-release.ps1 `
      -Version 0.4.0-test1 -Binaries K:\LLM\COF_Fix\stage1\releases\v0.4.0-test1 `
      -OutDir K:\LLM\COF_Fix\stage1\releases\v0.4.0-test1\dist `
      -EngineTree K:\LLM\COF_Fix\cof-fix\pristine-test1-20260923\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a `
      -CanonicalGame "K:\LLM\COF_Fix\Cry of Fear"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Binaries,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$Repo = '',
    [string]$EngineTree = '',
    [string]$CanonicalGame = '',
    [switch]$AllowDirty
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

[Console]::OutputEncoding = [Text.Encoding]::UTF8
if (-not $Repo) { $Repo = Split-Path -Parent $PSScriptRoot }
$Repo = [IO.Path]::GetFullPath($Repo)
$Binaries = [IO.Path]::GetFullPath($Binaries)
$OutDir = [IO.Path]::GetFullPath($OutDir)
if ($Version -notmatch '^[0-9A-Za-z.\-]+$') { throw "Bad version string: $Version" }

function Hash([string]$p) { (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToUpperInvariant() }
function Invoke-Git { $out = & git.exe -C $Repo @args; if ($LASTEXITCODE -ne 0) { throw "git $args failed" }; $out }

# ---- the release commit ------------------------------------------------------
$commit = (Invoke-Git rev-parse HEAD).Trim()
$short = (Invoke-Git rev-parse --short HEAD).Trim()
$dirty = Invoke-Git status --porcelain --untracked-files=no
if ($dirty -and -not $AllowDirty) { throw "The checkout has tracked changes; commit them first (or pass -AllowDirty for a test build):`n$($dirty -join "`n")" }
if ($dirty) { $commit += '+'; $short += '+' }
$tracked = @(Invoke-Git -c core.quotepath=off ls-files)
function Tracked-Under([string]$prefix) { @($tracked | Where-Object { $_.StartsWith($prefix) }) }

# ---- the staged binaries ------------------------------------------------------
$sums = @{}
foreach ($line in [IO.File]::ReadAllLines((Join-Path $Binaries 'SHA256SUMS.txt'))) {
    if ($line -match '^([0-9A-Fa-f]{64})\s+\*?(.+)$') { $sums[$Matches[2].Trim().Replace('\', '/').ToLowerInvariant()] = $Matches[1].ToUpperInvariant() }
}
$info = @{}
foreach ($line in [IO.File]::ReadAllLines((Join-Path $Binaries 'BUILD-INFO.txt'))) { if ($line -match '^([a-z_0-9]+)=(.*)$') { $info[$Matches[1]] = $Matches[2] } }
foreach ($k in 'binaries_commit', 'stamp') { if (-not $info.ContainsKey($k)) { throw "BUILD-INFO.txt has no $k=" } }
if (-not $info['stamp'].Contains($Version)) { throw "The staged binaries are stamped '$($info['stamp'])', not version $Version" }
$binaryFiles = 'CoFLaunchApp.exe', 'xash.dll', 'ref_gl.dll', 'vgui.dll', 'FileSystem_Stdio.dll', 'SDL2.dll', 'cryoffear/cl_dlls/menu.dll'

# ---- stage -------------------------------------------------------------------
$stage = Join-Path $OutDir "_stage-$Version"
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
$pkg = Join-Path $stage 'cof-enhanced'
$files = Join-Path $pkg 'files'
New-Item -ItemType Directory -Force -Path $files | Out-Null

function Put([string]$src, [string]$rel) {
    $dst = Join-Path $files $rel.Replace('/', '\')
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst
}

foreach ($b in $binaryFiles) {
    $src = Join-Path $Binaries $b.Replace('/', '\')
    $want = $sums[$b.ToLowerInvariant()]
    if (-not $want) { throw "$b is not listed in $Binaries\SHA256SUMS.txt" }
    if ((Hash $src) -ne $want) { throw "$b does not match $Binaries\SHA256SUMS.txt" }
    Put $src $b
}

# gamedata: the files the game folder needs (not gameinfo.keys, READMEs, .gitignore)
$gd = 'gamedata/cryoffear/'
$gamedata = @(Tracked-Under "${gd}fonts/") + @(Tracked-Under "${gd}gfx/fonts/") +
    @("${gd}gfx/shell/kb_def.lst", "${gd}resource/cryoffear_english.txt", "${gd}scripts/chapterbackgrounds.txt")
foreach ($g in $gamedata) {
    if ($tracked -notcontains $g) { throw "$g is not tracked at HEAD" }
    Put (Join-Path $Repo $g.Replace('/', '\')) ('cryoffear/' + $g.Substring($gd.Length))
}
foreach ($must in 'cryoffear/fonts/OFL.txt', 'cryoffear/gfx/fonts/OFL.txt') {
    if (-not (Test-Path -LiteralPath (Join-Path $files $must.Replace('/', '\')))) { throw "missing $must (the OFL must ship beside the fonts)" }
}

# language packs: every languages/<pack>/ with a MANIFEST.tsv, checked file by file
$packs = @($tracked | Where-Object { $_ -match '^languages/([^/]+)/MANIFEST\.tsv$' } | ForEach-Object { $_.Split('/')[1] })
if (-not $packs.Count) { throw 'no language packs found' }
foreach ($p in $packs) {
    $pfiles = Tracked-Under "languages/$p/"
    $listed = @{}
    foreach ($row in ([IO.File]::ReadAllLines((Join-Path $Repo "languages\$p\MANIFEST.tsv")) | Select-Object -Skip 1)) {
        if (-not $row) { continue }
        $c = $row -split "`t"
        $listed[$c[0]] = $c[2].ToUpperInvariant()
    }
    foreach ($f in $pfiles) {
        $rel = $f.Substring("languages/$p/".Length)
        $src = Join-Path $Repo $f.Replace('/', '\')
        if ($rel -ne 'MANIFEST.tsv' -and $rel -ne 'README.md') {
            if (-not $listed.ContainsKey($rel)) { throw "languages/$p/$rel is not listed in its MANIFEST.tsv" }
            if ((Hash $src) -ne $listed[$rel]) { throw "languages/$p/$rel does not match its MANIFEST.tsv" }
        }
        Put $src "cryoffear/languages/$p/$rel"
    }
    $unlisted = @($pfiles | Where-Object { $_ -eq "languages/$p/MANIFEST.tsv" -or $_ -eq "languages/$p/README.md" }).Count
    if ($listed.Count -ne ($pfiles.Count - $unlisted)) { throw "languages/${p}: MANIFEST.tsv lists $($listed.Count) files, $($pfiles.Count - $unlisted) are tracked" }
    Write-Host ("pack {0,-10} {1,4} files, MANIFEST.tsv {2}" -f $p, $pfiles.Count, (Hash (Join-Path $Repo "languages\$p\MANIFEST.tsv")).Substring(0, 8))
}

# ---- safety checks -------------------------------------------------------------
$payload = @(Get-ChildItem -LiteralPath $files -Recurse -File | Sort-Object FullName)
foreach ($f in $payload) {
    $n = $f.Name.ToLowerInvariant()
    if ($n.EndsWith('.pdb') -or ($n -in @('client.dll', 'hl.dll', 'liblist.gam', 'gameinfo.txt')) -or $n.EndsWith('.bsp') -or $n.EndsWith('.ent') -or $n.EndsWith('.mdl') -or $n.EndsWith('.wad')) {
        throw "refusing to ship $($f.FullName)"
    }
}
if ($CanonicalGame) {
    $bySize = @{}
    foreach ($g in Get-ChildItem -LiteralPath $CanonicalGame -Recurse -File -Force) {
        if (-not $bySize.ContainsKey($g.Length)) { $bySize[$g.Length] = New-Object System.Collections.Generic.List[string] }
        $bySize[$g.Length].Add($g.FullName)
    }
    $same = @()
    foreach ($f in $payload) {
        if (-not $bySize.ContainsKey($f.Length)) { continue }
        $h = Hash $f.FullName
        foreach ($g in $bySize[$f.Length]) { if ((Hash $g) -eq $h) { $same += "$($f.FullName) == $g" } }
    }
    if ($same.Count) { throw "files identical to the game:`n$($same -join "`n")" }
    Write-Host "no payload file is byte-identical to a file of $CanonicalGame"
}

# ---- MANIFEST.sha256, release.txt --------------------------------------------
$man = New-Object System.Collections.Generic.List[string]
foreach ($f in $payload) { $man.Add(('{0}  {1}' -f (Hash $f.FullName), $f.FullName.Substring($files.Length + 1).Replace('\', '/'))) }
[IO.File]::WriteAllText((Join-Path $pkg 'MANIFEST.sha256'), (($man -join "`r`n") + "`r`n"))
[IO.File]::WriteAllText((Join-Path $pkg 'release.txt'), ("version=$Version`r`ncommit=$commit`r`nbinaries_commit=$($info['binaries_commit'])`r`nstamp=$($info['stamp'])`r`n"))

# ---- installer, documents --------------------------------------------------------
function Put-Text([string]$src, [string]$dst, [switch]$Crlf) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    if ($Crlf) {
        $t = [IO.File]::ReadAllText($src)
        [IO.File]::WriteAllText($dst, (($t -replace "`r`n", "`n") -replace "`n", "`r`n"))
    } else { Copy-Item -LiteralPath $src -Destination $dst }
}
foreach ($f in 'install.ps1', 'uninstall.ps1', 'installer-common.ps1') { Put-Text (Join-Path $Repo "release\installer\$f") (Join-Path $pkg $f) -Crlf }
foreach ($f in 'Install.cmd', 'Uninstall.cmd') { Put-Text (Join-Path $Repo "release\installer\$f") (Join-Path $stage $f) -Crlf }
foreach ($f in 'CHEATS.md', 'LICENSE', 'LICENSING.md', 'THIRD-PARTY-NOTICES.md', 'DISCLAIMER.md') { Copy-Item -LiteralPath (Join-Path $Repo $f) -Destination (Join-Path $pkg $f) }
foreach ($f in Tracked-Under 'licenses/') { Put-Text (Join-Path $Repo $f.Replace('/', '\')) (Join-Path $pkg $f.Replace('/', '\')) }

$sourceZipName = "cof-enhanced-$Version-source.zip"

# SOURCE.txt: the source offer (LICENSING.md section 6, item 6)
$lic = [IO.File]::ReadAllText((Join-Path $Repo 'LICENSING.md'))
$s3 = [regex]::Match($lic, '(?ms)^## 3\. Pinned upstream sources\s*$.*?(?=^## 4\.)').Value.TrimEnd()
if (-not $s3) { throw 'LICENSING.md section 3 not found' }
$binCommit = $info['binaries_commit']
$changed = @()
if ($binCommit -and $commit.TrimEnd('+') -ne $binCommit) {
    $changed = @(Invoke-Git diff --name-only $binCommit $commit.TrimEnd('+'))
    # the release commit may only add release tooling and documents on top of
    # the commit the binaries were built at
    $compiled = @($changed | Where-Object { $_ -match '^(patches/|launcher/|scripts/apply-|scripts/write-cof-version|scripts/prepare-fwgs|VERSION$|gamedata/|languages/)' })
    if ($compiled.Count) { throw "changed since the binaries were built ($binCommit), rebuild them: $($compiled -join ', ')" }
}
$srcLines = @(
    "Cry of Fear: Enhanced $Version - source code offer",
    ('=' * 60),
    '',
    'Every binary in this release is free software (GNU GPL version 3 or later,',
    'FreeVGUI BSD-3-Clause, SDL2 zlib; see LICENSING.md). Its complete source',
    'code is available at no charge, for as long as these binaries are offered:',
    '',
    '1. This project (engine/menu/UI patches, launcher, installer, data):',
    '   https://github.com/hajdawery/cof-enhanced',
    "   tag v$Version, commit $commit",
    '',
    "   The binaries were built at commit $binCommit",
    "   (stamp: $($info['stamp'])).",
    $(if ($changed.Count) { "   Files changed between that commit and the release commit (none of them is" } else { '   The release commit is that commit.' }),
    $(if ($changed.Count) { '   compiled into a binary):' } else { '' })
) + @($changed | ForEach-Object { "     $_" }) + @(
    '',
    "2. The source archive attached to the same GitHub release: $sourceZipName",
    '   (this repository at the release commit, plus the patched Xash3D FWGS tree',
    '   the binaries were built from, under engine-source/).',
    '',
    '3. Upstream sources and the build configuration (LICENSING.md section 3):',
    '',
    $s3,
    '',
    'SDL2.dll is the unmodified x86 SDL2.dll from SDL2-devel-2.30.9-VC.zip',
    '(https://github.com/libsdl-org/SDL/releases/tag/release-2.30.9).'
)
$sourceText = ($srcLines -join "`r`n") + "`r`n"
[IO.File]::WriteAllText((Join-Path $pkg 'SOURCE.txt'), $sourceText)

# README.txt from the player template
$tpl = [IO.File]::ReadAllText((Join-Path $Repo 'docs\player-README-template.md'))
$tpl = [regex]::Replace($tpl, '(?s)<!--.*?-->\s*', '')
$fields = @{ 'VERSION' = $Version; 'BACKUP_FOLDER' = 'cof-enhanced-backup'; 'COF_FIX_COMMIT' = $commit; 'SOURCE_ARCHIVE_NAME' = $sourceZipName }
foreach ($k in $fields.Keys) { $tpl = $tpl.Replace("{{$k}}", $fields[$k]) }
if ($tpl -match '\{\{[A-Z_]+\}\}') { throw "README template field not filled: $($Matches[0])" }
$out = New-Object System.Collections.Generic.List[string]
foreach ($line in ($tpl -replace "`r`n", "`n").Split("`n")) {
    $l = $line -replace '\*\*([^*]+)\*\*', '$1' -replace '`([^`]+)`', '$1' -replace '<(https?://[^>]+)>', '$1'
    if ($l -match '^# (.+)$') { $out.Add($Matches[1]); $out.Add('=' * $Matches[1].Length) }
    elseif ($l -match '^## (.+)$') { $out.Add($Matches[1]); $out.Add('-' * $Matches[1].Length) }
    else { $out.Add($l) }
}
[IO.File]::WriteAllText((Join-Path $stage 'README.txt'), (($out -join "`r`n").TrimEnd() + "`r`n"))

# ---- the player archive ----------------------------------------------------------
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
function New-Zip([string]$zipPath, [string]$root, [string]$prefix = '') {
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    $zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($f in (Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName)) {
            $name = $prefix + $f.FullName.Substring($root.TrimEnd('\').Length + 1).Replace('\', '/')
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $name, [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $zip.Dispose() }
}
$zipPath = Join-Path $OutDir "cof-enhanced-$Version.zip"
New-Zip $zipPath $stage
Write-Host ("player archive: {0} ({1:N0} bytes, {2} payload files)" -f $zipPath, (Get-Item -LiteralPath $zipPath).Length, $payload.Count)

# ---- the source archive -----------------------------------------------------------
$srcZip = Join-Path $OutDir $sourceZipName
if (Test-Path -LiteralPath $srcZip) { Remove-Item -LiteralPath $srcZip -Force }
Invoke-Git archive --format=zip "--prefix=cof-enhanced-$Version/" -o $srcZip $commit.TrimEnd('+') | Out-Null
$zip = [IO.Compression.ZipFile]::Open($srcZip, [IO.Compression.ZipArchiveMode]::Update)
try {
    $e = $zip.CreateEntry("cof-enhanced-$Version/SOURCE.txt")
    $w = New-Object IO.StreamWriter($e.Open(), (New-Object Text.UTF8Encoding($false)))
    try { $w.Write($sourceText) } finally { $w.Dispose() }
    if ($EngineTree) {
        $EngineTree = [IO.Path]::GetFullPath($EngineTree)
        $top = Split-Path -Leaf $EngineTree
        # not linked into the Windows build (LICENSING.md section 3); available upstream
        $skipDirs = '3rdparty\mbedtls', '3rdparty\gl4es', '3rdparty\nanogl', '3rdparty\gl-wes-v2', '3rdparty\libbacktrace', '3rdparty\extras', '3rdparty\maintui'
        $n = 0
        foreach ($f in (Get-ChildItem -LiteralPath $EngineTree -Recurse -File -Force | Sort-Object FullName)) {
            $rel = $f.FullName.Substring($EngineTree.Length + 1)
            $parts = $rel.Split('\')
            if ($parts | Where-Object { $_ -eq '.git' -or $_ -like 'build-*' -or $_ -like '.waf*' -or $_ -eq '__pycache__' }) { continue }
            if ($f.Name -like '.lock-waf*' -or $f.Name -eq '.git') { continue }
            if ($skipDirs | Where-Object { $rel.StartsWith($_ + '\', [StringComparison]::OrdinalIgnoreCase) }) { continue }
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, ("cof-enhanced-$Version/engine-source/$top/" + $rel.Replace('\', '/')), [IO.Compression.CompressionLevel]::Optimal)
            $n++
        }
        Write-Host "source archive: $n files of the patched engine tree added"
    }
} finally { $zip.Dispose() }
Write-Host ("source archive: {0} ({1:N0} bytes)" -f $srcZip, (Get-Item -LiteralPath $srcZip).Length)

# ---- SHA256SUMS.txt -------------------------------------------------------------------
$sumLines = foreach ($f in $zipPath, $srcZip) { '{0}  {1}' -f (Hash $f).ToLowerInvariant(), (Split-Path -Leaf $f) }
[IO.File]::WriteAllText((Join-Path $OutDir 'SHA256SUMS.txt'), (($sumLines -join "`n") + "`n"))
$sumLines | ForEach-Object { Write-Host $_ }
Remove-Item -LiteralPath $stage -Recurse -Force
Write-Host "release $Version built from commit $commit"
