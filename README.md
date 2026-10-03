# Nook

> Never lose your next favourite find. Nook saves the travel content you find on
> TikTok, Instagram, Facebook and YouTube in one place — grouped by trip, and
> searchable across every platform — for travellers whose trip research is
> currently scattered across four apps.

**Live demo:** https://alyencs.github.io/nook-flutter/
**Demo video:** `docs/demo.mp4` (link it here once it exists)
**Course:** Applications Development and Emerging Technologies (6ADET), Holy Angel University
**Author:** Alison C. Sampang

This repository lives in the author's own GitHub account and is public on
purpose. There is no `student.json` here and there should not be one: see
[`docs/06-security-and-privacy.md`](docs/06-security-and-privacy.md) for what a
public repo means for secrets and personal data, and
[`SECURITY-CHECKLIST.md`](SECURITY-CHECKLIST.md) for the audit behind it.

---

## Screenshots

| Onboarding | Set up profile | Home |
| --- | --- | --- |
| ![Onboarding](docs/assets/screen-onboarding.png) | ![Set up profile](docs/assets/screen-profile-setup.png) | ![Home](docs/assets/screen-home.png) |

| Search results | Post details | Recently Deleted |
| --- | --- | --- |
| ![Search results](docs/assets/screen-search-results.png) | ![Post details](docs/assets/screen-post-details.png) | ![Recently Deleted](docs/assets/screen-recently-deleted.png) |

*Captured from the current build at 390×844 on a 3× screen. The machine they were
taken on cannot reach Wikimedia Commons or OpenStreetMap, so the seeded
destination photographs fall back to the placeholder each card is designed to
show, and Travel Details is not included because its map would have rendered as
an error rather than a map. The live link renders both.*

## What it does

- **Paste a link to save it** — TikTok, Instagram, Facebook or YouTube. The
  platform is recognised from the URL. Nook is also a Web Share Target, so once
  it is installed to a home screen you can share straight into it and analysis
  has already started by the time the app opens.
- **Detection reads the post, not just the link.** Nook fetches what the platform
  publishes — a YouTube title and description, a TikTok caption — and hands that
  to Gemini, which returns the place, a category, a summary, the country, the
  best time to visit, a rough budget, the venues the post named and its tips.
  Anything it cannot tell you is left blank rather than invented.
- **Group saves into trips** with coloured folders, and see where a save is on a
  map you can drag, pinch and zoom.
- **Search across everything** — titles, creators, destinations, countries,
  categories and your own notes, in one field.
- **Delete without losing anything.** Deleted posts and trips wait in Recently
  Deleted for 30 days and can be restored.

## Built with

