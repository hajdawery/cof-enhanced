# CoF menu-save fault harness

`run-harness.bat` regenerates `actual_extracted.inc` from the default source tree, builds the standalone harness, and runs its fake-filesystem transaction tests. It does not launch the game. The batch file changes to its own directory, so it can be invoked from the repository root or any other working directory.

Pass `-SourceRoot <source-root>` to select another checkout; the batch file forwards its arguments to `extract-actual.ps1`:

```bat
tests\cof-menu-save\run-harness.bat -SourceRoot K:\path\to\xash3d-fwgs
```

The extractor can also be run directly with `powershell -ExecutionPolicy Bypass -File extract-actual.ps1 -SourceRoot <source-root>`. Generated `.inc`, `.exe`, and object files are ignored and must not be committed.
