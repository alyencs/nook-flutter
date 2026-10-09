# Weekly reports

The development history of Nook, week by week, from the repository being created
to the final documentation pass.

**How this was reconstructed.** Every week below is anchored to commits in this
repository: their dates, their diffs and their messages. Where a claim comes
from somewhere else — a planning document, a piece of work that happened before
the first commit — it says so. Weeks are Monday to Sunday. One week has no
commits in it and is written up as exactly that rather than filled in.

This is a **historical record**, not a description of the app as it stands
today. Several things below were built, shipped and then replaced: Inter as the
typeface, email in onboarding, a destructive delete, CARTO map tiles, the
`google_generative_ai` package, a pinned `gemini-2.0-flash`. They are kept
because they happened. For what Nook is now, read the
[README](../README.md).

| Week | Dates | Headline | Commits |
| --- | --- | --- | --- |
| [1](#week-1) | 24–30 Aug 2026 | Repository from the course template | 1 |
| [2](#week-2) | 31 Aug – 6 Sep 2026 | Planning reconciled, then the whole app built | 2 |
| [3](#week-3) | 7–13 Sep 2026 | Review pass, and the extraction pipeline rebuilt twice | 9 |
| [4](#week-4) | 14–20 Sep 2026 | No commits | 0 |
| [5](#week-5) | 21–27 Sep 2026 | Editorial redesign, Recently Deleted, animations, documentation | 9 |
| [6](#week-6) | 28 Sep – 4 Oct 2026 | The real logo, slower motion, a deterministic extractor | — |

---

<a id="week-1"></a>

## Week 1 — the repository exists

**Dates.** Monday 24 – Sunday 30 August 2026. One commit, `fee2a36`, on Friday
28 August.

**Before this week.** The proposal was written and revised through the course's
own submissions — `docs/01-proposal.md` records it as "submitted (m6a1, revised
in m7a1)" — along with the mockup and the design system. None of that work is
dated inside this repository, so it is noted here as context rather than
assigned to a week it cannot be proved to belong to.

**Objectives.**

- Get a repository in place that can hold every deliverable, so the project is
  one link rather than a pile of attachments.
- Have a deploy path before there is anything to deploy.

**Done.**

- Repository created from the course template: `README.md`, `docs/01` through
  `docs/06` as placeholders (18–42 lines each), `docs/README.md`, `LICENSE`,
  `analysis_options.yaml`, a starter `lib/main.dart`, `web/index.html` and
  `web/manifest.json`.
- `.github/workflows/deploy-web.yml`: build on push to `main`, publish to GitHub
  Pages, skip quietly when there is no `pubspec.yaml` yet.
- `.gitignore` written **before** any secret existed — `.env`, `.env.*`,
  `!.env.example`, keystores, service-account JSON. That ordering is the reason
  no key has ever been committed to this repository, and it is checkable:
  `git log --all -- .env` is empty.

**Technical changes.** Scaffolding only; 926 lines, no application code beyond
the template's `main.dart`.

**Milestone.** A public repository that deploys, with the secret hygiene decided
up front rather than retrofitted.

**Next.** Reconcile the three planning documents and start building.

---

<a id="week-2"></a>

## Week 2 — planning turned into a running app

**Dates.** Monday 31 August – Sunday 6 September 2026. Two commits, both on
Sunday 6 September: `572c3ff` (the build plan) and `0e9f22b` (the app).

**Objectives.**

- Read the proposal, the mockup and the design system against each other and
  settle every place they disagreed, in writing, before building anything.
- Build the MVP: all five core features, every screen, on-device storage.

**Done.**

- **Reconciled the three source documents** and found twelve points where they
  were ambiguous or in direct conflict — the navigation bar's colour, the
  missing travel-metadata columns, two different category lists (6 on Search, 7
  on Add), screens the tab bar needs but nobody drew. Each was resolved with a
  recorded decision rather than settled silently mid-build.
- **Ran the Drift spike the proposal promised** before feature 1: one table, one
  insert, restart, read it back. Extended it to cover the web setup —
  `sqlite3.wasm` and `drift_worker.js` in `web/` — which is the piece that
  white-screens a deployed build with no error if it is missing.
- **Built the design system as code first**: tokens for colour, spacing, radius
  and type, then thirteen components, so no screen hardcodes a value.
- **Built every screen**: onboarding and local profile, Home in all three
  states, Search and results, the six-screen add flow, the four detail screens,
  the six profile screens, plus the Trips tab and Trip Details that the mockup
  never drew.
- **Wired the AI layer**: one `AiExtractor` interface, a Gemini implementation
  and a deterministic sample one, chosen at startup by whether `.env` has a key.
- Filled in `docs/01` through `docs/06` with the real planning documents and
  removed the template's `START-HERE.md`.

**Technical changes.**

- Drift schema version 1, **four tables**: `users`, `trips`, `saved_posts`,
  `recent_searches`. (`app_settings` arrives in week 3, which is where the count
  becomes five.)
- Foreign keys written as explicit `customConstraint` SQL with
  `PRAGMA foreign_keys = ON`.
- `trips.item_count` computed rather than stored.
- State is `setState` plus Drift streams through `StreamBuilder` — no
  state-management package.
- Inter bundled as a local asset; a custom `web/flutter_bootstrap.js` loads
  CanvasKit from the app's own folder instead of Google's CDN.
- 28 tests.

**Challenges, and what fixed them.**

- *Foreign keys were silently missing.* `references(Trips, #id)` generated no
  `REFERENCES` clause. Switched to explicit SQL and turned the pragma on, then
  wrote a test asserting a post cannot point at a trip that does not exist. That
  relationship is the reason Drift was chosen over Hive, so it had to be real
  rather than assumed.
- *Recent searches came back in the wrong order.* Two searches in the same
  millisecond tie on the timestamp, and SQLite broke the tie by row id — putting
  the older one first. Added the id as an explicit second sort key.
- *Search was a dead end.* Built as a pushed route with no back button. The
  mockup calls those frames "Home: Search" and draws the tab bar on them, so it
  moved inside the Home tab where it belongs.
- *Two layout overflows* the browser hid and the tests caught: a chip whose
  label could exceed a narrow card, and two rows of non-flexible text.
- *The deployed build white-screened locally* because Flutter loads CanvasKit
  from a CDN by default. The custom bootstrap fixed it and removed a
  third-party dependency from the deploy at the same time.

**Milestone.** Every MVP feature working, deployed, with the Gemini key
deliberately outside the build.

**Next.** Review the built app against the mockup.

---

<a id="week-3"></a>

## Week 3 — the review pass, and the extraction pipeline rebuilt twice

**Dates.** Monday 7 – Sunday 13 September 2026. Nine commits, all on Monday 7
and Tuesday 8 September: `88c1224`, `748ed64`, `b0cb50f`, `3393a3e`, `2f964ac`,
`5a0dc72`, `954fe18`, `0e6e49f`, `d5f318b`.

This was the heaviest week of the project. It started as a review pass and
turned into three separate root-cause investigations, two of which ended with a
piece of the extraction pipeline being replaced.

**Objectives.**

- Review the built app against the mockup and close the gaps.
- Find out why extraction was returning 503s and vague destinations.

**Done — the review pass (`88c1224`).** Six items; the useful part was that
three of them were bugs rather than missing work.

- *The onboarding screens could never be seen.* LA1–LA6 and LO1 were built in
  week 2, but the seed inserted a **named** user row and the launch gate treated
  any user row as "already set up" — so every install went straight to Home. The
  seeded row is nameless now and exists only so trips have an owner. Fixing that
  exposed a second bug: onboarding screens are pushed routes, so swapping the
  home route left them on top; saving a profile clears the stack.
- *The note field did not render.* `NookNoteField` had an `Expanded` inside a
  Column with unbounded height, so it collapsed to zero and Create Note showed
  only a title box — a note could not be typed at all. Sized by `minLines` now.
- *Travel Details values were not flush right.* A loose `Flexible` label beside
  an `Expanded` value split the free space equally, so the value box was half the
  row. Long labels happened to look correct, which is why it read as a spacing
  quirk rather than a layout bug.
- Built: `flutter_map` with OpenStreetMap tiles and a pin per located post —
  the stretch goal, cheaper than expected because the extraction call now
  returns coordinates. Thumbnails derived from the video id for YouTube and
  oEmbed for TikTok; Instagram and Facebook keep the placeholder, which is worth
  saying plainly rather than leaving it looking broken.
- Detection now reports which extractor is running, in Settings and on Paste
  Link.

**Done — the save-flow assertion and the profile screens (`b0cb50f`).**

- Four places read `ScaffoldMessenger.of(context)` *after* popping the route,
  registering an inherited dependency from an element being deactivated. All
  four now capture `ScaffoldMessenger.of` and `Navigator.of` before any `await`.
  Writing the regression test surfaced two more faults: a SnackBar raised in the
  same frame as a pop is parented by both Scaffolds and trips the
  duplicate-hero-tag assertion, and the four platform badges on Paste Link
  overflowed their Row.
- **Typography came down about 10%** (Display 32→28, Heading 24→22, Title 20→18,
  Body 16→15, Overline 12→11) and every ad-hoc `copyWith(fontSize:)` was
  removed. A dozen screens had drifted from the scale independently.
- `platform_badge.dart` became the single source of platform branding, using
  Font Awesome brand marks rendered with `FaIcon`.
- Settings, About Nook and Help & Support rebuilt to the supplied screenshots,
  with four real persisted switches and Export Data writing JSON.

**Done — the migration and the stall (`5a0dc72`).**

- *Export Data failed with "no such table: app_settings".* `app_settings` and
  the two coordinate columns had been added to the schema without bumping
  `schemaVersion`, so drift only ever created them on a fresh install. **Schema
  version 2** with a real `onUpgrade` that checks `sqlite_master` and
  `PRAGMA table_info` before each step — because "version 1" describes two
  different shapes on disk. The same root cause made all four Settings switches
  snap back: the write threw and was lost.
- *Link analysis had three separate stalls*: no timeout on `generateContent`, a
  6s thumbnail lookup running in series after it, and `gemini-2.5-flash`'s
  thinking phase, which the SDK could not switch off. Fixed with a 30s timeout,
  the thumbnail resolved in parallel at 2.5s, and a move to
  `gemini-2.0-flash`. 1.8s end to end, measured.
- `test/migration_test.dart` builds a genuine v1 database with raw `sqlite3`;
  `test/layout_test.dart` draws all 22 screens at exactly 390×844, where a
  `RenderFlex` overflow throws. 71 tests.

**Done — the 503s, root-caused (`954fe18`).** Three faults at once:

- *The model was gone.* `gemini-2.0-flash` — pinned the same day — had been shut
  down by Google on 1 June 2026. Swapping in another id would only move the
  outage, so **no default model id is compiled in any more**: the app asks
  `GET /v1beta/models` what the key can reach and ranks the answers.
- *There was no retry.* One call, and any failure was permanent, so every Retry
  tap was one more immediate request. Now four attempts with exponential backoff
  and equal jitter, 20s per call, 45s overall, honouring `Retry-After`.
- *The SDK hid the status code.* `google_generative_ai` raises 5xx as
  `'Server Error [$statusCode]: $body'` — the status survives only inside a
  string, which is what the user was shown — and does not take that branch for
  429 at all. **The package was dropped** for a direct REST call over `http`,
  which keeps the status, `error.status`, `details[].reason` and `Retry-After`.
- 37 new tests script a server through every failure. 108 tests.

**Done — `_dependents.isEmpty`, and the blind spot (`0e6e49f`).**

- The assertion lives in `InheritedElement.debugDeactivated` and **only exists in
  debug builds**. Every browser check so far had run a release build, and every
  widget test hosted screens under a bare `MaterialApp` while `main()` wraps the
  app in `DevicePreview`. Adding `DevicePreview` to a test is not enough either —
  its store loads from `shared_preferences`, which has no binding under
  `flutter test`, so it silently renders the bare branch.
- `AppScope` was built **inside** `DevicePreview.builder`, which runs again on
  every preview rebuild — four times before the first frame settles — so each
  call produced a new `GeminiExtractor`, discarding the in-flight request map and
  the resolved-model cache. `AppScope` now sits above `DevicePreview` and the
  extractor is created once in `main()`.
- The extraction-error card overflowed by 54 pixels; both buttons put an
  unconstrained `Text` in a fixed-width Row.
- The Flutter version was checked and ruled out rather than blamed. 123 tests.

**Done — giving the model something to read (`d5f318b`).**

- Pasting an Osaka video gave "Japan" and saved the post as `Sf9ihvL0Usk`. One
  cause: the extractor sent the model a **bare URL**, so it had eleven characters
  of video id to work from. A better model would not have helped, because the
  information was never in the request.
- `lib/ai/source_metadata.dart` reads the post first, per platform: keyless
  oEmbed for YouTube and TikTok; Instagram and Facebook reach the model as a URL
  plus what the path says, and the prompt tells it so.
- **Schema version 3** adds nine columns: the location steps from `place_name`
  through address, neighbourhood, city and region to country, alongside
  `caption`, `creator_handle` and `source_id`.
- Coordinates are dropped unless something specific was found — a model asked
  for the coordinates of "Japan" returns the centre of Japan, which is a true
  fact and a false claim about the post.
- The black bars turned out to be in the image file: `hqdefault.jpg` is 480×360
  with a letterboxed 16:9 frame painted into it, which no `BoxFit` can crop.
  Thumbnails moved to `mqdefault.jpg`. 153 tests.

**Milestone.** Extraction that reads the post instead of guessing from a URL,
on a retry path that reports the truth.

**Next.** The 40-link extraction test, and the demo video.

---

<a id="week-4"></a>

## Week 4 — no commits

**Dates.** Monday 14 – Sunday 20 September 2026.

**What the repository records.** Nothing. There is no commit in this range on
any branch, and no document carries a date inside it. Whatever happened that
week — coursework elsewhere, reading, a pause — left no evidence here, so
nothing is claimed for it.

The gap is visible in the history as a seventeen-day jump from `d5f318b`
(8 September) to `081ce7d` (25 September), and it is left in the record rather
than smoothed over.

---

<a id="week-5"></a>

## Week 5 — the editorial redesign, Recently Deleted, and the animations

**Dates.** Monday 21 – Sunday 27 September 2026. Nine commits: `081ce7d`,
`6067a0e`, `3ee4606`, `148abb4`, `992f2b3` on Friday 25 September; `c68a89f`,
`ec783d7`, `72fe45a`, `4d8b587` on Sunday 27 September.

**Objectives.**

- Take the app from "every screen exists" to a considered visual identity.
- Make deleting safe.
- Treat all four platforms as themselves rather than as YouTube plus three
  afterthoughts.
- Fix the extraction failures properly, having already been wrong about them
  once.

**Done — the editorial redesign (`081ce7d`).**

- **Manrope replaces Inter** for everything functional. The editorial face is an
  accent and is deliberately rationed — one emphasised phrase inside an otherwise
  plain line, four in the whole app, expressed as a property of the copy
  (`NookHeadline('Never lose your *next favourite find*')`).
- **PP Editorial New cannot be committed**: it is licensed from Pangram Pangram,
  free for personal use only. **Instrument Serif** (SIL OFL) ships in that role,
  and every editorial style resolves through one family constant, so swapping in
  the licensed face later is two edits.
- Three line shapes — a hairline, a section mark whose rule runs to the margin,
  and a label joined to its value by a leader line. Two layout traps came with
  them and `layout_test.dart` caught both.
- **Onboarding is personalisation, not registration.** Email and the account
  framing are gone — Nook stores everything on the device and talks to no server,
  so there was never an account for an address to identify. **Schema version 4**
  relaxes `users.email` through a table rebuild, since SQLite cannot drop a
  `NOT NULL` constraint in place.
- **`YOUTUBE_API_KEY` added** — the first new secret since the project began.
  oEmbed has no description field, and the description is where the detail lives:
  the difference between "Kyoto" and five named cafes. `ai_places` and
  `ai_highlights` hold what comes back.
- `NookToast` replaces SnackBars, which sat over the primary button and the tab
  bar.
- **Share to Nook** as a Web Share Target — the mechanism that works for a web
  deployment. It is only a source of URLs; everything after it is the code Paste
  Link already runs.
- Map: drag, pinch and wheel zoom, rotation off, and CARTO Positron tiles for
  Latin-script labels. 166 tests.

**Done — animations, first attempt (`6067a0e`, `3ee4606`).**

- The animation code landed but did not compile, and three of the four breakages
  came from the guide rather than the edits made against it: a code block that
  was never valid Dart, an illustrative class name that did not exist, and an
  `Expanded` applied at a call site inside a `SingleChildScrollView` where its
  variable was out of scope.
- A leak repeated in four places: `CurvedAnimation` registers a status listener
  on its parent **in its constructor**, so one built per frame leaks one listener
  per frame. Hoisted to fields and disposed.
- `Entrance` held its stagger in an uncancelled `Future.delayed`; a widget
  disposed mid-stagger left a pending timer. It is a cancelled `Timer` now.
- Review & Save set `_saving` only after an awaited settings read, so a fast
  double-tap could write two rows. 183 tests.

**Done — making the map show a map (`148abb4`).** Three faults, one symptom
each:

- *Grey tiles.* CARTO had gated `basemaps.cartocdn.com` behind an API key and
  now stamps "API KEY REQUIRED" across every tile — served as a normal **200**,
  so `fallbackUrl`, which only fires on an error, never fired. Moved to
  `tile.openstreetmap.org`: keyless, CORS-enabled. The trade is real and worth
  stating — OSM's standard style labels places in local script, so Kyoto reads
  京都.
- *Dead gestures.* Not a flag. `FlutterMap` always registers a
  `ScaleGestureRecognizer` and makes it captain of its arena team **whatever**
  `InteractiveFlag`s are set, and a one-finger drag is a one-pointer scale — so
  the map claimed every drag starting on it and the Travel Details page could not
  scroll. Turning flags off cannot fix a recognizer that is not behind a flag;
  not receiving the pointer can. The preview is `IgnorePointer` with a tap target
  above it, and a tap opens a full-screen map where everything works.
- "Open in Maps" hands the coordinates to whatever map app the device has:
  `geo:` on Android, `maps:` on iOS, an OpenStreetMap URL on the web. 197 tests.

**Done — Recently Deleted and four real platforms (`992f2b3`).**

- **Deleting is no longer destructive.** Posts and trips carry `deleted_at`
  (**schema version 5**), every screen-facing query filters on it, and Recently
  Deleted under Profile restores or destroys them. Nothing is copied at any
  point, so nothing can be duplicated. Items age out after 30 days, purged when
  the screen opens, and the screen says so.
- The trip confirmation now states the thing that was always true but never
  written down: the posts inside are not deleted. The post confirmation stopped
  claiming the delete cannot be undone, because it can.
- **`FACEBOOK_TOKEN` added** — the second new secret. Instagram and Facebook
  withdrew public oEmbed in October 2020; both now go through the Graph API
  behind that token, and without one they extract from the URL alone and the
  prompt says so in those words.
- *The 503s, again.* The extractor only moved to another model when one was
  *gone*; an overloaded one was retried and then reported. A 503 is that model's
  capacity and another model is another pool, so a persistent overload now falls
  back — deliberately narrower than "transient", since a 429 is the key's quota.
- **The screen is told a phase, not a sentence.** It used to receive "Asking
  gemini-flash-latest" and "Gemini is busy — retrying in 4s (attempt 2 of 4)": a
  vendor, a model id and a retry schedule, in front of someone who pasted a link.
  `ExtractionPhase` has three values and the screen chooses the words, and a test
  asserts none of them can leak a vendor name, a model id or a status code again.
- Deleting a post flies its card to the Profile tab, where Recently Deleted
  lives, so the animation answers "where did it go". 238 tests.

**Done — the real cause of the extraction failures (`c68a89f`).**

- **It was not Gemini being busy.** Gemini 2.5 models think before they answer
  and thinking is **on by default**; nothing in the request asked them to stop.
  Every extraction spent seconds and thousands of invisible tokens reasoning
  about a JSON shape it had already been handed, routinely exceeded the 20s
  attempt timeout, and was then retried four times. **The 503s and quota errors
  were largely load the app was generating itself.** `generationConfig` now
  carries `thinkingBudget: 0` and a 2048-token ceiling, with a detected-and-
  remembered fallback for models that predate the field.
- *Maps.* The pin was landing on a city centroid while the label named a
  mountain. Two causes: the seeded library gave "5 Hidden Cafes in Kyoto" the
  Kyoto city coordinate and no place name at all, and the prompt asked only for
  somewhere "specific enough to have a single point" without saying which of the
  places it had just named.
- *Typography.* `ThemeData` still declared `'Inter'` as the default family long
  after Inter stopped being bundled, so every widget that did not reach for
  `NookType` explicitly fell back to the platform font — the app had quietly been
  running two typefaces since the redesign.
- Onboarding became an editorial spread; trip folders gained five pastel colours
  (**schema version 6**); Recently Deleted stopped saying its own name twice.
  254 tests.

**Done — the animations, properly (`ec783d7`, `72fe45a`, `4d8b587`).**

- The guide was rewritten as an applicable patch and validated by applying it
  end to end to a working copy, which caught a `BuildContext` used across an
  `await` and a deprecated `Matrix4.translate`.
- The integration commit did not compile: a second `_controller` written over a
  `CurvedAnimation` field, and a duplicated delete tail that closed a class
  early.
- Four behavioural defects behind that: a post-frame callback tore the folder
  spring out of the tree before any of its 340ms ran; a `GlobalKey` held in a
  `StatelessWidget` field rebuilt a row on every stream tick; the delete write
  ran after the flight, so the post sat in the list with a copy of itself flying
  overhead; and two fast taps ran the whole delete flow twice.
- Then the part a clean analyzer cannot show. Driven in Chromium and recorded
  frame by frame, **three of the four animations were running and saying
  nothing**: the delete flight spent most of its journey as a ~30×17 pale card on
  a cream background, the folder lid moved a 72pt card's top edge about two
  pixels, and the tab pulse expanded to 96pt across a 68pt bar while fading
  linearly. All three were rebuilt against the recordings. The logo also spelled
  NVVK. 275 tests.

**Done — the documentation pass (27 September).**

- `SECURITY-CHECKLIST.md` created: every item checked against the code, with
  seven open items recorded rather than smoothed over — including a wipe that
  leaves `app_settings` behind and an export that is a subset of the database.
- `docs/06-security-and-privacy.md` re-checked against the current build; it
  predated both new secrets, the current schema and the whole of Recently
  Deleted.
- These weekly reports reconstructed from the commit history.
- README corrected: the storage row, the run instructions, and a typeface the
  repository does not ship.
- `07-build-plan.md`, `09-share-to-nook.md` and `10-animations.md` removed as
  working documents whose job is finished, with every reference to them updated.
- The six screenshots in `docs/assets/` replaced. They dated from 6 September
  and showed the app before the editorial redesign — the old type, no folder
  colours, no editorial accents — so every one of them contradicted the README
  they illustrated. Recaptured from the current build at the same 390×844 on a
  3× screen.

**Milestone.** Feature-complete against the proposal, with deletion reversible,
all four platforms handled as themselves, the extraction cost problem solved at
its cause, and the documentation matching the code.

**Still outstanding.**

- **The 40-link extraction test.** Ten real travel links per platform, logging
  how often a usable destination comes back. This is the mitigation the proposal
  committed to for its biggest risk, it has been carried since week 2, and it
  needs a normal network and a Gemini key.
- **The demo video**, showing real Gemini extraction locally.
- **Confirming the live third-party calls** — every tile, image and API host is
  blocked in the environment this was built in, so all five integrations are
  verified against documented payloads rather than against the services
  themselves.

---

<a id="week-6"></a>

## Week 6 — the real logo, slower motion, and an extractor that answers the same way twice

**Dates.** Monday 28 September – Sunday 4 October 2026.

**Objectives.**

- Replace the splash mark with the actual Nook logo, having realised the one on
  screen was invented.
- Make the three animations that carry meaning slow enough to read.
- Find out why the same link extracts well one minute and thinly the next.
- Close the two audit items left open last week.

**Done — the logo was never Nook's.**

The splash assembled four charcoal squares with a letter set in Manrope in each.
That was wrong in a way the earlier "fix" had not touched: **Nook's mark is not
type at all.** It is four tiles with the letterforms cut out of them as counters,
and the two O tiles read as a check rather than a round O — which is almost
certainly why an AI looking at the brief guessed `V` and produced a mark that
spelled **NVVK**. Changing the Vs to Os in week 5 corrected the spelling of a
logo that still did not exist.

The mark now ships as four transparent tiles cut from `nook_logo.png` along its
own gutters, at its own resolution. That the crops are faithful is checked rather
than claimed: composited back together and differenced against the original, no
pixel differs. Nothing redraws, re-traces or re-spaces anything.

Only `N.svg` and two identical copies of `O.svg` were supplied — there is no
`K.svg` — which is why all four quarters come from the PNG rather than three from
vectors and one from somewhere else.

**Done — motion that can be followed.**

Three animations were running and saying very little, so the timings moved and
the curve under the long ones changed:

| | Was | Now |
| --- | --- | --- |
| Logo assembly | 1500ms, pieces 90ms apart | 2400ms, pieces ~260ms apart |
| Delete and restore flight | 900ms on `easeOutCubic` | 1400ms on a new `travel` curve (`easeInOutCubic`) |
| Tab pulse | 520ms | 700ms |
| Folder lid | 340ms | 420ms |

The curve mattered more than the duration. An ease-out spends two thirds of the
distance in the first third of the time, which is what made a 900ms flight feel
like a 300ms one; a curve that holds its middle is what makes the middle
watchable. Restore also gained the same ring at the tab that delete lands into —
there the bar catches something, here it lets it go.

All four beats of a delete are now separately visible, confirmed by recording the
real build frame by frame: the list settling, the card crossing, the tab
answering, the confirmation.

**Done — the extractor stopped giving different answers to the same question.**

Two causes, both ours:

- **Sampling was still live.** `temperature` was 0.2 — low, but enough for the
  model to decide differently about an optional array between two identical
  calls, which is exactly where the missing cafes were going. It is 0 now, with
  a fixed `seed` and an explicit `candidateCount`.
- **The reply was being cut off.** `maxOutputTokens` was 2048. A post naming five
  venues with an address and a note each runs past that, and a reply cut off at
  the ceiling is truncated JSON — so it failed the parse and was reported as
  "couldn't be read", which pointed at the model rather than at the ceiling.
  Worse, `MAX_TOKENS` was explicitly waved through alongside `STOP`, so the real
  cause was hidden. The ceiling is 8192 and truncation now says what it is.

**Done — three smaller things the pipeline was missing.**

- **The summary is pinned to English.** The source may be in any language and
  should be read in it; the summary is Nook's own sentence in an English
  interface, so it is always English. Names stay as they are — 錦市場 is not
  translated into "Nishiki Market".
- **The creator's profile picture** is extracted where it legitimately exists,
  which is YouTube and only YouTube, and only with a Data API key. Schema 7 adds
  `creator_url` and `creator_avatar_url`; everywhere else the UI draws the
  creator's initial rather than inventing a face.
- **The onboarding photographs were never broken.** They were failing CORS: a
  plain `Image.network` has CanvasKit fetch the bytes over HTTP, and the Commons
  `Special:FilePath` redirect carries no CORS header, so every one fell through
  to the error builder and left a flat block of tint. `PostThumbnail` had already
  solved this; onboarding now renders through the same `<img>` path.

**Done — the two audit items, decided rather than deferred.**

Both were left last week as "the author's call", and both got the same answer —
fix the behaviour, do not soften the sentence:

- `clearAll()` clears `app_settings` too, so "this erases everything on this
  device" is true and a device handed on comes back at defaults.
- Export Data writes every column. Fifteen were missing while its own comment
  claimed it wrote everything.

**Done — the profile photo can be positioned.**

Every avatar drew the picked image with `BoxFit.cover` — a centre crop decided by
the middle of the file rather than by the person in it. There is a crop sheet
now: drag to move, pinch or scroll to zoom, inside a round window. The crop is
baked into the stored image rather than kept as an offset beside it, so
`users.profilePicture` stays the single source of truth and Profile, Account and
anything added later cannot disagree about it. No new dependency — a
`GestureDetector`, a `Transform`, and `dart:ui` drawing one rectangle into
another.

**Challenges.**

- *No `K.svg`.* Resolved by taking all four quarters from the supplied PNG, which
  is also the only way to guarantee they match each other.
- *Every image host is blocked in the build environment.* Wikimedia Commons and
  OpenStreetMap both refuse at the proxy, so the onboarding CORS fix and the
  seeded photographs are verified by reading the failure, not by watching them
  load. That needs confirming on a normal network.
- *No Gemini key in the container.* The determinism and language changes are
  asserted against a scripted HTTP client at the network boundary rather than
  against the real API.

**Milestone.** The app ships Nook's own mark, motion that communicates, an
extractor that answers the same question the same way, and documentation with no
knowingly open contradictions.

**Next.** The 40-link extraction test, on a real network with a real key. The
demo video. Confirming the photographs load where the hosts are reachable.

## Week 7 — Explore Itinerary, a new AI provider, and a tap that stopped registering

**Done — Explore Itinerary is built.**

The itinerary generator had been drawn, disabled and labelled a stretch goal
since the proposal. It is a feature now, and the shape it took is narrower than
the proposal imagined: it plans from the posts already saved into a trip rather
than from a destination typed into a box. That is the version worth having —
the material is already there, it is the traveller's own, and a planner that
ignores it would be a second app bolted on rather than Nook doing more with what
it holds.

Three screens: a trip picker, a plan screen with the source posts listed above a
row of duration chips, and the result. The duration is one to seven days and the
generator is held to it — more days than asked for are trimmed, fewer is
reported rather than padded out with a day nobody planned. A trip with nothing
in it, or one whose posts are only titles, is refused before a call is made.

`SampleItineraryGenerator` is the keyless half, and it is not a stub: it takes
the places, tips and notes out of the saved posts, orders them and spreads them
across the days. The deployed build runs it, and the screen says so.

**Done — the AI provider moved to Claude Haiku 4.5.**

`lib/ai/` kept its shape. `AiExtractor` and `ItineraryGenerator` did not change,
the prompts did not change, and the itinerary models did not change. What
changed is the three files underneath: a Messages API client in place of the
Gemini one, and the two implementations rewritten against it.

The one substantive difference is how structure is asked for. Gemini had
`responseSchema`; the replacement is a tool the model is forced to call, with a
JSON Schema for its arguments. The reply then arrives as a decoded object rather
than as text that has to be found inside prose and parsed — strictly better than
what it replaced. Model discovery went with it: a dated model id is pinned,
with the rolling alias behind it as a fallback, which is two fewer requests per
session and one less thing to go stale.

`GEMINI_API_KEY` and `GEMINI_MODEL` became `ANTHROPIC_API_KEY` and
`CLAUDE_MODEL`. The security position is unchanged and so is its limit: the key
is still read from a git-ignored `.env`, still bundled as an asset in any build
made with one, and still absent from the deployed build.

**Done — taps stopped being swallowed.**

A tap on a trip folder would sometimes do nothing, and the number of taps that
worked before one went missing varied between one and three. `FolderOpen` held
its re-entrancy guard in a library-level variable rather than in its State, so
one folder part-way through its lid animation silenced every folder on every
screen for the length of that animation. Worse, the guard was released only when
an awaited `TickerFuture` completed — and a ticker is muted, not cancelled, when
its screen sits under another route, so a lid frozen that way never released it
at all.

The flag is per-instance now, and the wait is a `Timer` rather than a ticker
future, so it lands whether or not the screen is on top. A tap that is stale by
the time it fires — because another screen arrived first — closes the folder
instead of pushing a route over wherever the user now is.

**Challenges.**

- *Reproducing the tap bug took a measurement, not a reading.* It looked like a
  gesture problem and was not. Tapping two folders at a fixed interval and
  counting how many callbacks fired put the dead window at 420ms and made the
  cause obvious.
- *The screenshots were out of date.* Onboarding and the seeded posts have real
  photographs now; the README still showed the versions without them. Recaptured
  from the current build with the phone frame off.

**Done — the live link became usable.**

GitHub Pages had never been switched on, so every deploy run built the app and
then failed at `actions/deploy-pages` with a 404. Turning it on (Settings >
Pages > Source: GitHub Actions) was the whole of that fix — no file changed.

What the live link then showed was a second problem. The deployed build shipped
`device_preview`, a development tool, wrapped around the whole app. It draws a
dev toolbar pinned to the bottom of the window, and on a window narrower than
700pt — every phone — that toolbar is the first thing a thumb finds. Opening it
puts a sheet over the app and a full-screen `Navigator` in front of it, and
every setting it offers, the simulated on-screen keyboard included, is written
to `localStorage`, so a state that hides the app's buttons is restored on the
next load rather than cleared by one. There is no console on a live link; it
just looks like an app that does not respond.

It is gone, replaced by `DemoFrame` — a `Center`, a `SizedBox` and a border,
about forty lines, no overlay and no second `Navigator`. It holds the app at
phone proportions on a wide window and stands aside on a narrow one, which is
all the dev tool was wanted for. `demo_frame_test.dart` asserts the part that
matters: that five taps in a row all reach the button, at three window sizes.

One more thing had to be dealt with before any of that could reach a browser.
The builds up to this point registered Flutter's generated service worker, and
a service worker answers navigations from its own cache first. Anyone who had
opened the live link while one of those builds was up still had that worker,
so every later deploy succeeded and they kept being handed the bundle it had
cached — the files on the server changed and the page did not. Removing the
registration from the bootstrap does nothing about it, because a worker
already in a browser does not consult the page, and clearing site data does
not reliably unregister one that is controlling an open tab.

Only a worker can replace a worker, so the deploy writes one:
`web/retire_service_worker.js` is copied over `flutter_service_worker.js`
after the build, and it claims the open clients, empties Cache Storage,
unregisters itself and reloads the tab. The browser re-checks that script URL
on its own, which is what makes this work without the visitor doing anything.
The deploy also writes `build.txt`, so which commit is live can be read off
`<username>.github.io/<repo>/build.txt` rather than guessed — Pages keeps
serving the previous build when a run fails to deploy, and from the browser
the two are indistinguishable.

Two deployment details went with it. `cp .env.example .env` ran *after*
`flutter analyze` and `flutter test` in the workflow, so both stopped at "No
file or variants found for asset: .env" on every run and never reached a line
of Dart — green-looking checks over a build they had not read. It runs before
them now. And the service worker was registered but bought nothing: Nook's
database is already on the device, so all it did was serve the previous deploy
to anyone who had opened the link before. The bootstrap unregisters it and
clears its caches instead.

**Next.** The 40-link extraction test, still outstanding, on a real network with
a real key. Five tests in `dao_test.dart` and `widget_test.dart` assert counts
and coordinates that the current demo seed no longer matches, and need updating
to the fixture rather than the other way round. The demo video.
