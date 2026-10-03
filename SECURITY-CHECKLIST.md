# Security and privacy checklist

**Project:** Nook — Applications Development and Emerging Technologies (6ADET), Holy Angel University
**Repository:** public, in the author's own GitHub account
**Checked against:** commit `10464e3` plus the October fixes below, schema version 7
**Date:** 2026-10-03 (first audited 2026-09-27)

This is the audited version. Every line below was checked against the code in
this repository rather than assumed, and the four statuses mean different
things:

| | Meaning |
| --- | --- |
| **PASS** | Verified in the repository. The file and the check that proves it are named. |
| **N/A** | Does not apply to how Nook is built, with the reason. |
| **LIMIT** | Working as designed, with a consequence worth stating plainly. |
| **REVIEW** | A real gap, or something this container could not verify. Listed in full at the end. |

Nothing here is marked PASS because no problem was obvious. Where something
could not be verified from inside this sandbox — a live API call, a deployed
build — it says so rather than being given the benefit of the doubt.

---

## 1. Secrets and API keys

Nook reads four values from `.env`. Two are credentials, one is a key-shaped
value that is not privileged, and one is not a secret at all.

| Variable | What it is | Privileged? | Required? |
| --- | --- | --- | --- |
| `GEMINI_API_KEY` | Google AI Studio key for extraction | **Yes — billable** | No. Without it Nook runs `SampleExtractor` and says so on screen. |
| `YOUTUBE_API_KEY` | YouTube Data API v3 key, used to read a video's description and the creator's channel avatar | **Yes — quota-bearing** | No. Without it a YouTube post reaches the model as a title only, and no creator picture is available. |
| `FACEBOOK_TOKEN` | `APP_ID\|CLIENT_TOKEN` for Meta's oEmbed endpoints | **Yes — app-scoped** | No. Without it Instagram and Facebook links extract from the URL alone. |
| `GEMINI_MODEL` | An optional model id to pin | No — it is a configuration string | No. Without it the app asks the API which models the key can reach. |

- [x] **PASS — `.env` is git-ignored, and was from the first commit.**
      `.gitignore:2-4` has carried `.env`, `.env.*` and `!.env.example` since
      `fee2a36` (2026-08-28), which is before any `.env` existed in this
      repository. Verified with `git log --all -- .env`: no commit has ever
      touched it.
- [x] **PASS — `.env` has never been committed, in any branch.**
      `git ls-files` lists `.env.example` and nothing else matching `.env*`.
- [x] **PASS — `.env.example` contains placeholders only.**
      All four variables are present with empty values and a comment explaining
      each. There is no key, token or id in the file.
- [x] **PASS — no hardcoded secrets anywhere in the source.**
      Scanned `lib/`, `web/` and `test/` for Google (`AIza…`), Meta (`EAA…`) and
      generic `api_key = "…"` shapes. The only match is a 1×1 base64 PNG used as
      a test fixture in `test/map_test.dart:115`.
- [x] **PASS — all four values are read at run time, never compiled in.**
      `lib/ai/ai_config.dart` is the only reader. It pulls each one from
      `dotenv.env` and treats missing, empty and `put_your…` placeholder values
      as absent.
- [x] **PASS — no `--dart-define` carries a secret.**
      `.github/workflows/deploy-web.yml` builds with `--base-href` and nothing
      else.
- [x] **PASS — no repository secrets exist or are needed.**
      The workflow references no `secrets.*` value. It runs
      `cp .env.example .env` before building, so the runner never holds a key.

### Client-side exposure

- [x] **PASS — the deployed build ships no credentials.**
      GitHub Pages serves a build whose `.env` came from `.env.example`. With no
      `GEMINI_API_KEY`, `NookAi.createExtractor()` returns `SampleExtractor`, and
      the UI labels the result *"Sample data — this build ships without an AI
      key"*. The YouTube and Facebook lookups are likewise unconfigured, so the
      published site makes no keyed request at all.
- [x] **LIMIT — any key placed in `.env` is readable by anyone who opens that
      build.** This is a property of client-side Flutter, not a defect: a web
      build is JavaScript served to the browser, and `flutter_dotenv` bundles
      `.env` as an asset. It is precisely why the deployed build is keyless and
      why real extraction is demonstrated on video instead. Anyone running Nook
      locally with their own key is exposing only their own key, to themselves.
