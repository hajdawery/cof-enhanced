# CoF tape-save command compatibility

This experimental patch restores the original Cry of Fear client-side
`savehack cofsave1` through `savehack cofsave5` command boundary when
`cof_save_root_compat 1` is enabled for the `cryoffear` game folder. It is
independent of optional menu-save behavior.

The hook is deliberately narrow. It requires an active single-player session,
rejects demo playback, and accepts only a complete command whose slot is one
of `1` through `5`. A slot outside that range, a path separator, a semicolon,
an extra token, or another command after a newline falls through unchanged to
the normal client-to-server `pfnServerCmd` path. The existing server save
validation (`IsValidSave`) is unchanged. The compatibility cvar remains the
only enablement guard, so other games and the default configuration keep the
normal behavior.

The original binary evidence is static and binary-specific: client-side
`savehack` interception occurs at `hw.dll` offsets `0x1D21AF5` and
`0x1D21BCC`, tokenization is around `0x1D44D36`, the force flag is at
`0x23C9F1C`, and the save handler is around `0x1D829D5`. The original client
delays the request around `0x1007279B..0x100727AA`. These addresses are not a
portable API contract; they document why a client command hook is needed to
preserve the tape-recorder path.

Apply after `cof-save-root-compat.patch` with:

```powershell
pwsh -NoProfile -File scripts/apply-cof-tape-save-command.ps1 `
  -SourceRoot <source-tree>
```

The helper confines the source tree to this project, checks the base cvar,
performs a forward `git apply --check`, verifies the inserted markers, and
supports a checked reverse application with `-Reverse`. No unsafe path option
is used. A disposable source fixture passed forward application, marker
verification, reverse checking, and reverse application. The slot boundary was
also checked statically for valid `1`–`5` commands and passthrough of `0`, `6`,
multi-digit slots, path/semicolon/extra-token forms, and newline-followed
commands.

No native tape-recorder runtime test is claimed yet. Menu-save work must keep
this path separate and preserve the original five-slot behavior.
