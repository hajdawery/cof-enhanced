#!/usr/bin/env python3
"""Build pack/languages/<lang>/strings/dll-strings.tsv from the binary-patch
string-diff analysis of client.dll / hl.dll.

Source data (read-only):
    stage1/polish-mod-analysis-20260922/binaries/data/client_dll_string_diffs.txt
    stage1/polish-mod-analysis-20260922/binaries/data/hl_dll_string_diffs.txt

Each file holds NUL-terminated string pairs (canonical English -> mod Polish)
recovered from an in-place hex patch of the DLL's .rdata section (see
BINARIES_ANALYSIS.md). This script:

  1. Parses both files into (file_offset, canonical, mod) triples.
  2. Verifies the raw pair counts match the analysis doc's expectations
     (123 for client.dll, 109 for hl.dll).
  3. Drops a fixed, literal list of excluded offsets -- corruption the mod's
     own blanket find/replace introduced (gameplay identifiers, CRT day-name
     table damage, one NUL-terminator overrun) that must not be shipped as
     "translated display text". Two additional identifier-like pairs are
     *kept* but marked in the `flagged` column for human review.
  4. Cross-checks every excluded/flagged offset against the actual parsed
     data (by content, not just by presence) and reports any mismatch
     instead of silently skipping.
  5. Writes a UTF-8 TSV with columns: english, polish, source_dll,
     file_offset, flagged.

Idempotent: re-running regenerates the TSV deterministically from the same
read-only inputs; it does not read or depend on any previous run's output.

Text encoding: client_dll_string_diffs.txt / hl_dll_string_diffs.txt were
produced by a prior analysis pass that already re-decoded the DLLs' raw
cp1250 (and, per BINARIES_ANALYSIS.md section 5.4, some non-standard
font-glyph-slot) bytes into text and saved the result as UTF-8. This script
verified both files decode as strict UTF-8 with correctly rendered Polish
diacritics (e.g. "Nie mogę ich otworzyć" / "Nie mogę ich otworzyć")
before relying on this, so it reads them directly as UTF-8 -- no cp1250
re-decoding from the raw DLL bytes is performed or needed.
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import langpack_common as lc

DIFF_DIR = lc.ANALYSIS_ROOT / "binaries" / "data"
CLIENT_DIFF_FILE = DIFF_DIR / "client_dll_string_diffs.txt"
HL_DIFF_FILE = DIFF_DIR / "hl_dll_string_diffs.txt"

EXPECTED_RAW_COUNTS = {"client": 123, "hl": 109}

HEADER_RE = re.compile(r"^\[0x([0-9A-Fa-f]+)\]")

# ---------------------------------------------------------------------------
# Exclusion / flag lists (authoritative -- see task spec / BINARIES_ANALYSIS.md
# section 5). Offsets are the *diff-range* / *doc-table* offsets as literally
# given in the task; verify_and_resolve() maps each to the actual
# string-pair offset found in the source diff file, since for three
# client.dll entries these differ (see report).
# ---------------------------------------------------------------------------

# hl.dll identifier-corruption pairs (not display text).
HL_IDENTIFIER_EXCLUSIONS = {
    "0x001CA0B0": "ammo_buckshot",
    "0x001CC824": "sk_plr_buckshot1",
    "0x001CC838": "sk_plr_buckshot2",
    "0x001CC84C": "sk_plr_buckshot3",
    "0x001CC860": "sk_plr_buckshot4",
    "0x001CD5C4": "sk_plr_buckshot",
    "0x001AA9C4": "browningwheelchair",
    "0x001DA4CC": "SimonMode",
    "0x001DA4D8": "Syringe",
}

# CRT day-name table corruption ("Wed" -> "Wen" blanket replace hit the
# statically-linked MSVC CRT locale tables). The task's listed offsets are
# the *differing-byte* offsets from BINARIES_ANALYSIS.md section 3 (diff
# ranges), not necessarily the NUL-terminated string's *start* offset as
# recorded in the *_string_diffs.txt files this script parses -- resolved
# by content match; see report for the client.dll discrepancy.
CLIENT_CRT_EXCLUSIONS = {
    "0x0015A8DD": ":Sun:Sunday:Mon:Monday:Tue:Tuesday:Wed:Wednesday:Thu:Thursday:Fri:Friday:Sat:Saturday",
    "0x00160F12": "Wed",
    "0x00168AEF": "SunMonTueWedThuFriSat",
}
HL_CRT_EXCLUSIONS = {
    "0x001E7D30": ":Sun:Sunday:Mon:Monday:Tue:Tuesday:Wed:Wednesday:Thu:Thursday:Fri:Friday:Sat:Saturday",
    "0x001EE4B0": "Wed",
    "0x001F4A74": "SunMonTueWedThuFriSat",
}

# NUL-terminator overrun (display bug -- merged with the following literal).
CLIENT_OVERRUN_EXCLUSIONS = {
    "0x00140E44": "Unlocked: FAMAS with infinite ammo",
}

# Flag-but-keep: identifier-like per BINARIES_ANALYSIS.md section 5.2, but
# NOT in the confirmed exclusion list above -- ship them, flagged for human
# review.
FLAGGED_BUT_KEPT = {
    ("hl", "0x001B85E0"): "identifier-like (ammo registration name), not in the confirmed exclusion list",
    ("hl", "0x001B66D8"): "identifier-like (weapon/ammo identifier), not in the confirmed exclusion list",
}


class DiscrepancyError(RuntimeError):
    pass


def parse_diff_file(path: Path) -> list[tuple[str, str, str]]:
    """Parse a *_string_diffs.txt file into (file_offset, canonical, mod) triples.

    file_offset is normalized to "0xUPPERHEX" as given in the source file.
    Line-based (not a single regex) so it tolerates the occasional extra
    trailing annotation on a header line (e.g. "  <non-textual>").
    """
    text = path.read_text(encoding="utf-8")
    lines = text.replace("\r\n", "\n").split("\n")
    entries: list[tuple[str, str, str]] = []
    i = 0
    n = len(lines)
    while i < n:
        m = HEADER_RE.match(lines[i])
        if not m:
            i += 1
            continue
        offset = "0x" + m.group(1).upper()
        if i + 2 >= n:
            raise DiscrepancyError(f"{path.name}: truncated entry at offset {offset} (line {i + 1})")
        canon_line = lines[i + 1]
        mod_line = lines[i + 2]
        canon_prefix = "  canonical: "
        mod_prefix = "  mod      : "
        if not canon_line.startswith(canon_prefix):
            raise DiscrepancyError(
                f"{path.name}: expected canonical line after {offset}, got {canon_line!r}"
            )
        if not mod_line.startswith(mod_prefix):
            raise DiscrepancyError(
                f"{path.name}: expected mod line after {offset}, got {mod_line!r}"
            )
        canonical = canon_line[len(canon_prefix):]
        mod = mod_line[len(mod_prefix):]
        entries.append((offset, canonical, mod))
        i += 3
    return entries


def index_by_content(entries: list[tuple[str, str, str]]) -> dict[str, list[tuple[str, str, str]]]:
    """Map canonical-string text -> list of matching entries, for discrepancy resolution."""
    idx: dict[str, list[tuple[str, str, str]]] = {}
    for e in entries:
        idx.setdefault(e[1], []).append(e)
    return idx


def resolve_offset(
    label: str,
    claimed_offset: str,
    expected_canonical: str,
    by_offset: dict[str, tuple[str, str, str]],
    entries: list[tuple[str, str, str]],
    report: list[str],
) -> str:
    """Return the actual file_offset to use for exclusion, verifying the
    claimed offset against the parsed data.

    First checks whether claimed_offset is present *and* its canonical text
    matches expected_canonical exactly. If the offset is present but the
    content differs, or the offset is entirely absent, falls back to an
    exact-equality search over all entries' canonical text (unambiguous by
    construction for the strings used here) and records the discrepancy.
    """
    if claimed_offset in by_offset:
        actual_canonical = by_offset[claimed_offset][1]
        if actual_canonical == expected_canonical:
            return claimed_offset
        report.append(
            f"DISCREPANCY: {label} offset {claimed_offset} exists but canonical text "
            f"{actual_canonical!r} != expected {expected_canonical!r}; falling back to content match."
        )
    else:
        report.append(
            f"DISCREPANCY: {label} exclusion offset {claimed_offset} not present in source diff "
            f"file (this offset is the BINARIES_ANALYSIS.md diff-range/interior-byte offset, not "
            f"the string-pair start offset used by *_string_diffs.txt); resolving by exact "
            f"canonical-text match instead."
        )
    candidates = [e for e in entries if e[1] == expected_canonical]
    if len(candidates) == 1:
        actual = candidates[0][0]
        report.append(
            f"  -> resolved {label} {claimed_offset} to actual offset {actual} "
            f"(canonical={expected_canonical!r})."
        )
        return actual
    if not candidates:
        report.append(
            f"DISCREPANCY: {label} exclusion offset {claimed_offset} -- no entry with canonical "
            f"text {expected_canonical!r} found either -- exclusion could NOT be applied."
        )
        return claimed_offset  # will simply not match anything; entry stays included
    report.append(
        f"DISCREPANCY: {label} exclusion offset {claimed_offset} -- {len(candidates)} entries share "
        f"canonical text {expected_canonical!r}; AMBIGUOUS, exclusion could not be unambiguously applied."
    )
    return claimed_offset


def build(lang: str) -> None:
    cfg = lc.get_language(lang)  # noqa: F841 (validates lang is configured)

    if not CLIENT_DIFF_FILE.is_file():
        raise SystemExit(f"Missing source file: {CLIENT_DIFF_FILE}")
    if not HL_DIFF_FILE.is_file():
        raise SystemExit(f"Missing source file: {HL_DIFF_FILE}")

    client_entries = parse_diff_file(CLIENT_DIFF_FILE)
    hl_entries = parse_diff_file(HL_DIFF_FILE)

    report: list[str] = []
    report.append(f"Raw pairs read: client.dll={len(client_entries)} (expected {EXPECTED_RAW_COUNTS['client']}), "
                   f"hl.dll={len(hl_entries)} (expected {EXPECTED_RAW_COUNTS['hl']}).")
    if len(client_entries) != EXPECTED_RAW_COUNTS["client"]:
        report.append(f"WARNING: client.dll raw pair count mismatch!")
    if len(hl_entries) != EXPECTED_RAW_COUNTS["hl"]:
        report.append(f"WARNING: hl.dll raw pair count mismatch!")

    client_by_offset = {e[0]: e for e in client_entries}
    hl_by_offset = {e[0]: e for e in hl_entries}

    # Resolve every claimed exclusion offset against actual parsed data.
    client_exclude_offsets: set[str] = set()
    hl_exclude_offsets: set[str] = set()

    for off, hint in CLIENT_CRT_EXCLUSIONS.items():
        actual = resolve_offset("client.dll CRT", off, hint, client_by_offset, client_entries, report)
        client_exclude_offsets.add(actual)
    for off, hint in CLIENT_OVERRUN_EXCLUSIONS.items():
        actual = resolve_offset("client.dll overrun", off, hint, client_by_offset, client_entries, report)
        client_exclude_offsets.add(actual)
    for off, hint in HL_IDENTIFIER_EXCLUSIONS.items():
        actual = resolve_offset("hl.dll identifier", off, hint, hl_by_offset, hl_entries, report)
        hl_exclude_offsets.add(actual)
    for off, hint in HL_CRT_EXCLUSIONS.items():
        actual = resolve_offset("hl.dll CRT", off, hint, hl_by_offset, hl_entries, report)
        hl_exclude_offsets.add(actual)

    # Verify exact-content match for every resolved exclusion (paranoia check).
    for off in sorted(client_exclude_offsets):
        if off not in client_by_offset:
            report.append(f"DISCREPANCY: resolved client.dll exclusion offset {off} still missing after resolution.")
    for off in sorted(hl_exclude_offsets):
        if off not in hl_by_offset:
            report.append(f"DISCREPANCY: resolved hl.dll exclusion offset {off} still missing after resolution.")

    report.append(
        f"Exclusions applied: client.dll={len(client_exclude_offsets)} "
        f"(expect 4 = 3 CRT + 1 overrun), hl.dll={len(hl_exclude_offsets)} "
        f"(expect 12 = 9 identifier + 3 CRT)."
    )

    # Verify flagged-but-kept offsets are present and not accidentally excluded.
    for (dll, off), reason in FLAGGED_BUT_KEPT.items():
        by_offset = hl_by_offset if dll == "hl" else client_by_offset
        if off not in by_offset:
            report.append(f"DISCREPANCY: flagged-but-kept offset {off} ({dll}.dll) not found in source data!")
        exclude_set = hl_exclude_offsets if dll == "hl" else client_exclude_offsets
        if off in exclude_set:
            report.append(f"DISCREPANCY: flagged-but-kept offset {off} ({dll}.dll) was also matched by an exclusion rule!")

    rows: list[tuple[str, str, str, str, str]] = []
    for off, canonical, mod in client_entries:
        if off in client_exclude_offsets:
            continue
        flag = FLAGGED_BUT_KEPT.get(("client", off), "")
        rows.append((canonical, mod, "client", off, flag))
    for off, canonical, mod in hl_entries:
        if off in hl_exclude_offsets:
            continue
        flag = FLAGGED_BUT_KEPT.get(("hl", off), "")
        rows.append((canonical, mod, "hl", off, flag))

    report.append(f"Final row count written: {len(rows)}.")

    flagged_rows = [r for r in rows if r[4]]
    report.append(f"Flagged-but-kept rows present: {len(flagged_rows)} "
                   f"(expect 2): " + "; ".join(f"{r[3]} ({r[2]})" for r in flagged_rows))

    # Project overrides: retranslations and keep-English decisions keyed by
    # (source_dll, file_offset); see string_overrides_<lang>.tsv beside this
    # script. A leading control byte in the canonical string (e.g. ) is
    # preserved in front of the override text.
    ov_path = Path(__file__).with_name(f"string_overrides_{lang}.tsv")
    if ov_path.exists():
        overrides = {}
        with open(ov_path, encoding="utf-8", newline="") as fh:
            for r in csv.DictReader(fh, delimiter="	"):
                overrides[(r["source_dll"], r["file_offset"].lower())] = r
        applied = 0
        new_rows = []
        for canonical, mod, dll, off, flag in rows:
            key = (dll, str(off).lower())
            if key in overrides:
                o = overrides[key]
                prefix = canonical[:1] if canonical and ord(canonical[0]) < 32 else ""
                mod = prefix + o["polish"]
                flag = o["note"]
                applied += 1
            new_rows.append((canonical, mod, dll, off, flag))
        rows = new_rows
        report.append(f"Applied {applied} project overrides from {ov_path.name} (expect {len(overrides)}).")

    out_path = lc.dll_strings_tsv_path(lang)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh, delimiter="\t", lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
        writer.writerow(["english", "polish", "source_dll", "file_offset", "flagged"])
        for row in rows:
            writer.writerow(row)

    report.append(f"Wrote {out_path} ({len(rows)} data rows + header).")

    print("\n".join(report))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--lang", default="polish", help="language code (see langpack_common.LANGUAGES)")
    args = ap.parse_args()
    build(args.lang)


if __name__ == "__main__":
    main()