- [x] **LIMIT — two of the three credentials travel in a query string.**
      `GEMINI_API_KEY` is sent as an `x-goog-api-key` **header**
      (`lib/ai/gemini_api.dart:268-269`), which is the better shape.
      `YOUTUBE_API_KEY` is sent as `?key=…` to `googleapis.com`
      (`lib/ai/source_metadata.dart:305-307`) and `FACEBOOK_TOKEN` as
      `?access_token=…` to `graph.facebook.com`
      (`lib/ai/source_metadata.dart:277-282`), because those are the only forms
      those endpoints accept. Both are HTTPS, so the query string is encrypted in
      transit, but it is visible in the browser's own network inspector and may
      be recorded by any proxy that terminates TLS. Consequence: on a shared or
      managed machine, prefer keys that can be revoked and are scoped to these
      two APIs.
- [x] **PASS — the Meta value is a client token, not an app secret.**
      `.env.example` instructs `APP_ID|CLIENT_TOKEN` from Settings → Advanced.
      A client token is designed to be used from a client and cannot read user
      data or change app settings. An app *secret* would be the wrong value here
      and is never asked for.

---

## 2. Third-party APIs

Nook talks to five hosts, all over HTTPS, all at the user's initiative.

| Host | Purpose | Credential | Triggered by |
| --- | --- | --- | --- |
| `generativelanguage.googleapis.com` | Gemini extraction and model listing | `GEMINI_API_KEY` (header) | Tapping **Analyze** on Paste Link |
| `www.youtube.com/oembed` | Title, channel, thumbnail | None — public | Saving a YouTube link |
| `www.googleapis.com/youtube/v3` | The video description | `YOUTUBE_API_KEY` (query) | Saving a YouTube link, if configured |
| `www.tiktok.com/oembed` | Caption, author, thumbnail | None — public | Saving a TikTok link |
| `graph.facebook.com/v21.0` | Instagram / Facebook oEmbed | `FACEBOOK_TOKEN` (query) | Saving an Instagram or Facebook link, if configured |
| `tile.openstreetmap.org` | Map tiles | None — public | Opening Travel Details or the full map |

- [x] **PASS — every outbound call is HTTPS.** `lib/ai/gemini_api.dart:164`,
      `lib/ai/source_metadata.dart:269-283, 305`, `lib/widgets/post_map.dart`.
      There is no `http://` endpoint in the app.
- [x] **PASS — nothing is sent anywhere unless the user asks for it.**
      No analytics, no telemetry, no crash reporting, no background sync. The
      only network traffic is a link lookup the user started and the map tiles
      for a post they opened.
- [x] **PASS — what leaves the device is the link and what the platform already
      published about it.** The prompt sent to Gemini is built in
      `lib/ai/source_metadata.dart#toPromptBlock`: platform, URL, source id,
      creator, media type, title and description. The user's own personal note,
      their profile and their other saved posts are never included.
- [x] **PASS — Instagram and Facebook are handled honestly when unconfigured.**
      Both withdrew public oEmbed in October 2020. Without `FACEBOOK_TOKEN`,
      `SourceMetadata.endpointFor` returns null, extraction proceeds from the URL
      alone, and the prompt states that the model is working blind rather than
      inviting it to invent a caption.
- [x] **PASS — the Connected Platforms screen tells the truth.**
      `lib/screens/profile/connected_platforms_screen.dart` is drawn as designed
      with every control disabled and a "Stretch goal — not in this build" note,
      and states per platform how much of a post Nook can read. It does not imply
      the four platforms behave alike, because they do not.
- [x] **LIMIT — a failed lookup degrades, it does not fail.**
      A timeout or non-200 from any oEmbed or Data API call returns the URL-only
      metadata (`catch (_) { return source; }`). The user gets a weaker
      extraction rather than an error. The trade is deliberate; it also means a
      silently blocked host looks like a vague result.
- [ ] **REVIEW — live third-party responses were not exercised here.**
      This container's proxy denies CONNECT to youtube.com, tiktok.com,
      graph.facebook.com and every tile host, and holds no Gemini key. All five
      integrations were tested against their documented payloads with a scripted
      HTTP client at the network boundary (`test/gemini_test.dart`,
      `test/source_metadata_test.dart`, `test/platforms_test.dart`,
      `test/map_test.dart`). Behaviour against the real services should be
      confirmed on a normal network before submission.

