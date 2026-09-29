# Story Progress evidence

Native, unretouched 240 × 160 mGBA captures of the production renderer. The
isolated fixture lives in unused ROM padding and is excluded from shipping.
No ROM, ELF or personal save is included here.

The source base is merged PR #354 (`2deb1f92bb31ea89f071e281968f0c842cb023d3`).
The capture manifest records the input ROM/ELF, fixture source/output and each
production source hash, including new files not visible to a tracked diff.
The shipping ROM MD5 is `7C309CFABD61E42099FDEC246C23AED7`; its SHA-256 is
`343960c1b8e4fe8f3bd27d68b3b2d3b4cdc037f6a1dbf4a1d6efe151c29099b0`.

- Host resolver: 627 assertions; all 164 authored objective IDs exercised.
- Production Start menu: 31/31 checks (travel through all regions/hub, active
  defaults, regional isolation, heap restoration, real save/reboot/Continue).
- Renderer/classic fixture: 22/22 checks, including all 820 compiled fields
  measured with the real font, three-line bounds, scrolling/wrapping, repeated
  state purity, Champion status and started optional pages.
- Migrated v7 fixture: 14/14 checks, including immediate Story access, active
  Hoenn default and map/position restoration.
- `make modern` and `make validate`: exit 0. Build memory: EWRAM 235,256 bytes,
  IWRAM 28,216 bytes, ROM 22,977,184 bytes.
- Full engine and overworld regression results will be recorded after completion.

## Captures

| View | Native capture |
|---|---|
| Three-campaign overview | [Overview](StoryProgress_01_overview.png) |
| Main next action | [Kanto chapter/action](StoryProgress_02_kanto_next.png) |
| Destination/prerequisite | [Kanto context](StoryProgress_03_kanto_where.png) |
| Established milestone/progress | [Kanto recap](StoryProgress_04_kanto_recap.png) |
| Another region without travel | [Johto](StoryProgress_05_johto_next.png), [Hoenn](StoryProgress_06_hoenn_next.png) |
| Classic Start caller | [Classic entry](StoryProgress_07_classic_story.png) |
| Champion with unfinished optional chain | [Overview](StoryProgress_08_champion_overview.png), [Main action](StoryProgress_09_champion_next.png) |
| Started optional action | [Optional next](StoryProgress_10_optional_next.png) |
| Optional context/recap | [Optional prerequisite](StoryProgress_11_optional_why.png) |

These are targeted fixtures, not continuous campaign playthroughs. See
[coverage and reproduction](../../../../docs/story-progress/README.md).
