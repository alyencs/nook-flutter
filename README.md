# Nook

> Never lose your next favourite find. Nook keeps the travel content you save on
> TikTok, Instagram, Facebook and YouTube in one place — grouped by trip, and
> searchable across every platform.

**Live demo:** https://alyencs.github.io/nook-flutter/
**Demo video:** `docs/demo.mp4` (link it here once it exists)
**Course:** Applications Development and Emerging Technologies (6ADET), Holy Angel University
**Author:** Alison C. Sampang

This repository lives in the author's own GitHub account and is public on
purpose. There is no `student.json` here and there should not be one: see
[SECURITY-CHECKLIST.md](SECURITY-CHECKLIST.md) for what a public repo means for
secrets and personal data.

---

## Screenshots

| Onboarding | Set up profile | Home |
| --- | --- | --- |
| ![Onboarding](docs/assets/screen-onboarding.png) | ![Set up profile](docs/assets/screen-profile-setup.png) | ![Home](docs/assets/screen-home.png) |

| Search results | Post details | Recently Deleted |
| --- | --- | --- |
| ![Search results](docs/assets/screen-search-results.png) | ![Post details](docs/assets/screen-post-details.png) | ![Recently Deleted](docs/assets/screen-recently-deleted.png) |

*Captured from the current build at 390×844 on a 3× screen. The machine they
were taken on cannot reach Wikimedia Commons or OpenStreetMap, so the seeded
destination photographs — behind the cards and on the onboarding page — fall
back to the placeholder each screen is designed to show, and Travel Details is
not included at all, because its map would have rendered as "Map tiles could
not be loaded" rather than as a map. The live link above renders both. To
regenerate these with the images in place, run the app locally and capture the
same six screens at 390×844.*

## What it does

Travellers find destinations, itineraries and tips scattered across four apps.
Saving them inside each one scatters trip research four ways, and none of those
Saved folders group content by trip or search across platforms. Nook does both.

- **Paste a link to save it.** TikTok, Instagram, Facebook or YouTube. The
  platform is recognised from the URL.
- **Or share straight to Nook.** Installed to a home screen, Nook appears in the
  Android share sheet as a Web Share Target: picking it opens the app with the
  link already in the field and analysis already running. It is only a source of
  URLs — everything after it is the code Paste Link runs.
- **Detection reads the post, not just the link.** Nook fetches what each
  platform publishes — a YouTube title and description, a TikTok caption — and
  hands that to the model, which returns the place, a travel category, a summary,
  the country, the best time to visit, a rough budget, the specific places the
  post named and its tips. Anything it cannot tell you is left blank rather than
  invented, and the destination is editable before you save.
- **See where it is.** A save whose destination is specific enough to place gets
  a pin on a map in Travel Details, and a tap opens a full-screen map you can
  drag, pinch and zoom. A region like "Southeast Asia" has no single point, so it
  keeps the placeholder and says why.
- **Group saves into trips.** "Japan 2027", "Weekend Getaways". A post belongs
  to exactly one trip and can be moved between them. Trips have a folder colour.
- **Search across everything.** One field matches titles, creators,
  destinations, countries, categories and your own notes.
- **Keep a personal note** on any save, written while the reason is still fresh
  and editable afterwards.
- **Delete without losing anything.** Deleted posts and trips go to Recently
  Deleted under Profile, where they can be restored for 30 days.

## Built with

