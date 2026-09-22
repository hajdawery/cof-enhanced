# Cry of Fear: Enhanced documentation

Technical documentation for people who build, test or change Cry of Fear:
Enhanced. Players want the [README](../README.md) and [CHEATS.md](../CHEATS.md)
instead.

## Start here

* [Building](dev/building.md) - toolchain, source tree, configure flags, outputs.
* [The patch stack](dev/patch-stack.md) - **the authoritative apply order** of
  all 48 patches, the apply-script conventions and how to verify a stack.
* [Patch index](patches/README.md) - what every patch changes and why, with
  its cvars and commands.
* [Engine and game facts](history/engine-and-game-facts.md) - what we know
  about Cry of Fear on Xash3D FWGS, one paragraph per fact, with evidence links.
* [Contributing](../CONTRIBUTING.md) and [licensing](../LICENSING.md).

## `dev/` - building, testing, shipping

| Page | About |
| --- | --- |
| [building.md](dev/building.md) | toolchain, pinned sources, generated headers, waf configure/build, the launcher |
| [patch-stack.md](dev/patch-stack.md) | apply order, marker and `-Reverse` conventions, stack verification |
| [testing.md](dev/testing.md) | hard rules for launches, fixtures, cfg-only test hooks, evidence |
| [releases-and-deploy.md](dev/releases-and-deploy.md) | staging rule, the deploy script, the public release and the planned patcher |
| [steam-launch-prototype.md](dev/steam-launch-prototype.md) | the launcher contract and the reusable fixture workflow |
| [custom-ui-regression-checklist.md](dev/custom-ui-regression-checklist.md) | interaction gates for the game's own UI |
| [display-reference-audit.md](dev/display-reference-audit.md) | resolution acceptance matrix |
| [crash-capture-guidance.md](dev/crash-capture-guidance.md) | what a first-chance crash capture proves |
| [xash-goldsrc-developer-notes.md](dev/xash-goldsrc-developer-notes.md) | reusable engine lessons (the "special Xash notes") |

## `patches/` - one page per patch

The [patch index](patches/README.md) lists them all with their stack position.
Grouped:

* **Compatibility base:** [pmove adapter](patches/pmove-adapter.md),
  [pmove callback view (crouch fix)](patches/cof-pmove-callback-view.md),
  [edict stride](patches/edict-stride-proposal.md).
* **Saves:** [menu-load trace](patches/menu-load-trace.md),
  [root SAVE compatibility](patches/cof-save-root-compat.md),
  [pause-save plumbing](patches/cof-pause-save-plumbing.md),
  [menu-save backend](patches/cof-menu-save-backend.md),
  [tape-save command](patches/cof-tape-save-command.md),
  [MainUI menu save](patches/cof-mainui-menu-save.md).
* **Renderer:** [GL stage trace](patches/cof-gl-stage-trace.md),
  [solid-entity trace](patches/cof-solid-entity-trace.md),
  [transparent-triangle trace](patches/cof-transparent-triangle-trace.md),
  [skyline trace](patches/cof-skyline-trace.md),
  [GL debug stack](patches/cof-gl-debug-stack.md),
  [custom renderfx opaque (skyline fix)](patches/cof-custom-renderfx-opaque.md),
  [sprite frames](patches/cof-sprite-quiet-frames.md).
* **Unified UI, engine side:** [milestone 1 plumbing](patches/cof-ui-m1-plumbing.md),
  [milestone 2 Cry of Fear menu](patches/cof-ui-m2-cof-menu.md),
  [input gate](patches/cof-ui-input-gate.md),
  [video mode restart](patches/cof-vid-restart-background.md),
  [menu-map redirect](patches/cof-ui-menu-map-redirect.md),
  [menu sound volume](patches/cof-ui-sound-volume.md),
  [death flow](patches/cof-ui-death-flow.md),
  [levelshot guard](patches/cof-levelshot-guard.md).
