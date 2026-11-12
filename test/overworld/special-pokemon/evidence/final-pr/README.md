# Final seven-variant PR verification

This supersedes historical ten/eight-variant scope and ordinary-stat descriptions. Active catalog: Classic Cap, Surfboard and Balloon Pikachu; Squad and Firefighter Squirtle; Flower Crown Eevee; Pirate Totodile. All six base stats receive a 15% boost rounded to nearest integer. Final displayed stats still use normal level, IV, EV and nature calculations. Ordinary species and legacy Original Cap are unchanged.

Production ROM SHA-256: `04f8a13fc620117731233d878b1f9d9b165547e49bd082a8086cbbb7fbe98b16`.

- Production `make modern TOOLCHAIN=/opt/devkitpro/devkitARM -j8`: passed.
- Host validation: 23/23 passed.
- Mechanics emulator fixture: 6/6 passed, including actual calculated stats for all seven variants and ordinary/legacy baselines.
- UI emulator fixture: 1326/1326 passed.
- Source interaction fixture: 31/31 passed.
- Capture/recovery fixture: 23/23 passed.
- Art contracts: seven sets, 79 frames and 400 opaque-black ear-tip pixels passed.

Runtime fixtures link test setup into an immutable copy of the production ROM. They are focused automated emulator coverage, not a complete campaign or human playthrough. Latest art rendering was separately checked on the pre-stat wave ROM (see ../pikachu-wave-revision); the stat patch changes no graphics. Owner art approval remains outstanding; this PR is to remain unmerged pending review.

Current animation preview: ../animation-preview/all-seven.gif. Historical review files are retained as superseded evidence.