| | |
| --- | --- |
| Framework | Flutter 3.47 (Dart 3.13), web target |
| State | `setState` plus Drift stream queries read through `StreamBuilder` — no state-management package |
| Storage | [Drift](https://drift.simonbinder.eu) — on-device SQL, five tables at schema version 6, works on web (see below) |
| AI | Gemini's REST API over `http`, behind an interface with a keyless fallback |
| Link metadata | Public oEmbed for YouTube and TikTok; the YouTube Data API and the Meta Graph API for the rest, both optional |
| Maps | `flutter_map` with OpenStreetMap tiles — no key, no billing account |
| Icons | Material Icons, plus Font Awesome brand marks for the platform logos |
| Other packages | `flutter_dotenv` (keys out of git), `image_picker` (profile photo), `url_launcher` (open original, open in maps), `device_preview` (phone frame on the live link) |
| Type | Manrope for everything functional, Instrument Serif for the rationed editorial accent — both bundled locally, both SIL OFL |

### Storage

One Drift (SQLite) database on the device, at **schema version 6**:

| Table | Holds |
| --- | --- |
| `users` | The local profile: a name, an optional photo. One row. No password — there is no account. |
| `trips` | Name, owner, created date, folder colour, and `deleted_at` for Recently Deleted. Item counts are computed, never stored. |
| `saved_posts` | The big one, 32 columns: title, caption, creator and handle, platform, URL, source id, media type, thumbnail; the extraction results (destination, country, category, summary, best time, budget, the location from place name down to region, coordinates, named places, highlights); the trip it belongs to, the personal note, and the dates saved, viewed, edited and deleted. |
| `recent_searches` | Query and timestamp, behind the Recent Searches list. |
| `app_settings` | The four Settings switches, as key/value rows so adding one is not a migration. |

Six schema versions so far, each with a tested migration: 2 added `app_settings`
and the coordinates, 3 the columns that keep a full extraction, 4 the named
places and highlights (and relaxed `users.email`, which is no longer collected),
5 `deleted_at` on posts and trips, 6 the trip folder colour.

Storage is on the device and nowhere else. That is a deliberate decision, not a
shortcut: two travellers never need to see the same saved posts, so a server
would be work for nothing, and a saved post belonging to exactly one trip is a
foreign key rather than a flat key-value box. The reasoning is in
[docs/01-proposal.md](docs/01-proposal.md); the trade-off accepted is that saves
do not sync between devices.

## Running it yourself

**Requirements**

- Flutter on the stable channel. `pubspec.yaml` requires **Dart `^3.8.0`**;
  built and tested on **Flutter 3.47.2 / Dart 3.13.2**. Any Flutter release
  shipping a Dart in that range will resolve.
- A Chromium-based browser for `-d chrome`, or any browser for
  `-d web-server`.
- No API key is needed to run the app.

This is a **web-only** Flutter project: there is no `android/` or `ios/`
directory. `flutter run -d chrome` and the GitHub Pages build are the two ways
it is meant to run.

```bash
flutter pub get
cp .env.example .env      # required, even left empty — see below
flutter run -d web-server --web-port 8080
```

Then open http://localhost:8080.

`.env` is listed as an asset in `pubspec.yaml` (that is how `flutter_dotenv`
reads it), so **the file has to exist before the app will build**, even empty.
Copying `.env.example` is enough; every value in it is optional.

First launch seeds a small demo library — the trips and posts from the mockup,
with real destination photographs — so the app opens looking like the design
instead of an empty database. All of it is fictional.

Useful commands:

```bash
flutter analyze                                    # clean at this commit
flutter test                                       # 275 tests
flutter build web --release                        # what the workflow does
dart run build_runner build --delete-conflicting-outputs   # after editing lib/data/tables.dart
```

### Environment variables

This project reads its configuration from a `.env` file that is **not** in the
repository. Copy `.env.example`, fill in whichever values you want, and never
commit the result. Nook runs with none of them set.

| Variable | What it is | Without it | Where to get one |
| --- | --- | --- | --- |
| `GEMINI_API_KEY` | Powers destination, category, summary, places and coordinate detection. **Billable.** | Nook runs its deterministic sample extractor and says so on screen. | https://aistudio.google.com/apikey |
| `YOUTUBE_API_KEY` | YouTube Data API v3. Fetches a video's **description**, which is where the addresses and prices are — the difference between "Kyoto" and five named cafes. Free tier, no billing account. | YouTube extraction works from the title and channel alone. | Enable [YouTube Data API v3](https://console.cloud.google.com/apis/library/youtube.googleapis.com) |
| `FACEBOOK_TOKEN` | `APP_ID\|CLIENT_TOKEN` from a Meta app with the **oEmbed Read** feature. The only way to read an Instagram or Facebook post's caption at all — both withdrew public oEmbed in October 2020. | Those two extract from the URL alone, and the prompt tells the model it is working blind. | [developers.facebook.com/apps](https://developers.facebook.com/apps) → Settings → Advanced |
| `GEMINI_MODEL` | Optional model id to pin, e.g. `gemini-flash-lite-latest`. Not a secret. | Nook asks the API which models your key can reach and ranks them. | — |

YouTube and TikTok need no key for their public oEmbed, and the map needs none
at all.

### Turning on real extraction

1. Get a key at https://aistudio.google.com/apikey.
2. Put it in `.env` at the root of the project: `GEMINI_API_KEY=your-key-here`
3. Restart the app — `.env` is read once at startup, so a hot reload will not
   pick it up.

**Profile → Settings** shows which extractor is running, so you can confirm the
key was found without saving anything. Paste Link says so too, before you spend
a link finding out.

**No key is ever deployed.** None of the three is a repository secret or a
`--dart-define`. Anyone can read a value compiled into a web build and spend the
quota behind it, so the published site runs without one. See below.

## The published build, and what it does differently

The live link is built by GitHub Actions and served from GitHub Pages. It ships
with **no keys at all**, so extraction there is handled by a deterministic sample
extractor: the same link always produces the same result, and the app labels it
*"Sample data — this build ships without an AI key"* on the screen where it
matters. The YouTube and Meta lookups are likewise unconfigured, so the published
site makes no keyed request to anyone. Real Gemini extraction runs locally and is
shown in the demo video.

One interface, two implementations, chosen at startup by whether a key is
present — the same fallback pattern the proposal planned for the map feature.

## Privacy and secrets

- **What is stored, and where.** A local profile (name, optional photo), saved
  posts, trips, recent searches and four settings — all in a Drift database on
  the device. Nothing is uploaded, shared or synced. There is no account and no
  server.
- **What leaves the device, and when.** Only when you tap Analyze, and only the
  link plus what the platform has already published about it. No analytics, no
  telemetry, no crash reporting.
- **Where the secrets live.** `.env`, which is git-ignored — and was ignored
  from the very first commit, before any such file existed. The deploy workflow
  creates a keyless `.env` from `.env.example` at build time, so the published
  build has nothing to leak.
- **Deleting.** Posts and trips go to Recently Deleted for 30 days and can be
  restored; permanent deletion removes the row. "Delete my profile" on the
  Account screen clears everything you saved. Since nothing is stored anywhere
  else, that is the whole deletion process.
- **Sample data.** Every trip, post, handle and link in the seeded library is
  invented. No real personal information appears in this repository, in the
  screenshots or in the video.

The full audit — every item checked against the code, including the seven that
are **not** clean — is [SECURITY-CHECKLIST.md](SECURITY-CHECKLIST.md).

## Project documentation

| Document | |
| --- | --- |
| [Proposal](docs/01-proposal.md) | the problem, the users, the scope, the storage decision |
| [Mockup and wireframes](docs/02-mockup.md) | the screens and the flow between them |
| [Design system](docs/03-design-system.md) | palette, type scale, spacing, components |
| [Weekly reports](docs/04-weekly-reports.md) | the development history, week by week |
| [Demo video](docs/05-demo-video.md) | the recording and what it shows |
| [Security and privacy](docs/06-security-and-privacy.md) | why the data and the keys are handled this way |
| [Security checklist](SECURITY-CHECKLIST.md) | the audit, item by item, with the open items listed |

## Status and what is next

**Working:** every screen in the mockup, plus a Trips tab and Trip Details that
the mockup never drew. Save by link, by share, or as a note; detection with an
editable result; trips with folder colours; search; personal notes; moving posts;
an interactive map; Recently Deleted with restore and a 30-day window; the local
profile; export; and the demo library.

**Deliberately not built:**

- **Itinerary generator** — stretch goal #3. The button is drawn and disabled,
  with a line saying why.
- **Connected Platforms** — stretch goal #1, and auto-sync needs each platform's
  API. The screen exists as drawn, disabled, and says so.
- **Sharing a post out of Nook** — the share button on Post Details is drawn but
  inert. (Sharing *into* Nook works; see the Web Share Target above.)
- **Instagram and Facebook thumbnails without a token** — both retired their
  public oEmbed endpoints in 2020, so a preview image needs `FACEBOOK_TOKEN`.
  Without one those saves keep the drawn placeholder. YouTube thumbnails are
  derived from the video id and need no key; TikTok comes from its public oEmbed.

**Known limits.**

- **Extraction quality depends on what the platform publishes.** With
  `YOUTUBE_API_KEY` a YouTube post arrives with its full description and extracts
  well. Without a token, an Instagram or Facebook link is read from its URL
  alone, and an opaque URL may come back without a destination — which is why
  every field is optional and editable.
- **The 40-link extraction test is still outstanding.** Ten real links per
  platform, logging how often a usable destination comes back. It is the
  mitigation the proposal committed to for its biggest risk and it needs a normal
  network and a key.
- **Two documented gaps** in deletion and export are recorded as open items 1 and
  2 in [SECURITY-CHECKLIST.md](SECURITY-CHECKLIST.md).

## Credits

- Packages: see `pubspec.yaml`
- Typefaces: [Manrope](https://github.com/sharanda/manrope) by Mikhail Sharanda and [Instrument Serif](https://github.com/Instrument/instrument-serif) standing in for PP Editorial New, which is licensed and cannot be committed — both SIL Open Font License 1.1
- Icons: Material Icons, Apache License 2.0
- Platform logos: [Font Awesome Free](https://fontawesome.com) brand icons, CC BY 4.0
- Map tiles: © OpenStreetMap contributors, ODbL

## AI use

Claude (Anthropic) was used as a pair programmer for this project: turning the
proposal, mockup and design system into an implementation plan, then writing code
against that plan under review. The planning documents, the design and the
decisions behind them are the author's own; where the three source documents
contradicted each other, the resolutions were chosen by the author. Those twelve
decisions were recorded in a working build plan during weeks 2 and 3; the
outcomes of all of them are visible in the app and summarised in the
[weekly reports](docs/04-weekly-reports.md).

## Licence

MIT, see [LICENSE](LICENSE).
