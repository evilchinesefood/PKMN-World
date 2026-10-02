# Menu responsiveness and icons

Local main-menu actions no longer probe absent wireless hardware before fading or entering their destination. The optional Mystery Gift/e-Reader actions still check the adapter. Options and Story footer panels have rounded top corners and a solid white bottom edge flush with the screen bottom. Story uses the previous paper-and-pencil Save artwork; Save uses a shaded floppy disk with a white outer keyline, metallic shutter, and inset paper label. Its inactive and selected frames retain the existing 16-color palette and 32-by-32 frame size.

| Story icon | Save icon | Top-rounded footer |
| --- | --- | --- |
| ![Story icon](evidence/story-icon.png) | ![Save icon](evidence/save-icon.png) | ![Options](evidence/options.png) |

[Story footer](evidence/story.png). Screenshots are native emulator output from disposable synthetic fixtures.

## Reproduce

```sh
make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8
python3 test/overworld/menu-polish/run.py --out /tmp/pw-menu-polish
```

The runner builds an isolated fixture from the matching ROM/ELF and boots a fresh game for each scenario; no personal save is used. It measures emulated frames from A to palette movement and the expected destination callback, and checks rounded top corners and every pixel along the solid bottom row at screen y=159 after redraws. It also captures both icons and checks return to the field.

| Choice | Before: fade / destination frames | After: fade / destination frames |
| --- | --- | --- |
| Continue | 36 / 92 | 2 / 23 |
| New Game | 35 / 91 | 2 / 23 |
| Options | 34 / 90 | 2 / 23 |

Baseline: `4303e6ddcb`; all three baseline latency checks failed. After the footer refinement: 12/12 transition checks and 17/17 footer/navigation checks passed. The five new flat-bottom checks all failed against the earlier PR build and pass with the refinement. These measure destination callback entry, not completion of every destination's startup animation. Optional wireless hardware paths were reviewed by inspection; they are disabled in the shipped build.

Current refinement verification: modern ROM build and all content-validation pre-push checks pass. Screenshots above were recaptured from this build.

Earlier PR verification: `make validate`, the existing Story renderer fixture (22/22), and production Story tests (31/31, including save/Continue).