* **Console and text:** [console font fallback](patches/cof-console-variable-font-fallback.md),
  [styled console](patches/cof-console-style.md),
  [text autoscale](patches/cof-text-autoscale.md),
  [HUD text legibility](patches/cof-hud-text-legibility.md),
  [build stamp](patches/cof-cofenhanced-version.md).
* **Gameplay and world:** [MP3 stop on map](patches/cof-mp3-stop-on-map.md),
  [sky reset per map](patches/cof-sky-reset-per-map.md),
  [field of view](patches/cof-fov.md),
  [aim down sights, binds, chapter rule](patches/cof-ads-toggle.md).

## `design/` - the larger features

| Page | About |
| --- | --- |
| [ui-theme.md](design/ui-theme.md) | the Source-style menu: palette, type, every page, Options, Unlockables, Credits |
| [ui-scaling.md](design/ui-scaling.md) | the in-game UI scaled from the display (`cof_ui_scale`) |
| [fonts.md](design/fonts.md) | which text is drawn by what, from which font file |
| [vgui-inter-fonts.md](design/vgui-inter-fonts.md) | the client's VGUI text from Inter, code pages |
| [language-packs.md](design/language-packs.md) | `cof_language`, the pack format, hooks, the Language option, menu strings |
| [coop-bridge.md](design/coop-bridge.md) | Host / Join co-op pages and engine shims |
| [cheats.md](design/cheats.md) | cheats internals: the hash gate, offsets, latches (player list: [CHEATS.md](../CHEATS.md)) |
| [branding.md](design/branding.md) | the emblem and icons |

## `history/` - how we got here

| Page | About |
| --- | --- |
| [milestones.md](history/milestones.md) | the project timeline, milestone by milestone |
| [engine-and-game-facts.md](history/engine-and-game-facts.md) | the established technical facts, with evidence links |
| [menu-transition-investigation.md](history/menu-transition-investigation.md) | Stage 2 menu-to-game transition, the skyline hand-off |
| [abi-findings.md](history/abi-findings.md), [entvars-layout-analysis.md](history/entvars-layout-analysis.md), [dedicated-profile-test.md](history/dedicated-profile-test.md) | the first ABI evidence |
| [client-pmove-adapter-test.md](history/client-pmove-adapter-test.md), [campaign-save-load-test.md](history/campaign-save-load-test.md), [client-build-checkpoint.md](history/client-build-checkpoint.md) | the first client build and runs |
| [steam-play-test.md](history/steam-play-test.md) | the one Steam-parented launch test |
| [cof-custom-ui-scaling-research.md](history/cof-custom-ui-scaling-research.md) | UI ownership and coordinate spaces before the scaling work |

Pages in `history/` are records: they carry a status banner where later work
changed their conclusions, but their evidence is left as written.

## Other files

* [player-README-template.md](player-README-template.md) - the README every
  release archive ships (filled in by the release tooling; carries licence
  obligations).
* [`release/RELEASE-MANIFEST.md`](../release/RELEASE-MANIFEST.md) - what a
  release archive contains and what it must not.
* [`languages/README.md`](../languages/README.md) - the language-pack format;
  [`gamedata/README.md`](../gamedata/README.md) - the game-directory overlay files;
  [`scripts/polish/README.md`](../scripts/polish/README.md) - the pack generators.

### Redirect stubs

`cof-cheats.md`, `cof-coop-bridge.md`, `cof-hud-text-legibility.md`,
`cof-language-packs.md`, `cof-sprite-quiet-frames.md`, `cof-text-autoscale.md`,
`cof-ui-death-flow.md`, `cof-ui-m1-plumbing.md`, `cof-ui-m2-cof-menu.md`,
`cof-ui-m3-theme.md`, `cof-ui-m4-scaling.md` and `cof-ui-menu-map-redirect.md`
in this folder are one-line stubs pointing to the new locations. They stay
because patch comments, apply scripts and the `languages/` and `gamedata/`
READMEs still name those paths; remove a stub once nothing references it.
