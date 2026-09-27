# Preserve settings during controller migration

The generation check no longer changes `joy_gyro_enable`. A saved value survives upgrading from test1 (which has no generation marker), older controller layouts, or a current layout. Fresh profiles retain the registered default of zero. Diagnostics no longer claim gyro was disabled.

Binding migration is unchanged: an existing generation-zero layout is kept; known older defaults migrate, while customized and cleared bindings remain intact. Explicit layout reset remains available.

Apply after compact ammo, before the final cheats patch. Test with `tests/cof-pad-upgrade-settings/run.py --source-root <patched tree> --out <temporary output>` from an x86 MSVC environment. The fixture compiles the real migration functions and layout tables, covering old and current generations, saved gyro values, customized/cleared keys, defaults, and repeat checks.