| | |
| --- | --- |
| Framework | Flutter (Dart), web target |
| State | `setState` plus Drift stream queries read through `StreamBuilder` — no state-management package, because every screen reads one query and a package would be ceremony |
| Storage | [Drift](https://drift.simonbinder.eu) — on-device SQL, five tables at schema version 7, works on web. Chosen over Hive because a post belonging to exactly one trip is a foreign key, not a key-value pair |
| Other packages | `http` (Gemini's REST API and the oEmbed lookups — the official SDK was dropped because it hid the HTTP status code), `flutter_map` + `latlong2` (OpenStreetMap tiles, no key and no billing account), `flutter_dotenv` (keys out of git), `image_picker` (profile photo), `url_launcher`, `font_awesome_flutter` (platform brand marks), `device_preview` (phone frame on the live link) |

Storage is on the device and nowhere else, deliberately: two travellers never
need to see the same saved posts, so a server would be work for nothing. The
trade-off accepted is that saves do not sync between devices. The five tables are
`users`, `trips`, `saved_posts`, `recent_searches` and `app_settings`; the
reasoning is in [`docs/01-proposal.md`](docs/01-proposal.md).

## Running it yourself

```bash
flutter pub get
cp .env.example .env      # required, even left empty — see below
flutter run -d web-server --web-port 8080
```

Then open http://localhost:8080. Built and tested with **Flutter 3.47.2 /
Dart 3.13.2**; `pubspec.yaml` requires Dart `^3.8.0`. This is a web-only project
— there is no `android/` or `ios/` directory.

`.env` is listed as an asset in `pubspec.yaml` (that is how `flutter_dotenv`
reads it), so **the file has to exist before the app will build**, even empty.
Every value in it is optional; Nook runs with none of them set, and first launch
seeds a small fictional demo library so the app opens looking like the design.

```bash
flutter analyze    # clean
flutter test       # 279 tests
flutter build web --release
dart run build_runner build --delete-conflicting-outputs   # after editing lib/data/tables.dart
```

### Environment variables

This project reads its configuration from a `.env` file that is **not** in the
repository. Copy `.env.example`, fill in your own values, and never commit the
result.

| Variable | What it is | Where to get one |
| --- | --- | --- |
| `GEMINI_API_KEY` | Powers destination, category, summary and coordinate detection. **Billable.** Without it Nook runs a deterministic sample extractor and says so on screen. | https://aistudio.google.com/apikey |
| `YOUTUBE_API_KEY` | YouTube Data API v3. Fetches a video's description — where the addresses and prices are — and the creator's profile picture. Free tier, no billing account. Without it, extraction works from the title alone. | [Enable YouTube Data API v3](https://console.cloud.google.com/apis/library/youtube.googleapis.com) |
| `FACEBOOK_TOKEN` | `APP_ID\|CLIENT_TOKEN` from a Meta app with **oEmbed Read**. The only way to read an Instagram or Facebook caption — both withdrew public oEmbed in 2020. Without it those two extract from the URL alone, and the prompt says so. | [developers.facebook.com/apps](https://developers.facebook.com/apps) → Settings → Advanced |
| `GEMINI_MODEL` | Optional model id to pin. Not a secret. Without it Nook asks the API which models the key can reach. | — |

**No key is ever deployed.** None of these is a repository secret or a
`--dart-define`. Anyone can read a value compiled into a web build and spend the
quota behind it, so the GitHub Pages build is created from a keyless
`.env.example` and runs the sample extractor. Real extraction runs locally and is
shown in the demo video.

## Privacy and secrets

- **What is stored.** A local profile (a name and an optional photo), saved posts,
  trips, recent searches and four settings toggles — all in a Drift database on
  the device. Nothing is uploaded, shared or synced. There is no account and no
  server, so there is no service side to protect: no Firestore rules, no Supabase
  RLS, no credentials. The only thing that ever leaves the device is a link you
  asked Nook to analyse, plus what the platform has already published about it.
- **Where the secrets live.** `.env`, which is git-ignored — and was ignored from
  the very first commit, before any such file existed. The deploy workflow builds
  from a keyless `.env.example`, so the published site has nothing to leak.
- **No real personal information** appears in the sample data, the screenshots or
  the video. Every trip, post, handle and link in the seeded library is invented.

The full audit, including the open items, is
[`SECURITY-CHECKLIST.md`](SECURITY-CHECKLIST.md).

## Project documentation

| Document | |
| --- | --- |
| [Proposal](docs/01-proposal.md) | the problem, the users, the scope |
| [Mockup and wireframes](docs/02-mockup.md) | what it looks like, and the screen flow |
| [Design system](docs/03-design-system.md) | colours, type, spacing, components |
| [Weekly reports](docs/04-weekly-reports.md) | what happened each week |
| [Demo video](docs/05-demo-video.md) | the recording and what it shows |
| [Security and privacy](docs/06-security-and-privacy.md) | the checklist, filled in |
| [Security checklist](SECURITY-CHECKLIST.md) | the audit, item by item |
| [AI use](AI-USAGE.md) | the full account of how AI was used |

## Status and what is next

**Working:** every screen in the mockup, plus the Trips tab and Trip Details the
mockup never drew. Save by link, by share or as a note; detection with an
editable result; trips with folder colours; search; personal notes; an
interactive map; Recently Deleted with restore and a 30-day window; a local
profile with an adjustable photo crop; and a complete JSON export.

**Deliberately not built:** the itinerary generator and Connected Platforms are
stretch goals, drawn, disabled and labelled as such. Sharing a post *out* of Nook
is drawn but inert.

**Known issues, honestly:**

- **The 40-link extraction test is still outstanding.** Ten real links per
  platform, logging how often a usable destination comes back. It is the
  mitigation the proposal committed to for its biggest risk, and it needs a
  normal network and a key.
- **Creator profile pictures are YouTube-only.** Of the four platforms, only
  YouTube exposes an avatar through a route Nook can legitimately use, and only
  with a `YOUTUBE_API_KEY`. Everywhere else the UI draws the creator's initial
  rather than inventing a face.
- **Instagram and Facebook need a token for anything beyond the URL.** Without
  `FACEBOOK_TOKEN` those saves keep the drawn placeholder and extract from the
  link alone.
- **Extraction quality still depends on what the platform publishes.** An opaque
  URL may come back without a destination, which is why every field is optional
  and editable.

## Credits

- Packages: see `pubspec.yaml`
- Nook logo: the author's own. The splash mark in `assets/images/` is cut from
  the supplied `nook_logo.png` along its own gutters — the four crops reassemble
  into that file exactly.
- Typefaces: [Manrope](https://github.com/sharanda/manrope) by Mikhail Sharanda,
  and [Instrument Serif](https://github.com/Instrument/instrument-serif) standing
  in for PP Editorial New, which is licensed from Pangram Pangram and cannot be
  committed — both SIL Open Font License 1.1
- Icons: Material Icons, Apache License 2.0
- Platform logos: [Font Awesome Free](https://fontawesome.com) brand icons, CC BY 4.0
- Map tiles: © OpenStreetMap contributors, ODbL
- Seeded destination photographs: Wikimedia Commons, under their own licences

## AI use

![Built with AI assistance](https://img.shields.io/badge/built%20with-AI%20assistance-0b5fff)

**Claude (Anthropic), used heavily.** It wrote most of the code in `lib/` —
roughly 93% of it by line — working to my specification and under my review. The
planning is mine: the proposal, the mockup, the design system and the twelve
conflict resolutions between them. So is Nook's motion system, which I wrote and
tuned myself and which is about 69% mine by line. I reviewed what Claude produced
and rejected a fair amount of it, including a splash screen that assembled a logo
it had invented.

The full account — six examples of how I used it, three cases where it was
wrong, and the line-by-line authorship breakdown with the commands to reproduce
it — is in [AI-USAGE.md](AI-USAGE.md).

## Licence

MIT, see [LICENSE](LICENSE).
