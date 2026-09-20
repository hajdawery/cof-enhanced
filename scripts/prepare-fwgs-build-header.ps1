[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[ValidateSet('client', 'dedicated')]
	[string] $Target,

	[string] $SourceRoot = '',
	[string] $BuildCommit = '4857b389e6ba32ddaa68582aedcbc950c138f46a',
	[string] $BuildBranch = 'continuous',
	[string] $BuildDate = '2026-09-19'
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = [IO.Path]::GetFullPath((Join-Path $scriptRoot '..'))
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $projectRoot 'xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a'
}

$resolvedRoot = (Resolve-Path -LiteralPath $SourceRoot -ErrorAction Stop).Path
$projectPrefix = $projectRoot.TrimEnd('\') + '\'
if (-not $resolvedRoot.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
	throw "SourceRoot must be inside this project workspace: $projectRoot"
}
$commonDir = Join-Path $resolvedRoot 'common'
if (-not (Test-Path -LiteralPath $commonDir -PathType Container)) {
	throw "SourceRoot does not contain common/: $resolvedRoot"
}

$isDedicated = $Target -eq 'dedicated'
$sdl = if ($isDedicated) { 0 } else { 2 }
$refGl = if ($isDedicated) { 0 } else { 1 }
$timer = if ($isDedicated) { 'TIMER_WIN32' } else { 'TIMER_SDL' }
$video = if ($isDedicated) { 'VIDEO_NULL' } else { 'VIDEO_SDL' }
$sound = if ($isDedicated) { 'SOUND_NULL' } else { 'SOUND_SDL' }
$input = if ($isDedicated) { 'INPUT_NULL' } else { 'INPUT_SDL' }
$messageBox = if ($isDedicated) { 'MSGBOX_WIN32' } else { 'MSGBOX_SDL' }

$header = @"
#ifndef XASH_BUILD_H
#define XASH_BUILD_H
#define XASH_WIN32 1
#define XASH_POSIX 0
#define XASH_LINUX 0
#define XASH_APPLE 0
#define XASH_DOS4GW 0
#define XASH_PSP 0
#define XASH_NSWITCH 0
#define XASH_SDL $sdl
#define XASH_GAMEDIR "valve"
#define XASH_LOW_MEMORY 0
#define XASH_LITTLE_ENDIAN 1
#define XASH_BIG_ENDIAN 0
#define XASH_64BIT 0
#define XASH_REF_GL_ENABLED $refGl
#define XASH_REF_SOFT_ENABLED 0
#define XASH_REF_NULL_ENABLED 0
#define XASH_TIMER $timer
#define XASH_VIDEO $video
#define XASH_SOUND $sound
#define XASH_INPUT $input
#define XASH_LIB LIB_WIN32
#define XASH_MESSAGEBOX $messageBox
#define XASH_AVI AVI_NULL
#define HAVE_TGMATH_H 1
#define HAVE_STRNICMP 1
#define HAVE_STRICMP 1
#define ALLOCA_H <malloc.h>
#define XASH_BUILD_COMMIT "$BuildCommit"
#define XASH_BUILD_BRANCH "$BuildBranch"
#define XASH_BUILD_COMMIT_DATE "$BuildDate"
#endif
"@

foreach ($relativePath in @('common/build.h', 'build.h')) {
	$path = Join-Path $resolvedRoot $relativePath
	Set-Content -LiteralPath $path -Value $header -NoNewline -Encoding utf8
}

Write-Output "Generated $Target build headers under $resolvedRoot"
