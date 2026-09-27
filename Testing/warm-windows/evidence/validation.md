# #335 verification

Production build source: `3bc343d0331064646d4ce99b4b691291e1a6bf0c`,
stamp `v1.6-36-g3bc343d033`. The later evidence commit does not rebuild this ROM.

Before ROM source: `13478c088b0dcb2a28c3c453ed6eac0e8040364b` (the already-tested
#330 build). Its fixture was attached from checkout `124e190e1a`, which differs
only in review tooling/evidence. The byte comparison independently confirms no
other game differences between that ROM and this feature.

| Check | Result |
| --- | --- |
| Development configuration | builds successfully |
| Release configuration | builds successfully; compile check only, not the delivered build |
| `make validate` | pass, existing review baselines unchanged |
| Full `Testing/run-all.sh` sweep | **50/50 expected**, fresh sentinels for MD5 `2BD2993845547C5F91D6E2BDC0D75F18` |
| Before / after six-pane + four-map captures | **160/160 each** |
| Before / after lifecycle suites | **99/99 each** |
| Prepared save on unmodified development ROM | **12/12** |
| Runtime before/after comparisons | **40/40**, 22 identical views; 18 change exactly 50 glass pixels |
| Decoded lossless recordings | **10/10**, all frames and durations match native source captures |
| Verdict-gate regression checks | two valid runner formats accepted, nine stale/failed cases rejected |
| Palette data/layout audit | two masks, exact three-color ramp, seven layouts + borders, six placements |
| Compiled ROM scope | **77 changed bytes**: 2 mask bytes, 64 alternate-palette bytes, 11 build-stamp bytes |

The tracked sweep includes `JohtoDayNightLive`, `JohtoDayNightWorld`,
`DayNightTint`, all tracked save migrations, and the shipping smoke tests. The
optional private owner-save check is not counted or needed: the synthetic save
is separately tested on the actual delivery ROM.

See [gallery](review/index.html), [comparison manifest](review/manifest.json),
[palette atlas](palette-atlas.png), [layout audit](map-audit.json),
[ROM comparison](rom-byte-diff.json), and [tracked sweep](tracked-sweep.log).
Reproduction commands and scope are in [the feature README](../README.md).

## Timing and return paths

Matched screenshots use 12:00, 20:00, 22:00 and 08:00. Alternate weights are
256, 128, 0 and 128. The full transition time-lapses sample dusk every 15 minutes
and dawn every 30 minutes by changing the save's clock offset. Separately,
each natural-boundary run advances **12,000 emulated frames / 200 seconds**
after setting 19:58:50 or 07:58:50. It checks the overworld callback every frame,
monotonic weights, unchanged player position, and the resulting hardware colors;
there are no clock, counter, callback or palette writes during those waits.
Natural-clock clips play at 50×; normal return clips play at real speed.

Return checks use ordinary Start-menu navigation, Cherrygrove house entry/exit,
a wild battle escaped with Run, New Bark/Route 29 connections in both directions,
and a normal Continue. The disposable fixture only sets up those situations.
No fixture code is included in the delivered ROM. The 12-check delivery run
loads the prepared save and walks the owner's route on that unmodified ROM.

## Exact outputs

- Development ROM SHA-256: `a70354d7a31d6660bb9b25fee8bddaedb2eda66a1bc045bcbd6e599bafd170a0`
- Release ROM SHA-256: `cc5342b6c34550d48ac34473a2c2718cb023dbaa71c2b16465f6e4881bdaee14`
- Prepared save SHA-256: `770a2f52610b359ddfec0b410a86a904accdaab223e247db134af9b9c6b54fa8`
- Local archive: `PokemonWorld-WarmWindows-3bc343d033.zip`; hashes in [delivery metadata](delivery.json).

The local review is served at `http://127.0.0.1:8771/review/`. ROMs and saves are
kept outside Git in `_pwtest/warm-windows-335`. The supplied route takes roughly
five minutes and uses only normal controls. Owner sign-off is visual judgment;
all engineering checks above were run by the agent.

## Limits

This pilot changes the six small glazed door/window panes only. Adjacent windows
using other palettes retain their existing lighting. The original study's
"DNS-immune" shorthand was inaccurate: the high bits select a protected
light-color blend, so the pre-change panes already looked pale cream at night.
The approved alternate ramp makes them more amber without changing that engine
behavior. All three changed source entries and their final runtime values are
documented in the README and checked in emulator memory and hardware palettes.
