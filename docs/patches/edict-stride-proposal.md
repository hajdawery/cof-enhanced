# CoF edict stride proposal

> **Status (2026-09-22 docs pass):** this overlay is no longer "unapplied". It is step 3
> of the verified engine stack ([patch stack](../dev/patch-stack.md)), every engine
> built since milestone 1 carries it, and the deployed PDBs report `edict_s` =
> `0x32C` (see [the campaign/save-load checkpoint](../history/campaign-save-load-test.md)).
> The text below is the original proposal, kept as written.

This is an **unapplied diagnostic overlay**. It must be applied after
`patches/cof-entvars-legacy.patch` and built only with the existing opt-in
`XASH_COF_ENTVARS_LEGACY=1` profile. It has not been applied to the shared
source tree or built.

Use the project helpers from the repository root so the prerequisite and patch
order are checked:

```powershell
pwsh -File .\scripts\apply-cof-entvars-profile.ps1 `
  -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
pwsh -File .\scripts\apply-cof-edict-stride-profile.ps1 `
  -SourceRoot .\xash3d-fwgs-4857b389e6ba32ddaa68582aedcbc950c138f46a
```

Each helper verifies its expected source markers after `git apply` and runs a
reverse `git apply --check`; a successful process exit alone is not evidence
that the source changed. Apply to a clean ignored source copy and keep the
generated outputs outside the repository's tracked file set.

The corrected profile PDB proves `entvars_s` is `0x2A8` bytes and `edict_s` is
`0x328` bytes. Its stable engine members are `pvPrivateData` at `edict +
0x7C` and `v` at `edict + 0x80`. Original `hl.dll` `pfnServerActivate`
(API slot 21) checks `edict + 0x7C` and advances its entity pointer by
`0x32C`; the profile engine indexes its own array by `0x328`.

The `0x32C` stride is repeated in the original DLL outside this callback,
including loops at preferred addresses `0x1001935B`, `0x1006A1FB`,
`0x10070A94`, `0x1009446E`, and `0x100CA286`. These are direct disassembly
constants, not inferred structure sizes.

The overlay adds one trailing reserved `int` after `v`, producing `sizeof`
`edict_s == 0x32C` while leaving all existing member offsets unchanged. It
adds compile-time assertions for the verified `sequence`,
`pContainingEntity`, `pvPrivateData`, and `v` offsets plus the resulting
stride. The reserved field name is deliberately diagnostic: the original
field identity has not been recovered, so this does not claim a complete
CoF `edict_s` reconstruction.

Validation target: build a fresh isolated engine with the entvars profile and
this overlay, record the executable/PDB hashes, then repeat the existing
`c_intro` callback-stage test in a separate runtime. No runtime conclusion is
made by this proposal.
