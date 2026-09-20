[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $DllPath,

    [ValidateRange(0, 0x7FFFFFFF)]
    [int] $TableFileOffset = 0x219AE0,

    [ValidateRange(1, 10000)]
    [int] $MaxRecords = 120
)

$ErrorActionPreference = 'Stop'
$resolvedDll = (Resolve-Path -LiteralPath $DllPath -ErrorAction Stop).Path
$bytes = [IO.File]::ReadAllBytes($resolvedDll)

if ($bytes.Length -lt 0x40 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
    throw "Not a DOS/PE image: $resolvedDll"
}

$pe = [BitConverter]::ToInt32($bytes, 0x3C)
if ($pe -lt 0 -or ($pe + 24) -ge $bytes.Length -or
    [BitConverter]::ToUInt32($bytes, $pe) -ne 0x00004550) {
    throw "Invalid PE header: $resolvedDll"
}

$sectionCount = [BitConverter]::ToUInt16($bytes, $pe + 6)
$optionalSize = [BitConverter]::ToUInt16($bytes, $pe + 20)
$sectionBase = $pe + 4 + 20 + $optionalSize
if ($sectionBase -lt 0 -or ($sectionBase + (40 * $sectionCount)) -gt $bytes.Length) {
    throw "Invalid PE section table: $resolvedDll"
}

$imageBase = [BitConverter]::ToUInt32($bytes, $pe + 4 + 20 + 28)
$sections = @()
for ($i = 0; $i -lt $sectionCount; $i++) {
    $p = $sectionBase + (40 * $i)
    $sections += [pscustomobject]@{
        VirtualSize = [BitConverter]::ToUInt32($bytes, $p + 8)
        VirtualAddress = [BitConverter]::ToUInt32($bytes, $p + 12)
        RawSize = [BitConverter]::ToUInt32($bytes, $p + 16)
        RawPointer = [BitConverter]::ToUInt32($bytes, $p + 20)
    }
}

function Convert-VaToFileOffset([uint32] $VirtualAddress) {
    $rva = [uint64] $VirtualAddress - [uint64] $imageBase
    foreach ($section in $sections) {
        $span = [Math]::Max($section.VirtualSize, $section.RawSize)
        if ($rva -ge $section.VirtualAddress -and
            $rva -lt ($section.VirtualAddress + $span)) {
            $offset = [uint64] $section.RawPointer + ($rva - $section.VirtualAddress)
            if ($offset -lt $bytes.Length) { return [int] $offset }
            return -1
        }
    }
    return -1
}

function Read-StringAtVa([uint32] $VirtualAddress) {
    $offset = Convert-VaToFileOffset $VirtualAddress
    if ($offset -lt 0 -or $offset -ge $bytes.Length) { return $null }
    $end = $offset
    while ($end -lt $bytes.Length -and $bytes[$end] -ne 0) { $end++ }
    if ($end -eq $offset) { return $null }
    return [Text.Encoding]::ASCII.GetString($bytes[$offset..($end - 1)])
}

if (($TableFileOffset + 16) -gt $bytes.Length) {
    throw "Descriptor table starts beyond the image: 0x{0:X8}" -f $TableFileOffset
}

Write-Output ("DLL SHA256: " + (Get-FileHash -LiteralPath $resolvedDll -Algorithm SHA256).Hash)
Write-Output ("Table file offset: 0x{0:X8}" -f $TableFileOffset)
Write-Output 'record fieldType fieldOffset fieldSize flags name'

$invalid = 0
for ($i = 0; $i -lt $MaxRecords; $i++) {
    $record = $TableFileOffset + (16 * $i)
    if (($record + 16) -gt $bytes.Length) { break }

    $fieldType = [BitConverter]::ToUInt32($bytes, $record)
    $namePointer = [BitConverter]::ToUInt32($bytes, $record + 4)
    $fieldOffset = [BitConverter]::ToUInt32($bytes, $record + 8)
    $sizeFlags = [BitConverter]::ToUInt32($bytes, $record + 12)
    $name = Read-StringAtVa $namePointer
    $fieldSize = $sizeFlags -band 0xFFFF
    $flags = ($sizeFlags -shr 16) -band 0xFFFF

    if ($null -eq $name -or $fieldType -gt 0x11) {
        $invalid++
        if ($invalid -ge 3) { break }
        continue
    }
    $invalid = 0
    Write-Output ("{0,5} {1,10:X} {2,11:X3} {3,9:X} {4,5:X} {5}" -f
        $i, $fieldType, $fieldOffset, $fieldSize, $flags, $name)
}