---

## 3. Authentication and sessions

- [x] **N/A — there is no authentication, because there is no server.**
      `Users` in `lib/data/tables.dart` has `name`, an unused nullable `email`
      and an optional photo. There is no password column, no token, no session
      and nothing to authenticate against. This is a local profile, not an
      account.
- [x] **PASS — onboarding stopped collecting an email address.**
      Nook talks to no server, so there was never an account for an address to
      identify. Schema 4 relaxed `users.email` to nullable through a table
      rebuild; nothing writes it and nothing reads it. Profiles created before
      that keep what they gave, which is why the column still exists.
- [x] **N/A — no OAuth, no third-party sign-in, no "Connect account" flow is
      live.** Connected Platforms is drawn and disabled.

---

## 4. Local database and storage

- [x] **PASS — one Drift (SQLite) database on the device, five tables, schema
      version 7.** `users`, `trips`, `saved_posts`, `recent_searches`,
      `app_settings` — `lib/data/database.dart:9`. Version 7 added the creator's
      page URL and profile picture. On the web it lives in the
      browser's own storage (IndexedDB or OPFS, whichever the browser supports),
      which is per-origin and per-browser.
- [x] **PASS — nothing is uploaded, shared or synced.** There is no backend URL
      anywhere in the repository, so there is no service side to secure: no
      Firestore rules, no Supabase RLS, no database credentials.
- [x] **PASS — foreign keys are enforced, not assumed.**
      `PRAGMA foreign_keys = ON` in `beforeOpen`, with explicit
      `customConstraint` SQL, because drift's `references()` generated no
      `REFERENCES` clause. `test/dao_test.dart` asserts a post cannot point at a
      trip that does not exist.
- [x] **PASS — migrations are guarded and tested.** `onUpgrade` steps v1→v6 and
      checks `sqlite_master` and `PRAGMA table_info` before each change, because
      two different on-disk shapes are both stamped "version 1".
      `test/migration_test.dart` builds a genuine v1 database with raw `sqlite3`
      and asserts the upgrade.
- [x] **LIMIT — the database is not encrypted at rest.**
      It is a plain SQLite file, or browser storage, protected by the device's
      own account and disk encryption and nothing else. For the data Nook holds
      — saved links and travel notes — this is proportionate; it is stated rather
      than glossed over. Anyone with the unlocked device, or with access to the
      browser profile, can read it.
- [x] **LIMIT — the profile photo is stored as a base64 data URI inside the
      database,** not as a file path, because `image_picker` returns bytes rather
      than a path on the web. It does not leave the device either way, and it is
      included in an export.

---

## 5. User data and privacy

- [x] **PASS — what is stored is only what the user entered or saved.**
      A name, an optional photo, the links they saved with the metadata
      extraction returned, their own notes, their trips, their recent searches
      and four settings toggles.
- [x] **PASS — no real personal data is in this repository.**
      The seeded demo library in `lib/data/seed.dart` — trips, posts, handles,
      URLs, the profile name — is invented. `@wanderwithmia` and the rest are not
      real accounts.
- [x] **PASS — no student number and no `student.json`.** The private pointer in
      the course workspace is what matches this repository to its author.
- [x] **PASS — screenshots and the demo video use only the seeded demo library.**

---

## 6. Data retention, deletion and export

- [x] **PASS — deleting is reversible, and nothing is copied to make it so.**
      Posts and trips carry `deleted_at` (schema 5). Every screen-facing query
      filters on it, so a deleted post leaves Home, search, its trip and the
      counts at once, while the row — its note, its extraction, its trip id —
      stays intact. Restoring is one write back, so nothing can be duplicated.
