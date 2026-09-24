param(
    [Parameter(Mandatory=$true)] [string] $SourceRoot,
    [switch] $Reverse
)

# Cry of Fear on-screen keyboard, the menu (patches/cof-mainui-osk.patch,
# MainUI only). See docs/design/osk.md.
#
#   * menus/CoFOsk.cpp / .h (new): the themed key grid (digits, QWERTY,
#     symbols page, Shift/Caps, Space, Delete, Done) for gamepad players. Pad:
#     D-pad/stick move, A type, B delete (held: clear), Y clear, X shift, LB
#     symbols, RB space, START Done, View Close; mouse clicks; a real keyboard
#     types too. Its own prompts line. "menu_cof_osk game" opens it over the
#     game for the engine (cof-osk-engine.patch); "menu_cof_osk status".
#   * controls/Field.cpp: a text field opens it on A, and when a pad direction
#     key moves the focus onto it in pad mode.
#   * controls/Framework.cpp: the page's prompts line steps aside while it is up.
#   * menus/CoFOptions.cpp: the input hooks tell it about pad direction keys
#     and the mouse.
#
# Goes on after cof-mainui-options-layout (step 48); needs its CoFOptions.cpp.

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $SourceRoot -PathType Container)) {
    throw "SourceRoot must be an existing directory: $SourceRoot"
}
$source = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $SourceRoot).Path)
$rootPrefix = $root.TrimEnd('\') + '\'
if (-not $source.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'SourceRoot must be inside this project workspace.'
}
$mu = '3rdparty\mainui\'
$rel = @{ field = $mu + 'controls\Field.cpp'; fw = $mu + 'controls\Framework.cpp'; opt = $mu + 'menus\CoFOptions.cpp' }
$newCpp = $mu + 'menus\CoFOsk.cpp'
$newH   = $mu + 'menus\CoFOsk.h'
foreach ($r in $rel.Values) {
    if (!(Test-Path -LiteralPath (Join-Path $source $r))) {
        throw "Not an FWGS source tree with mainui checked out and the options layout applied: $(Join-Path $source $r)"
    }
}
$mainui = Join-Path $source '3rdparty\mainui'
$head = (& git -C $mainui rev-parse HEAD 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne '61263995592e93a278d764807243d043d3b97c54') {
    throw "mainui must be at pinned baseline 61263995592e93a278d764807243d043d3b97c54; found $head"
}
$patch = Join-Path $root 'patches\cof-mainui-osk.patch'
if (!(Test-Path -LiteralPath $patch -PathType Leaf)) { throw "Missing patch: $patch" }

function Slurp([string] $r) {
    $p = Join-Path $source $r
    if (Test-Path -LiteralPath $p) { Get-Content -Raw -LiteralPath $p } else { '' }
}
function ReadAll {
    $t = @{}
    foreach ($k in @($rel.Keys)) { $t[$k] = Slurp ([string]$rel[$k]) }
    $t['cpp'] = Slurp $newCpp
    $t['h'] = Slurp $newH
    return $t
}

$t = ReadAll
$present = $t.field.Contains('UI_CoFOsk_') -or $t.fw.Contains('UI_CoFOsk_Active') -or $t.opt.Contains('UI_CoFOsk_') -or $t.cpp -or $t.h

if ($Reverse) {
    if (-not $present) { throw 'The on-screen keyboard is not present in this source tree; nothing to reverse.' }
} else {
    if ($present) { throw 'The on-screen keyboard is already present; use -Reverse first or provide a clean tree.' }
    if (-not $t.opt.Contains('bool UI_CoFInputEvent( int key, int down )') -or -not $t.opt.Contains('const char *UI_CoFPadGlyph( const char *xboxFile, const char *psFile )') -or
        -not $t.fw.Contains('void CMenuFramework::DrawPadHints( void )')) {
        throw 'Prerequisite missing: apply patches/cof-mainui-options-layout.patch first.'
    }
}

Push-Location $root
try {
    $relativeSource = $source.Substring($rootPrefix.Length).Replace('\','/')
    $extra = @()
    if ($Reverse) { $extra += '--reverse' }
    & git apply --ignore-whitespace --check --directory=$relativeSource @extra -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Patch does not apply cleanly to this source tree.' }
    & git apply --ignore-whitespace --directory=$relativeSource @extra -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'git apply failed.' }

    $t = ReadAll

    if ($Reverse) {
        if ($t.field.Contains('UI_CoFOsk_') -or $t.fw.Contains('UI_CoFOsk_Active') -or $t.opt.Contains('UI_CoFOsk_') -or $t.cpp -or $t.h) {
            throw 'Reversed, but on-screen keyboard markers or files remain. Inspect the tree.'
        }
        if (-not $t.fw.Contains('void CMenuFramework::DrawPadHints( void )')) { throw 'Reverse application damaged the options layout this one sits on.' }
        Write-Host "Reversed patches\cof-mainui-osk.patch in $source"
        return
    }

    $checks = [ordered]@{
        'the keyboard window'   = $t.cpp.Contains('class CMenuCoFOsk : public CMenuBaseWindow') -and $t.cpp.Contains('ADD_COMMAND( menu_cof_osk, UI_CoFOsk_f );') -and
                                  $t.cpp.Contains('"cof_osk_result"') -and $t.cpp.Contains('"cof_osk_submit"') -and $t.cpp.Contains('"cof_osk_over_game"') -and
                                  $t.h.Contains('bool UI_CoFOsk_Active( void );')
        'field hooks'           = $t.field.Contains('UI_CoFOsk_FieldFocus( this );') -and $t.field.Contains('if( UI_CoFOsk_FieldKey( this, key ))')
        'prompts line'          = $t.fw.Contains('|| UI_CoFOsk_Active( ))')
        'input hooks'           = $t.opt.Contains('UI_CoFOsk_NoteKey( key, down );') -and $t.opt.Contains('UI_CoFOsk_NoteMouse();')
    }
    foreach ($k in $checks.Keys) {
        if (-not $checks[$k]) { throw "Applied, but the marker for '$k' is missing. Inspect the tree." }
    }

    & git apply --ignore-whitespace --reverse --check --directory=$relativeSource -- $patch
    if ($LASTEXITCODE -ne 0) { throw 'Applied on-screen keyboard patch cannot be reverse-checked.' }
} finally {
    Pop-Location
}
Write-Host "Applied patches\cof-mainui-osk.patch in $source"
Write-Host 'Build: python waf build --targets=menu'
