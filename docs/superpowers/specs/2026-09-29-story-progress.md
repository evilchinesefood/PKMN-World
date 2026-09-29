# Regional story reminders

Issue #353 is the implementation brief. A returning player must be able to
review Kanto, Johto and Hoenn without travelling or changing campaign state.
The Start menu's Story entry is available immediately in both menu styles.

Use existing regional flags, scene variables, intro bits and badge/Champion
accessors. A pure resolver returns a stable ID plus chapter, established
milestone, next action, destination and prerequisite. Inventory may resolve
an outstanding regional delivery or access prerequisite only with local
scene evidence; it never establishes regional completion. No save changes.

The full-screen 240 x 160 interface has a three-row overview and regional
detail pages: main objective, context, and a clearly marked optional page
only for an authored chain already started. Up/down selects a region;
left/right or L/R changes detail page; B returns to overview and then the
Start menu. Select the active campaign initially, or Kanto for a fresh hub
save with no active campaign. Resolve all regions on open.

Champion status overrides outstanding main-story steps; started optional
chains stay separate. Unknown supported states use conservative actionable
copy. Source tables document the scripts and transition boundaries. The
reminder has no RTC/network/history dependency and no automatic popup.

Verification includes real C resolver boundary tests, cross-region isolation,
retry/overlap cases, production font width checks, emulator navigation/state
and heap checks, boot, migration, make modern/validate/check and the full
overworld sweep. Documentation describes only implemented coverage.
