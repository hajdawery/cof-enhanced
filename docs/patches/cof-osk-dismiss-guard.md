# OSK dismissal key guard

An Enter key used for Done must not also submit the game's computer form.
The game's client polls Windows `GetAsyncKeyState(VK_RETURN)` independently
of engine key routing. Closing the OSK immediately restores game focus, so
simply removing the synthetic Enter command still allowed held real Enter
through. START repeats could likewise rearm synthetic Enter after closing.

The additive `cof-osk-dismiss-guard` patch follows the compact/context OSK
patch. It changes only engine files. `cof_osk_dismiss_guard` defaults to **1**;
set it to **0** to restore earlier dismissal-key routing for comparison.

The first Enter, keypad Enter or START press still reaches the OSK. Repeated
downs from that same held press are consumed until release, even if queued
in the same event batch as Done. Releases continue into engine bookkeeping.
When accepting the OSK result, `CL_CoF_EnterOskDismiss` clears stale synthetic
Enter pulse/hold state and records held confirmation keys. The client hook
masks physical Enter until it observes release, including the Windows low
transition bit on the first released poll. A fresh press after release works
normally. Other keys and mouse clicks, including the game's OK button, keep
their existing paths. START's intentional Enter mapping outside the OSK stays
available through `cof_enter_pad`.

The scoped test in `tests/cof-osk-dismiss-guard/run.py` compiles the actual
patched dismissal, key-event and Windows-poll functions against host stubs.
It covers all three closing keys, repeated downs before/after result handling,
release then fresh confirmation, stale synthetic state, real Enter without an
engine event, unrelated keys and the compatibility cvar. It performs no OS
input injection and launches no game. Full retail input/render ordering still
requires manual validation after integration.
