# Nook — Build Plan

The implementation plan for Nook, derived from three source documents:

- **Final Project Proposal (Revised)** — MVP scope, storage decision, data model, risks
- **Final Project Mockup** — the 24 drawn screens and the screen-by-screen revision table
- **Design System** — palette, type scale, spacing rule, component inventory

Nothing here is invented. Where the three documents disagreed, or where a drawn
screen needed a field the proposal's tables did not have, the conflict is listed
in §1 with the decision that resolved it. Everything else traces back to a line
in one of the three PDFs.

**Status:** built. Every screen below exists and runs; §13 records what changed
between this plan and the finished app.

---

## 1. Decisions log

Twelve points were ambiguous or contradictory across the three documents. Each
was resolved before any code was written.

| # | Conflict | Decision |
| --- | --- | --- |
| 1 | Mockup draws a warm vertical gradient background and a **solid Burnt Orange** bottom nav with white icons. Design system specifies flat `#FAFAF8` and a **white** nav with orange active icons. | **Mockup wins.** Build the gradient and the orange nav bar. `docs/03-design-system.md` is updated so the written doc matches the shipped app. |
| 2 | The Gemini key can never ship in a public web build, but "Analyze" is the core action. | **Two implementations behind one interface** (the proposal's own `kIsWeb` fallback pattern, page 13). Real Gemini when a `.env` key is present; a deterministic sample extractor otherwise, with an honest on-screen notice. Real extraction is shown in the demo video. |
| 3 | Travel Details draws Location, Country, Best Time to Visit and Budget. `saved_posts` only has `ai_destination`, `ai_category`, `ai_summary`. | **Extend the table and the prompt.** Add `ai_country`, `ai_best_time`, `ai_budget_note`. The proposal's Screens section already names all four fields; this fills in the table rather than adding a feature. |
| 4 | The nav has a Trips tab and MVP feature #3 needs trip browsing, but no Trips or Trip Details frame was ever drawn. | **Design both** in the established visual language. They also serve as the "See All" destinations. |
| 5 | Profile lists five rows; three of those screens are stretch or non-essential. | **Keep all five rows.** Connected Platforms renders as drawn but disabled with a "Stretch goal — not in this build" line; About Nook and Help & Support are real static screens; Settings is drawn as-is with inert switches. |
| 6 | Two different category lists across screens (6 on Search, 7 on Add). | **Union of both, 8 values:** Food, Travel, Itinerary, Accommodation, Adventure, Scenery, Nightlife, Other. This is the enum Gemini must return. |
| 7 | Home draws "Recently Viewed" and Search draws "Recent Searches" with per-item delete. Neither has a home in the proposal's three tables. | **Both real.** Add `last_viewed_at` to `saved_posts` and a small `recent_searches` table. |
| 8 | A1 offers a "Create Note" method that the proposal never describes. | **Real.** Saves a post with `import_method = 'note'`, no URL, no AI call. |
| 9 | S1's primary button reads "Continue", which does nothing meaningful on a detail screen, and S2 has no other entry point. | **Relabel to "Travel Details"** so it opens S2. |
| 10 | Design system names sizes and weights but no typeface. | **Inter, bundled as a local asset.** Type scale extended with Display 32 and an uppercase Overline 12 — both are drawn in the mockup but missing from the doc's 24/16/12. |
| 11 | Every mockup screen is populated, but a fresh browser opens an empty database. | **Seed the mockup's own fictional data on first run,** with reset-to-seed and clear actions in Settings. Home Empty stays reachable after clearing. |
| 12 | The revision table says Home cards show destination in the caption line; the drawn H1/H4 cards show `@creator`. | **Build as drawn** — `@creator` on Home, destination on Search Results. The pixels win; destination is already first-class on Search, Review and Details. |

### Consequences worth knowing

- The **share icon** on Post Details is drawn but inert, so `original_url` is stored and never opened. One line of `url_launcher` flips this if wanted.
- **"Explore Itinerary"** on Travel Details maps to stretch goal #3 and ships disabled with a "Stretch goal" label.
- **Home section order** follows H1 (Recent Saves → Your Trips → Recently Viewed). H2 draws a different order; H1 is the canonical "Home (Default)" frame.
- **Tagline spelling** differs between documents: the splash and About screens draw "Never lose your next favourite idea."; the proposal's line is "Never lose your next favorite find." Screens use the drawn copy verbatim; the README uses the proposal's line. Worth settling on one before the video.
- **Account (P2)** draws no Save button although the revision table asks for one. Plan: save on field blur with a confirmation snackbar, no extra button, so the screen still matches the frame.

---

## 2. Design tokens

Every value below becomes a `const` in `lib/theme/`. No screen hardcodes a color
or a number; no Material default survives.

### Colour

| Token | Value | Source | Used for |
| --- | --- | --- | --- |
| `primary` | `#DD700B` | Design system | Primary buttons, active nav, links, accents |
| `secondary` | `#FCF8D8` | Design system | Chip fills, selected states, gradient foot |
| `background` | `#FAFAF8` | Design system | Gradient head |
| `surface` | `#FFFFFF` | Design system | Cards, search bar, dialogs |
| `error` | `#D9534F` | Design system | Delete actions, validation |
| `textPrimary` | `#2E2E2E` | Design system | Body and headings |
| `border` | `#D9DADF` | Design system | Field and card outlines |
| `textMuted` | `#8A8F98` | *Derived from mockup* | Creator names, captions, section labels, inactive nav |
| `placeholder` | `#F0F1F4` | *Derived from mockup* | Thumbnail and avatar placeholder fills |

`textMuted` and `placeholder` are additions: the design system names one text
colour, but the mockup clearly renders captions and inactive nav items in a
lighter grey. Both are recorded in the updated design system doc.

### Screen gradient

Vertical, `#FAFAF8` at the top through `#FCF8D8` at the bottom, on every screen
behind all content. Implemented once in `NookScaffold` so no screen repeats it.

### Spacing

`tight = 8`, `section = 16`, `screenEdge = 24`, exactly as the design system's
spacing rule states. A `NookGaps` helper exposes them so `SizedBox(height: 16)`
never appears as a literal.

### Radius

| Token | Value | Applies to |
| --- | --- | --- |
| `sm` | 12 | Nav icon tiles, thumbnails, avatar squares |
| `md` | 16 | Cards, buttons, text fields, dialogs |
| `pill` | 999 | Metadata chips, category chips, search bar |

Derived from the mockup; the design system only says "rounded".

### Type — Inter, bundled

| Style | Size | Weight | Used for | Source |
| --- | --- | --- | --- | --- |
| Display | 32 | Bold | "Set Up Profile", "Review & Save", "Welcome to Nook" | *Added* |
| Heading | 24 | Bold | Screen titles, section headers, trip names | Design system |
| Title | 20 | SemiBold | App bar titles, card titles on details | *Added* |
| Body | 16 | Regular | Saved posts, notes, descriptions | Design system |
| Caption | 12 | Regular | Creator names, platform labels, dates, hints | Design system |
| Overline | 12 | SemiBold, +0.08em, uppercase | "DETECTED DESTINATION", "SUPPORTED PLATFORMS", "ACTIONS" | *Added* |

Inter ships in `assets/fonts/` rather than loading from the Google Fonts CDN, so
the deployed build has no third-party network dependency and renders identically
offline.

### Elevation

One shadow token: `0 2 8 rgba(46,46,46,0.06)`, applied to white cards and the
dialog. Nothing else casts a shadow. Material's default elevations are switched
off in the theme.

---

## 3. Component inventory

The design system's ten components, each becoming exactly one widget. Screens
compose these; they do not build their own buttons or cards.

| Design system component | Widget | Notes |
| --- | --- | --- |
| *(screen chrome)* | `NookScaffold` | Gradient background, safe areas, optional nav bar |
| *(screen chrome)* | `NookAppBar` | Rounded-square back button + title, as drawn on every sub-screen |
| Primary Button (nav bar) | `NookBottomNav` | Solid Burnt Orange, white active label, translucent-white inactive. Home / Trips / Add / Profile |
| Search Bar | `NookSearchBar` | White pill, `#D9DADF` border, leading search icon, optional trailing clear |
| Primary Button | `NookPrimaryButton` | Burnt Orange fill, white label, radius 16, full-width by default |
| Secondary Button | `NookSecondaryButton` | White fill, grey outline, charcoal label. Destructive variant swaps label and border to `#D9534F` |
| Saved Post Card | `SavedPostCard` | Two variants: `.grid` (Recent Saves carousel — thumbnail on top) and `.row` (Recently Viewed, Search, Trip Details — thumbnail at left) |
| Collection Card | `TripCard` | White card, folder icon in a rounded tile, trip name + item count |
| Text Field | `NookTextField` | White fill, grey border, radius 16. Multiline variant carries the `0/500` counter |
| Section Header | `SectionHeader` | Bold charcoal title with an optional Burnt Orange "See All ›" |
| Metadata Chip | `MetadataChip` | Soft Butter pill, Burnt Orange text, optional leading icon. Outlined variant for the Search suggestion chips |
| Empty State | `NookEmptyState` | Circular outlined icon, heading, body, primary action |
| Dialog | `NookDialog` | White rounded modal, Cancel (secondary) + Confirm (primary, or Soft Red when destructive) |

---

## 4. Screens and flow

24 screens. Mockup IDs in brackets. Every screen listed as drawn; the two marked
**new** are §1 decision 4.

### Launch flow

```
Splash [LA1] ─► Onboarding pager [LA2-LA5] ─► Get Started [LA6] ─► Set Up Profile [LO1] ─► Home
      └── profile already in the users table ────────────────────────────────────────────┘
```

| Screen | Contents |
| --- | --- |
| **Splash** [LA1] | Logo mark, "Nook", tagline, Continue |
| **Onboarding** [LA2–LA5] | Four pages with illustration slot, heading, body, 4-dot indicator. Copy verbatim: "Save travel finds" / "AI organizes your trips" / "Organize by trip" / "Rediscover anything". Button reads Next, then Get Started on page 4 |
| **Get Started** [LA6] | "Welcome to Nook", "Your travel content, saved in one place", single Get Started CTA. No sign-in methods — there is no server to sign in to |
| **Set Up Profile** [LO1] | Display heading, subtitle, Full Name, Email address, Profile Picture picker, Continue. Writes the one row in `users` |

### Tab 1 — Home

| Screen | Contents |
| --- | --- |
| **Home** [H1/H2/H4] | Greeting + name, search bar, **Recent Saves** (horizontal `SavedPostCard.grid`, See All), **Your Trips** (2-up `TripCard` grid, See All), **Recently Viewed** (`SavedPostCard.row` list, See All) |
| **Home Empty** [H3] | Greeting + search bar retained, then `NookEmptyState`: bookmark icon, "No trips yet — save your first find", "Paste a link from TikTok, Instagram, or YouTube to start building your first trip.", **Save First Find** → Add flow |
| **Search** [H5] | Search bar, Recent Searches (clock icon + query + delete ✕), Suggested Categories (8 outlined chips), All Saved Posts list |
| **Search Results** [H6] | Query in the bar with a clear button, "N results", rows showing destination + platform chip + category chip |

### Tab 2 — Trips **(new)**

| Screen | Contents |
| --- | --- |
| **Trips** | "Your Trips" heading, 2-up `TripCard` grid over all trips, a create-trip tile, and `NookEmptyState` when there are none |
| **Trip Details** | Trip name, item count, `SavedPostCard.row` list of that trip's posts, rename and delete in an overflow menu |

Both follow the drawn grid, card and chip specs exactly; nothing new is invented
visually.

### Tab 3 — Add

```
Choose Method [A1] ─► Paste Link [A2] ─► (extract) ─► Destination & Category [A3]
                                                              │
Create Note ─────────────────────────────►  Choose Trip [A4] ─┘
                                                     ▼
                                        Personal Note [A5] ─► Review & Save [A6] ─► Home
```

| Screen | Contents |
| --- | --- |
| **Choose Add Method** [A1] | "Paste Link / Save a post from social media" and "Create Note / Write a personal note" |
| **Paste Link** [A2] | URL field, SUPPORTED PLATFORMS row (TikTok, Instagram, Facebook, YouTube), **Analyze**. Analyze shows the loading state; failure shows an inline error with Retry and Enter manually |
| **Destination & Category** [A3] | DETECTED DESTINATION in a white confirm field with a check, "Category: X" beneath, "OR CHOOSE ANOTHER:" chips for the remaining categories, Continue. Destination is editable by tapping the field |
| **Choose Trip** [A4] | ADD TO TRIP radio list of trips with item counts, "+ Create New Trip" with the "e.g. Japan 2027" hint, Continue |
| **Personal Note** [A5] | "Add a Note (Optional)", multiline field with `0/500` counter, Skip (secondary) and Continue (primary) |
| **Review & Save** [A6] | Summary card — thumbnail, TITLE, CREATOR, PLATFORM chip, DESTINATION, CATEGORY chip, TRIP, divider, PERSONAL NOTE — and **Save Post** |

### Post detail stack

| Screen | Contents |
| --- | --- |
| **Post Details** [S1] | Thumbnail with "Video Thumbnail" chip, title, creator with avatar, destination line, platform + category chips, AI SUMMARY, TRIP tile, PERSONAL NOTES, "Saved on <date>", **Travel Details** button + share button (inert). Overflow "…" → Manage Post |
| **Travel Details** [S2] | Post header, Location, Country, MAP LOCATION placeholder, Best Time to Visit, Budget, disabled "Explore Itinerary". The signature screen — the most visual care of any |
| **Personal Notes** [S3] | Post header, EDIT NOTES multiline field, "Last edited <date>", Save Changes |
| **Manage Post** [S4] | CURRENT TRIP with a Change action, MOVE TO ANOTHER TRIP list, ACTIONS: Save Changes, then **Delete Post** in Soft Red behind a `NookDialog` confirmation |

### Tab 4 — Profile

| Screen | Contents |
| --- | --- |
| **Profile** [P1] | Avatar, name, email, two stat tiles (Saved Posts / Trips), five rows: Account, Settings, Connected Platforms, About Nook, Help & Support |
| **Account** [P2] | Avatar + Change Photo, Full Name, Email, Danger Zone → "Delete my account" (confirmation dialog, wipes the local database, returns to onboarding) |
| **Settings** [P3] | Four switches as drawn (inert), Data section: Export Data, Clear Search History, Clear Cache. Reset-to-seed lives here |
| **Connected Platforms** [P4] | Exactly as drawn, buttons disabled, "Stretch goal — not in this build" |
| **About Nook** [P5] | Logo, "Nook", version, tagline, four rows, "Made with care for content lovers." |
| **Help & Support** [P6] | Help search field, five Popular Topics, Send Feedback / Report a Bug |

---

## 5. Data layer — Drift, on device

Storage is exactly what the proposal chose: **Drift, SQL, on-device, no server,
no account, no API key.** Three tables from the proposal's data table, plus the
additions from decisions 3 and 7, each marked.

```dart
// users — one local row. No password column: there is nothing to authenticate against.
id            int      autoIncrement
name          text
email         text
profilePicture text?   // data URI; see below

// trips
id            int      autoIncrement
name          text
userId        int      references users(id)
createdAt     dateTime

// saved_posts
id            int      autoIncrement
title         text
creator       text?
platform      text            // tiktok | instagram | facebook | youtube | other
originalUrl   text?           // null for import_method = note
importMethod  text            // link | note
thumbnailUrl  text?
aiDestination text?
aiCategory    text?           // one of the 8 canonical categories
aiSummary     text?
aiCountry     text?           // + decision 3
aiBestTime    text?           // + decision 3
aiBudgetNote  text?           // + decision 3
tripId        int?     references trips(id)
personalNote  text?
dateSaved     dateTime
lastViewedAt  dateTime?       // + decision 7
noteEditedAt  dateTime?       // + decision 7, drawn as "Last edited" on S3

// recent_searches                 // + decision 7
id            int      autoIncrement
query         text
searchedAt    dateTime
```

**One deliberate deviation:** the proposal lists `item_count` as a column on
`trips`. It is computed by the DAO with a join count instead of stored, so the
number on a `TripCard` can never disagree with the rows behind it. Same value,
one fewer thing to keep in sync.

**Profile picture on web.** `image_picker` returns bytes on web, not a file
path, so the image is stored as a base64 data URI in `profilePicture`. Nothing
leaves the device — consistent with the proposal's "nothing leaves the device"
claim.

**Web setup.** Drift's web backend needs `sqlite3.wasm` and `drift_worker.js`
in `web/`, and the connection opens through `WasmDatabase`. This is the one
piece of setup that will silently white-screen the deployed build if skipped,
so it lands in Phase 0, not late.

**Queries are streams.** DAO methods return `Stream` via Drift's `watch()`, and
screens read them with `StreamBuilder`. Saving a post updates Home, Trips and
Search with no manual refresh and no state-management package — `setState` plus
Drift streams is the whole story. The README's "State" row says exactly that.

**Seed data** (decision 11) inserts on first run only, guarded by a row count:
the four trips and the posts drawn in the mockup — Japan 2027, Weekend Getaways,
Someday List, Europe Backpacking; "5 Hidden Cafes in Kyoto", "3-Day Lisbon
Itinerary on a Budget", "This Beach in Palawan Looks Fake", "Best Street Food in
Bangkok", "Hidden Gems in Porto" and the rest. All fictional, no real personal
data, which is also what the security checklist has to be able to claim.

---

## 6. AI layer — Gemini, and what happens without it

### The interface

```dart
abstract class AiExtractor {
  Future<ExtractionResult> extract(String url);
}
```

Two implementations, chosen once at startup — the proposal's own "one interface,
two implementations" pattern from page 13:

- **`GeminiExtractor`** — `google_generative_ai`, key read from a git-ignored
  `.env` through `flutter_dotenv`. Used whenever a non-empty `GEMINI_API_KEY` is
  present.
- **`SampleExtractor`** — deterministic, keyed on the URL's host and a hash of
  the path, returning one of the seeded fixtures. Used when there is no key,
  which is always true of the GitHub Pages build.

When the sample extractor is active, A3 shows a small honest notice: *"Sample
data — this build ships without an API key."* Never a silent fake.

### The contract

One call per saved link, asking for structured JSON:

```json
{
  "title":        "string",
  "creator":      "string or null",
  "destination":  "City, Country — or null if none is stated",
  "country":      "string or null",
  "category":     "Food|Travel|Itinerary|Accommodation|Adventure|Scenery|Nightlife|Other",
  "summary":      "2-3 sentences",
  "best_time":    "string or null",
  "budget_note":  "string or null"
}
```

`responseMimeType: application/json` with a response schema, so the reply is
parsed rather than scraped. `category` is constrained to the eight values from
decision 6; anything unrecognised falls back to `Other`. Any field may come back
null — the proposal's own second risk is exactly that destinations return vague
or empty — and every screen renders `—` for a null rather than an empty gap.

**Platform is not asked of the model.** It is parsed from the URL host locally,
which is both free and reliable.

**Thumbnails.** Arbitrary social thumbnails cannot be fetched from a browser
build (CORS), and the mockup draws placeholder boxes on every card anyway, so
`thumbnailUrl` stays null and the placeholder renders as designed. This matches
the frames rather than working around them.

### Failure handling

Every call is wrapped in `try`/`catch` with the `if (!mounted) return` guard the
proposal names. Three outcomes: success → A3; failure → inline error with
**Retry** and **Enter manually**; missing-key misconfiguration → a clear startup
message, not a confusing 400 later.

**Risk work the proposal committed to:** test extraction against 10 real travel
links per platform and log how often a usable destination comes back. That is a
Phase 5 task with a real date, not a line in a document.

---

## 7. Packages

| Package | Why |
| --- | --- |
| `drift`, `drift_dev`, `sqlite3_flutter_libs`, `path_provider` | The storage decision, plus its web worker setup |
| `google_generative_ai` | Gemini, named specifically in the proposal |
| `flutter_dotenv` | Key from a git-ignored `.env`, page 7's exact pattern |
| `image_picker` | Profile picture on LO1 and P2; works on web |
| `intl` | "Saved on July 15, 2025" date formatting |
| `device_preview` | Already in the starter; stays on, per START-HERE |

No routing package (Navigator with named routes), no state-management package
(Drift streams), no HTTP client beyond what the Gemini SDK carries. `flutter_map`
stays out: the proposal files it as a stretch goal and the mockup draws a map
placeholder, which is what ships.

---

## 8. Project structure

```
lib/
  main.dart                  DevicePreview + dotenv load + DB open
  app.dart                   MaterialApp, theme, named routes
  theme/                     nook_colors, nook_typography, nook_spacing,
                             nook_radius, nook_theme
  data/
    database.dart            Drift database + web/native connection
    tables.dart              the five tables
    daos/                    posts_dao, trips_dao, users_dao, searches_dao
    seed.dart                first-run mockup data
  ai/
    ai_extractor.dart        the interface + ExtractionResult
    gemini_extractor.dart
    sample_extractor.dart
    categories.dart          the 8 canonical categories
    platform_from_url.dart
  widgets/                   the 13 components from §3
  screens/
    onboarding/  home/  search/  trips/  add/  details/  profile/
test/
  theme_test.dart            tokens resolve, no stray Material defaults
  dao_test.dart              save → read back, move between trips, delete
  extractor_test.dart        JSON parsing, unknown category → Other, null fields
  widget_test.dart           Home renders seeded data
```

---

## 9. Build order

Phased so the app runs end to end early and each phase leaves it working.

| Phase | Work | Est. |
| --- | --- | --- |
| **0** | **Drift spike** — one table, insert a hardcoded post, restart, read it back, *including the web worker setup*. The proposal promised this before feature 1 | 1.0 h |
| **1** | Theme + all 13 components, on a scratch gallery screen | 2.5 h |
| **2** | Splash, onboarding, Get Started, Set Up Profile, nav shell | 2.0 h |
| **3** | Full schema, DAOs, seed data, stream wiring | 2.5 h |
| **4** | Home (3 states), Trips, Trip Details | 3.0 h |
| **5** | Add flow A1–A6, both extractors, error states, the 40-link extraction test | 6.0 h |
| **6** | Post Details, Travel Details, Personal Notes, Manage Post, delete dialog | 3.0 h |
| **7** | Search, Search Results, recent searches | 2.0 h |
| **8** | Profile, Account, Settings, Connected Platforms, About, Help | 2.0 h |
| **9** | Polish pass against every frame, tests, `flutter analyze` clean, screenshots, docs, video | 3.0 h |
| | **Total** | **27 h** |

The proposal's ~17.5 h covers the five MVP *features*. The rest is the screens,
the design system and the deliverables around them — the two numbers measure
different things and do not contradict.

---

## 10. Deployment and secrets

- **Host: GitHub Pages**, the workflow already in the repo. No alternate host is
  needed and none will be used: there is no server, no proxy, no billable key in
  the build. The README says so explicitly.
- **`GEMINI_API_KEY` never reaches the deploy.** It is not a repository secret
  and not a `--dart-define`. The build workflow is left as-is. The key exists
  only in a local `.env`, which `.gitignore` already covers, with a committed
  `.env.example` carrying a placeholder.
- The deployed build therefore runs `SampleExtractor` and says so on screen.
  Real Gemini extraction is recorded in the demo video.
- `--base-href` is already handled by the workflow.
- `device_preview` stays enabled, per START-HERE.

---

## 11. Repo deliverables

Not code, but part of what is submitted.

- [ ] `README.md` — live link, demo video link, screenshots at phone size, what it does, Built with (Flutter / setState + Drift streams / Drift / the package list), running it, the env-var table, the privacy-and-secrets section, honest status
- [ ] `docs/01-proposal.md` — the revised proposal under the template's headings
- [ ] `docs/02-mockup.md` — the 24 frames exported into `docs/assets/`, plus the screen flow
- [ ] `docs/03-design-system.md` — palette, type scale, spacing, components, **updated for decisions 1 and 10**, with the PDF in `docs/assets/`
- [ ] `docs/04-weekly-reports.md` — written weekly, starting this week
- [ ] `docs/05-demo-video.md` — the recording; must show real Gemini extraction running locally
- [ ] `docs/06-security-and-privacy.md` — filled in and dated: everything on-device, `GEMINI_API_KEY` local only, nothing in the deployed build, seed data entirely fictional
- [ ] `project/README.md` in the **workspace** repo — copied from `content/final-project-revision/project-README-template.md`, with the two links. Private pointer; no `student.json` in this public repo
- [ ] `START-HERE.md` read and deleted
- [ ] `flutter analyze` clean

---

## 12. Open risks

1. **Extraction reliability** — the proposal's headline risk, and larger now that
   extraction targets travel-specific fields. Mitigation is the Phase 5 test
   across 40 real links, with the failure rate written down.
2. **Vague destinations** — a country instead of a city, or nothing. Mitigation
   is designed in: the destination field on A3 is editable, and every screen
   renders `—` rather than breaking on a null.
3. **Drift on web** — the one setup that white-screens silently if the wasm and
   worker files are missing. De-risked by putting it in Phase 0.
4. **Mockup fidelity drift** — 24 frames is a lot to match by memory. Phase 9 is
   an explicit frame-by-frame comparison pass, not a general "polish".


---

## 13. As built — what changed, and what broke

The plan above survived contact with the code largely intact. Six things were
different in practice, and they are worth recording because each was a real
decision rather than a typo.

### Changes to the plan

1. **Search moved inside the Home tab.** The plan had it as its own route. Built
   that way it was a dead end: no back button, because the mockup does not draw
   one. The mockup names those frames "Home: Search" and "Home: Search Results"
   and draws the tab bar on both, so search became a state of the Home tab and
   the Home tab is how you leave it.
2. **`trips.item_count` is computed, not stored** — flagged in §5 as a planned
   deviation, and it stayed that way.
3. **Foreign keys needed explicit SQL.** Drift's `references(Trips, #id)`
   generated no `REFERENCES` clause at all — the schema came out with the
   relationship missing, silently. Switched to `customConstraint` plus
   `PRAGMA foreign_keys = ON`, and added a test asserting a post cannot point at
   a trip that does not exist. That relationship is the stated reason Drift beat
   Hive, so it had to be real.
4. **CanvasKit is served from the app's own folder.** Flutter's default loads it
   from a Google CDN, which white-screens with no error behind a proxy or
   offline. A custom `web/flutter_bootstrap.js` points at the copy the build
   already produces.
5. **The deploy workflow gained one step** — `cp .env.example .env` — because
   `flutter_dotenv` reads `.env` through the asset bundle, and the runner has
   none. It copies the keyless example, so the deployed build has no key by
   construction rather than by omission. This is the only change to a file the
   starter provided.
6. **A `NOOK_DEVICE_PREVIEW` build flag** was added so screenshots can be taken
   at phone size without the `device_preview` frame. The frame stays on by
   default, including in the deployed build.

### Bugs found and fixed during the build

- **Recent searches came back in the wrong order.** Two searches in the same
  millisecond tie on the timestamp, and SQLite broke the tie by row id, putting
  the *older* one first. Fixed with an explicit second sort key.
- **A chip could overflow its card.** "Accommodation" is wider than a Recent
  Saves card allows. Fixed in `MetadataChip` so it cannot happen anywhere.
- **Two rows of non-flexible text** could clip — the "Saved on <date>" line and
  the Travel Details label rows. The browser hid it; the widget tests, which use
  a wider fallback font, did not.

### Tests

28, all passing:

| File | Covers |
| --- | --- |
| `test/dao_test.dart` | Seeding, persistence across a reopen, search across every field, recently-viewed ordering, moving posts between trips, deleting a trip without destroying its posts, note edits, search-history de-duplication, and foreign-key enforcement |
| `test/extractor_test.dart` | Platform detection, the category vocabulary and its fallback, and the sample extractor's determinism, keyword matching, slug-derived titles and error handling |
| `test/widget_test.dart` | Home renders its sections, search opens in-tab and filters, the no-results state, post and travel details, the empty state, the splash-to-onboarding step, and that no Material default colours or fonts leak into the theme |

### Still outstanding

- The 40-link extraction test (10 real links per platform), which is the
  proposal's own mitigation for its biggest risk.
- The demo video, showing real Gemini extraction locally.


---

## 14. Second pass — map, thumbnails, and three bugs

A review against the mockup after the first build turned up six items. What each
one actually turned out to be:

### 1. Gemini extraction — already implemented, and now visible

`GeminiExtractor` was wired from the first build; what was missing was any way
to *tell* which extractor was running. Detection now reports itself in
**Profile → Settings**, and Paste Link says so before a link is spent finding
out. Extraction was also extended to return **latitude and longitude** so the
map has something to pin.

The seeded Recent Saves and Trips are, as suspected, sample data. Real
extraction needs `GEMINI_API_KEY` in `.env` — see §15.

### 2. Map — was not implemented, now is

`flutter_map` with OpenStreetMap tiles, which is what the proposal chose and
why: no key, no billing account, works on web. A post with coordinates gets a
pin; a destination too broad to place ("Southeast Asia") keeps the mockup's
placeholder and says why rather than showing an empty grey panel. The seeded
library carries real coordinates so the map works before anything is saved.

### 3. Thumbnails — partly possible, and honest about the rest

- **YouTube**: derived from the video id. No key, no network call, always works.
- **TikTok**: attempted through its public oEmbed endpoint, with silent fallback
  when the browser is not allowed to read it.
- **Instagram and Facebook**: not possible. Both retired public oEmbed; a
  thumbnail now needs a Meta app, an access token and app review. Those posts
  keep the placeholder.

Images render through `WebHtmlElementStrategy.prefer`, so a host without CORS
headers still displays, and a dead URL falls back to the placeholder instead of
a broken image.

### 4. Alignment — two real layout bugs

- **Travel Details values were not flush right.** The label was a loose
  `Flexible` and the value an `Expanded`, so both took an *equal share of the
  free space*: the value box was only half the row and sat wherever the label
  happened to end. Short labels ("Location") left their value floating in the
  middle; long ones ("Best Time to Visit") happened to look correct. Both sides
  are now flex, so the boxes tile the full width and every value ends at the
  right edge.
- **Chips dropped below the creator.** The caption row was a `Wrap`, so the
  platform and category chips fell to a second line as soon as the handle was
  long. It is a `Row` now: the creator ellipsises instead, since it is the part
  that survives shortening. Trip Details also stopped showing the category chip
  — with both chips there was no room left for the handle at phone width.

### 5. Add Note — genuinely broken, now fixed

`NookNoteField` put an `Expanded` inside a `Column` with unbounded height (these
fields live in scroll views), so **the note field collapsed to nothing** and the
Create Note screen showed only a title box. It is sized by `minLines` now and
grows with its content.

### 6. LA1-LA6 and LO1 — built all along, but unreachable

Every one of those screens existed from the first build. The seed inserted a
*named* user row, and the launch gate treated any user row as "already set up",
so every install went straight to Home and the onboarding run could never be
seen. The seeded row is now nameless — it exists only so trips have an owner —
and the gate checks for a name. Set Up Profile fills that same row in rather
than inserting a second one.

Fixing that exposed a second bug behind it: the onboarding screens are *pushed*
routes, so swapping the gate's home route left them sitting on top. Saving a
profile now clears the stack.

### Tests

40, all passing. New coverage: onboarding reachability and the full LA1-LO1 run,
Set Up Profile reusing the seeded row, the Create Note field and its saved note,
seeded coordinates, the region-with-no-coordinates case, and thumbnail
derivation for every YouTube URL shape.

The rendered map is checked in the browser rather than in a widget test:
`flutter_map`'s tile layer holds live timers for tiles a test environment never
serves, so a widget test can neither settle nor tear it down.

---

## 15. What needs a key, and where it goes

Two things in this app depend on something outside the repository.

| What | Needs | Where |
| --- | --- | --- |
| Real destination, category, summary and coordinate detection | A Google Gemini API key, free tier is enough | `GEMINI_API_KEY` in `.env` at the project root. Get one at https://aistudio.google.com/apikey |
| Instagram and Facebook thumbnails | A Meta app, an access token and app review | Not configured, and not planned — out of scope for the MVP |

`.env` is listed as an asset in `pubspec.yaml`, so **the file must exist for the
app to build at all**, even empty. `cp .env.example .env` is enough; the key
itself is optional. Restart after adding it — `.env` is read once at startup.

Nothing else needs configuring. The map needs no key. OpenStreetMap tiles are
fetched directly from `tile.openstreetmap.org`, which the sandbox this was built
in blocks, so **the tile imagery is the one thing not verified here** — the map
widget, its pin, its attribution and the placeholder logic all are. It should
render normally on any machine with ordinary internet access.
