# Validation — player outfit colorways (#342)

- Production source: `fab489026058484960b7bd3ef7418e14466c6356`.
- Tested development stamp: `v1.6-40-gfab4890260`.
- Development ROM MD5: `02052ab0077c430cd6aece2873f8eaf5`.
- Development ROM SHA256: `01bcb9a70f0cd964737a50c9f7b04b799646ae7cc2c519588ffcf6dd5e71c19c`.
- Baseline production source: `3bc343d0331064646d4ce99b4b691291e1a6bf0c`.
- Baseline ROM SHA256: `a70354d7a31d6660bb9b25fee8bddaedb2eda66a1bc045bcbd6e599bafd170a0`.

| Check | Result |
| --- | --- |
| Development `make modern` | PASS |
| Release configuration compile | PASS; development build delivered |
| `make validate` | PASS; existing bounds-warning baseline unchanged |
| Full ordinary-build Lua regression sweep | 50/50 suites, fresh matching-ROM sentinels |
| Before surfaces / returns / save reload | 249/249 |
| After surfaces / returns / save reload | 249/249 |
| Before Oak picker, Brendan and May | 26/26 each |
| After Oak picker, Brendan and May | 26/26 each |
| Unmodified ROM with prepared save | 12/12 |
| Source asset audit | Six tables; all 22 affected sprite sheets |
| Red native before/after comparisons | 10/10 pixel-identical |
| Lossless send-out clips | All 24 decoded and matched to capture pixels/timing |

All six outfits and both genders were checked in the real overworld, water
reflection, own trainer card, battle back sprite and throw, and actual Oak picker.
Black, Purple and Pink were additionally checked at night. Every runtime check
compares all 16 source colors, including protected entries, and verifies the
faded palette agrees with GBA palette RAM. Save/reload is checked using May/Black;
the ordinary delivery ROM independently loads that save and uses the normal menu.

The 50-suite regression sweep covers the existing gameplay systems. CI provides
the separate upstream battle suite and feature-flag compilation gates after PR
creation; those results are not claimed as local passes here. This is a palette
change with no new game logic, save fields, asset ownership, or external credits.

The complete compiler logs remain local; their hashes and terminal build output
are in the build summaries. Existing unrelated release-configuration warnings
remain. The review manifest separately identifies the ROM's actual build commit
and the later baseline checkout HEAD. No game rebuild occurs for evidence-only
commits.