- [x] **PASS — Recently Deleted states its own retention.** 30 days,
      `RecentlyDeletedScreen.retention`, shown on screen per item ("Removed in 3
      days") rather than left to be discovered.
- [x] **LIMIT — the 30-day purge runs when the Recently Deleted screen is
      opened, and only then.** `didChangeDependencies` calls
      `purgeDeletedBefore(now - 30 days)` on both DAOs. There is no background
      job — Nook has no server and no scheduler — so an item can sit past its
      window on a device where that screen is never visited. It is deleted the
      moment the screen is next opened. "Empty" on that screen destroys
      everything in it immediately.
- [x] **PASS — permanent deletion is genuinely permanent.**
      `deletePostForever` / `deleteTripForever` remove the row. Since nothing is
      stored anywhere else, that is the whole deletion process: there is no copy
      on a server to request the removal of.
- [x] **PASS — "Delete my profile" erases the user's content.**
      `NookDatabase.clearAll()` (`lib/data/database.dart:179`) empties
      `saved_posts`, `trips`, `users` and `recent_searches` in one batch,
      including anything soft-deleted, and the launch gate returns the app to
      onboarding on its own.
- [x] **RESOLVED — `clearAll()` now clears `app_settings` too.**
      It did not, so "Delete my profile" left the Settings toggles behind while
      the dialog said it erased everything on this device. Two ways to settle
      that: soften the dialog, or make the wipe match it. The wipe matches it —
      a settings row is the user's own choice about their own library, and a
      device handed on should come back at defaults rather than remembering
      preferences nobody can see. Anything absent falls back to
      `NookSettings.defaults`, so emptying the table *is* the reset.
      `lib/data/database.dart#clearAll`.
- [x] **RESOLVED — "Export Data" now exports the whole database.**
      It wrote the columns `saved_posts` had when the feature was first built and
      never grew with it, so thirteen post columns added in schemas 3 to 7 — the
      caption, the handle, the source id and media type, the whole
      specific-location chain, the named places and highlights, the creator's
      page and picture — were silently absent, along with a trip's colour and
      both `deleted_at` columns. Its own comment claimed it wrote everything.
      Again two options: narrow the sentence or widen the export. The export is
      widened, because the honest version of a personal-data export is the
      complete one. `places` and `highlights` are decoded back into real JSON
      rather than exported as escaped strings, soft-deleted rows are included
      with their timestamps, and `format_version` is 2 to mark the change.
      `lib/data/export_service.dart`.

- [x] **PASS — the export never leaves the device.**
      On the web the browser downloads it; on a device it is written to the app's
      documents directory (`export_web.dart` / `export_io.dart`). Nothing is
      uploaded.
- [x] **PASS — "Clear Search History" and "Clear Cache" do what they say.**
      The first empties `recent_searches`; the second empties Flutter's image
      cache, which is the only cache Nook has.

---

## 7. Network, logging and error messages

- [x] **PASS — there is no logging.** `lib/` contains no `print`,
      `debugPrint` or `dart:developer` call. Nothing writes a key, a URL or a
      user's note to a console or a file.
- [x] **PASS — error messages carry nothing internal.**
      `ExtractionPhase` has three values and the screen chooses the words, so
      backend vocabulary cannot reach the UI by accident.
      `test/gemini_test.dart:948` asserts that **no failure mode leaks a vendor
      name, a model id or a status code**. Messages are plain English with
      something to do next.
- [x] **PASS — a failed extraction cannot silently become fake data.**
      Every failure path throws. `SampleExtractor` is reached only by having no
      key at all, and when it runs the UI says so.
- [x] **PASS — extraction requests are bounded.** Four attempts, exponential
      backoff with equal jitter, an 8s cap per wait, 20s per attempt and 45s
      overall (`lib/ai/gemini_api.dart:120-124`), honouring `Retry-After`. Only
      408/425/429/5xx and requests that never landed are retried; a rejected key
      fails on the first attempt. In-flight extractions are de-duplicated by URL,
      so a second tap cannot start a second billable call.
- [x] **PASS — `thinkingBudget: 0` and a 2048-token ceiling are set on every
      request** (`lib/ai/gemini_extractor.dart:276, 291`). Gemini 2.5 models
      think by default; left on, each extraction spent seconds and thousands of
      invisible tokens, which was generating the quota pressure it then reported
      as an outage. This is a cost control, and cost control on a billable key is
      a security concern.
- [x] **PASS — opening a saved link is constrained.**
      `lib/widgets/open_original.dart` uses the stored URL, never one rebuilt
      from metadata, and refuses any non-`http`/`https` scheme.

---

## 8. Externally retrieved content

- [x] **PASS — model output is parsed, not trusted.** The response is decoded as
      JSON against a fixed schema; every field is nullable and unknown values are
      dropped. A malformed or hostile response yields empty fields, not a crash
      and not an injected value.
- [x] **PASS — extracted text is rendered as text.** Flutter has no HTML
      renderer in this app: `Text` widgets draw strings. There is no `innerHTML`
      path, so there is no XSS surface for a caption or a summary.
- [x] **PASS — coordinates are dropped when they would be a false claim.**
      A model asked for the coordinates of "Japan" returns the centre of Japan —
      true as a fact, false as a statement about the post. Extraction drops
      latitude and longitude for anything broader than a city, and Travel Details
      shows the placeholder with the reason.
- [x] **PASS — thumbnails are remote images and nothing more.**
      A failed load falls back to the drawn placeholder.
- [x] **LIMIT — saved URLs are user-supplied and are not checked for safety.**
      Nook stores the link the user pasted and opens it in the platform's own
      browser when asked. It does no reputation or malware check — it is a
      bookmark, and it behaves like one.

---

## 9. Permissions

- [x] **PASS — this is a web-only Flutter project.** There is no `android/`,
      `ios/`, `macos/`, `windows/` or `linux/` directory, so there is no OS
      permission manifest to audit and none is declared.
- [x] **PASS — the only capability the app asks for is a file the user picks.**
      `image_picker` on the web opens a file input for the profile photo. That is
      a user gesture, not a standing permission, and the bytes stay in the local
      database.
- [x] **N/A — no camera, microphone, location, contacts or notification
      access.** Nook never asks the device where it is; a map pin comes from the
      post's extracted destination, not from the user.

---

## 10. Build and dependencies

- [x] **PASS — dependencies are pinned by `pubspec.lock`, which is committed.**
- [x] **PASS — no CDN dependency at run time.** A custom
      `web/flutter_bootstrap.js` loads CanvasKit from the app's own folder rather
      than Google's CDN, and both typefaces are bundled locally. The deployed
      build fetches no third-party script.
- [x] **PASS — `flutter analyze` is clean and 279 tests pass.**
- [x] **PASS — the deploy workflow has least-privilege permissions.**
      `contents: read`, `pages: write`, `id-token: write`.
- [x] **PASS — `google_generative_ai` was removed.** It raised 5xx as a
      formatted string, so the status code survived only inside the message
      shown to the user. Nook calls the REST endpoint over `http` and keeps the
      status, `error.status`, `details[].reason` and `Retry-After`.

---

## Known limitations, in one place

These are the items above that are **not** clean, gathered so nothing is buried:

**Two of the original seven are now fixed** — `clearAll()` and the export, both
above. Five remain:

1. **The retention purge is opportunistic.** 30-day expiry is enforced when
   Recently Deleted is opened, not on a timer. Correct for an app with no
   server; worth knowing.
2. **Two credentials travel in query strings.** Forced by the YouTube Data API
   and Meta Graph API. HTTPS protects them in transit; a TLS-terminating proxy
   or the browser's own inspector can still see them.
3. **The local database is not encrypted.** Device and browser-profile security
   is the only thing protecting it.
4. **Live third-party calls are unverified from this environment.** Every
   integration is tested against documented payloads with a scripted client;
   none has been exercised against the real service here. Confirm on a normal
   network.
5. **Saved URLs are not safety-checked.** Nook is a bookmark store and treats
   them as bookmarks.

---

## Sign-off

| | |
| --- | --- |
| Secrets in the repository | None. `.env` git-ignored since the first commit and never committed. |
| Secrets in the deployed build | None. The workflow builds from a keyless `.env.example`. |
| Personal data in the repository | None. The demo library is invented. |
| Data leaving the device | The pasted link and what the platform already published about it, only when the user taps Analyze. |
| Deletion | Reversible for 30 days, then permanent; "Delete my profile" now clears every table, matching its dialog. |
| Open items | Five, listed above. The two that were code decisions — the wipe and the export — have since been implemented. |

Companion document: [docs/06-security-and-privacy.md](docs/06-security-and-privacy.md),
which explains *why* the key handling is shaped this way. This file is the
audit; that one is the reasoning.
