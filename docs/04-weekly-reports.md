# Weekly reports

One short entry per week, written as the week happens.

---

## Week of 2026-09-01 — planning turned into a running app

**Done.**

- Read the revised proposal, the mockup and the design system against each
  other and found twelve points where they were ambiguous or in direct
  conflict — the navigation bar, the missing travel-metadata columns, two
  different category lists, screens the tab bar needs but nobody drew. Each is
  resolved and recorded in [07-build-plan.md](07-build-plan.md) rather than
  decided silently mid-build.
- Ran the Drift spike the proposal promised before feature 1: one table, one
  insert, restart, read it back. Extended it to cover the web setup
  (`sqlite3.wasm` and `drift_worker.js` in `web/`), which is the piece that
  white-screens a deployed build with no error if it is missing.
- Built the design system as code first — tokens, then thirteen components —
  so no screen hardcodes a colour or a size.
- Built every screen: onboarding and local profile, Home in all three states,
  Search and results, the six-screen add flow, the four detail screens, the six
  profile screens, plus the Trips tab and Trip Details that the mockup never
  drew.
- Wired the AI layer: one `AiExtractor` interface, a Gemini implementation and a
  deterministic sample one, chosen at startup by whether `.env` has a key.
- 24 tests: the data layer including foreign-key enforcement, the extractor, and
  widget tests for the main flows.

**Problems, and what fixed them.**

- *Foreign keys were silently missing.* `references(Trips, #id)` generated no
  `REFERENCES` clause. Switched to explicit `customConstraint` and turned on
  `PRAGMA foreign_keys`, then wrote a test that asserts a post cannot point at a
  trip that does not exist. That relationship is the reason Drift was chosen
  over Hive, so it needed to be real rather than assumed.
- *Recent searches came back in the wrong order.* Two searches in the same
  millisecond tie on the timestamp, and SQLite broke the tie by row id — putting
  the older one first. Added the id as an explicit second sort key.
- *Search was a dead end.* It had been built as a pushed route with no back
  button. The mockup calls those frames "Home: Search" and draws the tab bar on
  them, so it moved inside the Home tab where it belongs.
- *Two layout overflows* that the browser hid and the tests caught: a chip whose
  label could exceed a narrow card, and two rows of non-flexible text.
- *The deployed build white-screened locally* because Flutter loads CanvasKit
  from a CDN by default. A custom `web/flutter_bootstrap.js` points it at the
  copy already in the build, which also removes a third-party dependency from
  the deploy.

**Next.**

- Test extraction against 10 real travel links per platform and log how often a
  usable destination comes back. This is the mitigation the proposal committed
  to for its biggest risk, and it needs real numbers.
- Record the demo video, showing real Gemini extraction locally.

---

## Week of 2026-09-08 — review pass: the map, thumbnails, and three bugs

Reviewed the built app against the mockup. Six items; the useful part was that
three of them were bugs rather than missing work.

**Bugs found.**

- *The onboarding screens could never be seen.* LA1-LA6 and LO1 were built in
  week one, but the seed inserted a named user row and the launch gate treated
  any user row as "already set up" — so every install went straight to Home. The
  seeded row is nameless now and exists only so trips have an owner. Fixing that
  exposed a second one: onboarding screens are pushed routes, so swapping the
  home route left them on top; saving a profile clears the stack.
- *The note field did not render.* `NookNoteField` had an `Expanded` inside a
  Column with unbounded height, so it collapsed to zero and Create Note showed
  only a title box — a note could not be typed at all.
- *Travel Details values were not flush right.* A loose `Flexible` label and an
  `Expanded` value split the free space equally, so the value box was half the
  row and short labels left their value floating in the middle. Long labels
  happened to look correct, which is why it read as a spacing quirk rather than
  a layout bug.

**Built.**

- `flutter_map` with OpenStreetMap tiles and a pin per saved location — the
  stretch goal, and cheaper than expected because the extraction call now
  returns coordinates alongside the destination.
- Thumbnails: derived from the video id for YouTube, oEmbed for TikTok. Instagram
  and Facebook are not possible without a Meta app, so those keep the
  placeholder — worth saying plainly rather than leaving it looking broken.
- Chips moved off a `Wrap` and onto one line beside the creator, as drawn.
- Detection now says which extractor is running, in Settings and on Paste Link.

**Next.**

- The 40-link extraction test, still outstanding.
- Confirm the map tiles render outside the sandbox this was built in, which
  blocks the tile host.
- Record the demo video.
