# Crash capture guidance

The test-only `stage1/launch-proof/crash-capture.exe` debugger helper starts a
target with `DEBUG_ONLY_THIS_PROCESS`, prints the first interesting exception
and a symbolized stack, then terminates that target. It is useful for bounded
diagnostic runs because the debugger owns the exception and prevents an
unattended Windows error dialog. Run it from the isolated runtime directory
so the matching Xash PDBs are available to DbgHelp.

This helper is an early-stop diagnostic mode. It currently captures the first
chance access violation and therefore can stop on an exception that the target
would have handled. Its output must not be treated as proof of an unhandled
crash without corroboration from the target log or a minidump. For a new root
cause, prefer a second-chance/unhandled-event capture or compare the helper's
stack with the engine's own crash log and dump.

Example (all files remain in the isolated Stage 1 tree):

```powershell
Push-Location stage1/launch-proof/runtime
& ..\crash-capture.exe .\xash-cof-adapter.exe -game cryoffear -dev 2 `
  -cof-pmove-legacy -minidumps -log ..\runtime-adapter-capture.log `
  -console -ref gl -windowed -width 800 -height 600 +map c_intro
Pop-Location
```

Do not disable Windows Error Reporting globally or change registry settings
to suppress dialogs. Keep this helper and its target confined to the copied
runtime, and terminate any target process left after a bounded run.
