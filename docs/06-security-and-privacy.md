# Security and privacy

This repository is public.

**Last checked:** 2026-10-03, against schema version 7.

This document explains *why* Nook handles data and secrets the way it does.
The line-by-line audit — every item checked, with the file that proves it and
the seven that are not clean — is [`SECURITY-CHECKLIST.md`](../SECURITY-CHECKLIST.md)
at the root of the repository. The two are meant to be read together and they
agree; where this one says "see the checklist", that is where the evidence is.

## What this app stores

| Data | Where it lives | Who can see it |
| --- | --- | --- |
| Local profile: name, optional photo | On the device, in a Drift (SQLite) database | Only that user |
| Saved posts: title, caption, creator (name, handle, page and profile picture), platform, URL, extracted travel metadata, personal note | Same local database | Only that user |
| Trips, including their folder colour | Same local database | Only that user |
| Recent searches | Same local database | Only that user |
| Four settings toggles | Same local database | Only that user |

Five tables — `users`, `trips`, `saved_posts`, `recent_searches`,
`app_settings` — at schema version 7, which added the creator's page URL and
profile picture. Nothing is uploaded, shared or synced.
There is no account, no server and no analytics. On the web the database lives
in the browser's own storage (IndexedDB or OPFS, whichever the browser
supports), which is per-origin and per-browser.

**Email is no longer collected.** Onboarding used to ask for one, framed as
creating an account. Nook stores everything on the device and talks to no
server, so there was never an account for an address to identify — it asks what
to call you and nothing else. Schema 4 relaxed `users.email` to nullable through
a table rebuild, because SQLite cannot drop a `NOT NULL` constraint in place.
The column still exists so that profiles created before the change keep what
they gave; nothing writes it and nothing reads it.

The profile photo is stored as a base64 data URI inside the local database
rather than as a file path, because `image_picker` returns bytes rather than a
path on the web. It does not leave the device either way.

The database is **not encrypted at rest**. It is a plain SQLite file, or browser
storage, protected by the device's own account and disk encryption and nothing
more. For saved links and travel notes that is proportionate, but anyone with
the unlocked device or the browser profile can read it.

## Deleting the data

This is the part that changed most since the first version of this document.
Deleting used to be immediate and final, with a confirmation dialog as the only
safety net — and a confirmation asks before you know you were wrong.

- **Deleting a post or a trip is reversible.** Both carry a `deleted_at`
  timestamp (schema 5) and move to **Recently Deleted**, under Profile. Every
  screen-facing query filters on that column, so the item leaves Home, search,
  its trip and the counts at once, while the row keeps its note, its extraction
  and its trip membership. Nothing is copied at any point, so restoring cannot
  duplicate anything — it is one write back.
- **Deleting a trip does not delete the posts in it.** That was always true and
  is now what the confirmation says.
- **Items age out after 30 days**, and the screen states the window per item
  ("Removed in 3 days"). The purge runs when Recently Deleted is opened rather
  than on a timer: Nook has no server and no scheduler, so an item can sit past
  its window on a device where that screen is never visited. It goes the moment
  the screen is next opened, and "Empty" destroys everything in it at once.
- **Permanent deletion is permanent.** "Delete permanently" on a row removes it.
  Since nothing is stored anywhere else, that is the whole deletion process —
  there is no copy on a server to request the removal of.
- **"Delete my profile"** on the Account screen empties all five tables in one
  batch, including anything soft-deleted, and the launch gate returns the app to
  onboarding on its own. `app_settings` is in that list now and was not always:
  the dialog said it erased everything on this device while four of five tables
  went, which left the next profile created on the device inheriting a stranger's
  toggles. The wipe was widened rather than the sentence narrowed.

Settings also has **Clear Search History** (empties `recent_searches`) and
**Clear Cache** (empties Flutter's image cache, the only cache Nook has).

## Exporting the data

**Export Data** in Settings writes the profile, trips, saved posts, searches and
settings to a JSON file — downloaded by the browser on the web, written to the
app's documents directory on a device. Nothing is uploaded.

It is now genuinely everything, and was not. The post columns added in schemas 3
to 7 — caption, creator handle, creator page and picture, source id, media type,
the specific location parts, places and highlights — were missing, as were a
trip's colour and both `deleted_at` columns, while the code comment claimed the
file held everything. An export is the thing a person reaches for when they want
their data out, so the export was widened to match the claim rather than the
claim narrowed to match the export. `places` and `highlights` are decoded back
into real JSON instead of being written as escaped strings, soft-deleted rows are
included with their timestamps, and `format_version` is 2 to mark the change.

## Secrets

Nook reads four values from `.env`. Three are credentials; one is not.

| Variable | What it is | Privileged | Needed to run |
| --- | --- | --- | --- |
| `GEMINI_API_KEY` | Extraction: destination, category, summary, coordinates | **Yes, billable** | No — without it the sample extractor runs, and says so |
| `YOUTUBE_API_KEY` | A YouTube video's description and the creator's channel picture, via the Data API | **Yes, quota-bearing** | No — without it extraction works from the title alone and no creator picture is available |
| `FACEBOOK_TOKEN` | `APP_ID\|CLIENT_TOKEN` for Meta's oEmbed endpoints | **Yes, app-scoped** | No — without it Instagram and Facebook extract from the URL alone |
| `GEMINI_MODEL` | An optional model id to pin | No | No — without it the app asks the API what the key can reach |

The last two arrived after this document was first written, and they are the
reason it needed re-checking rather than re-dating.

- **Where they live locally:** `.env`, which is git-ignored. `.gitignore` has
  ignored `.env` since the very first commit, before any such file existed in
  this repository, and `git log --all -- .env` confirms no commit has ever
  touched it.
- **Where the deploy workflow gets them:** it does not. None of the three is a
  repository secret and none is passed as a `--dart-define`. The workflow copies
  `.env.example` — which carries four empty values and no key — so the published
  build has nothing to leak and makes no keyed request at all.
- **What the deployed build carries that a visitor could read:** nothing
  sensitive. No backend URL, no publishable key, no project identifier, because
  there is no backend.
- **How they travel when they are set.** `GEMINI_API_KEY` is sent as an
  `x-goog-api-key` header. `YOUTUBE_API_KEY` and `FACEBOOK_TOKEN` are sent as
  query parameters, because that is the only form the YouTube Data API and the
  Meta Graph API accept. All three go over HTTPS. A query string is encrypted in
  transit but is visible in the browser's network inspector and to any proxy that
  terminates TLS, so prefer keys scoped to those two APIs and revoke them if a
  machine is shared.
- **The Meta value is a client token, not an app secret.** A client token is
  designed to be used from a client: it cannot read user data or change app
  settings. An app secret would be the wrong value and is never asked for.

### Why the keys are handled this way

A Gemini key is billable, and a YouTube key carries a quota. Anything compiled
into a web build is readable by anyone who opens the site, so shipping either
would let a stranger spend what is behind it. Two options were available: put a
server in front as a proxy, or keep the feature local. Nook keeps it local,
because a proxy would mean running a server for an app whose entire storage
argument is that it does not need one.

The consequence is designed for rather than hidden. `AiExtractor` has two
implementations and the one that runs is decided at startup by whether a key is
present. The published build runs `SampleExtractor` — deterministic, offline,
and labelled *"Sample data — this build ships without an AI key"* on the screen
where the extracted values appear. Real Gemini extraction runs locally and is
shown in the demo video. The same rule extends to the two newer values: absent,
the affected lookups simply do less, and the prompt tells the model it is
working blind rather than inviting it to invent what it cannot see.

## What leaves the device, and when

Only when the user taps **Analyze** on a pasted link, and only ever the link and
what the platform has already published about it:

| Host | Purpose | Credential |
| --- | --- | --- |
| `generativelanguage.googleapis.com` | Gemini extraction and model listing | `GEMINI_API_KEY`, as a header |
| `www.youtube.com/oembed` | Title, channel, thumbnail | none — public |
| `www.googleapis.com/youtube/v3` | The video description, then the channel's picture | `YOUTUBE_API_KEY`, as a query parameter |
| `www.tiktok.com/oembed` | Caption, author, thumbnail | none — public |
| `graph.facebook.com/v21.0` | Instagram and Facebook oEmbed | `FACEBOOK_TOKEN`, as a query parameter |
| `tile.openstreetmap.org` | Map tiles for a post that has coordinates | none — public |

Every call is HTTPS. There is no analytics, telemetry, crash reporting or
background sync anywhere in the app. The prompt sent to Gemini contains the
platform, the URL, the source id, the creator, the media type, the title and the
description — **not** the user's personal note, their profile, or any of their
other saved posts. A failed lookup degrades to URL-only metadata rather than
failing the save.

Instagram and Facebook withdrew public oEmbed in October 2020. Without
`FACEBOOK_TOKEN` those links reach the model as a URL plus whatever the path
itself says, and the prompt states outright that it is working blind. The
Connected Platforms screen says per platform how much of a post Nook can read,
because the four are genuinely not equivalent.

## The creator's profile picture

Added in schema 7, and null for most saves on purpose.

Of the four platforms, only **YouTube** exposes a creator's avatar through a
route Nook can legitimately use, and only with a `YOUTUBE_API_KEY`: the Data API
returns a channel's thumbnails when asked for them by channel id, which costs one
more call on the key already in use. TikTok's oEmbed returns the author's name
and page and nothing else about them. Instagram and Facebook return the same
through the Graph API — a profile picture there needs a different permission and,
for a person rather than a page, their consent.

So Nook asks YouTube, takes what it gives, and draws the creator's initial
everywhere else. It never derives a face from a handle, picks a stock portrait,
or generates one. The avatar URL is read from the platform and never from the
model: a language model asked for a creator's picture returns a convincing URL to
an image that does not exist.

## Logging, errors and extracted content

- **There is no logging.** `lib/` contains no `print`, `debugPrint` or
  `dart:developer` call, so no key, URL or note is ever written to a console.
- **Error messages carry nothing internal.** The screen is handed a phase, not a
  sentence; it used to receive "Asking gemini-flash-latest" and "Gemini is busy —
  retrying in 4s (attempt 2 of 4)", a vendor, a model id and a retry schedule, in
  front of someone who pasted a link. A test asserts that no failure mode can
  leak a vendor name, a model id or a status code again.
- **Nothing is ever faked.** Every failure path throws. `SampleExtractor` is
  reached only by having no key at all, and when it runs the UI says so.
- **Model output is parsed, not trusted.** The response is decoded against a
  fixed schema, every field is nullable, and unknown values are dropped. Text is
  rendered through `Text` widgets — there is no HTML renderer in this app, so a
  caption or summary has no script surface.
- **Coordinates are dropped rather than approximated.** A model asked for the
  coordinates of "Japan" returns the centre of Japan: true as a fact, false as a
  statement about the post. Anything broader than a city stores no coordinate and
  Travel Details shows the placeholder with the reason.
- **Requests are bounded.** Four attempts with exponential backoff and jitter,
  20s per attempt, 45s overall, `Retry-After` honoured, and in-flight extractions
  de-duplicated by URL so a second tap cannot start a second billable call.
  `thinkingBudget: 0` and a 2048-token ceiling are set on every request; left on,
  Gemini 2.5's default thinking was spending seconds and thousands of invisible
  tokens per extraction and generating the quota pressure it then reported as an
  outage. Cost control on a billable key is a security concern.
- **Opening a saved link uses the stored URL**, never one rebuilt from metadata,
  and refuses any non-`http`/`https` scheme. Nook does not check a saved URL for
  safety — it is a bookmark store and treats bookmarks as bookmarks.

## What protects the data on the service side

Nothing leaves the device, so there is no service side. No Firestore rules, no
Supabase RLS policies, no database credentials to manage.

## Permissions

Nook is a web-only Flutter project: there is no `android/`, `ios/`, `macos/`,
`windows/` or `linux/` directory, so there is no OS permission manifest and none
is declared. The only capability it uses is `image_picker`, which opens a file
input for the profile photo — a user gesture, not a standing permission. Nook
never asks the device for camera, microphone, location, contacts or
notifications. A map pin comes from the post's extracted destination, not from
where the user is.

## Personal data in this repository

- The demo library seeded on first run — trips, posts, creator handles, links,
  the profile name — is entirely invented. The handles (`@wanderwithmia`,
  `@backpackbetter`, and the rest) are not real accounts, and the URLs are
  illustrative rather than links to real posts.
- No student number appears anywhere in this repository, and there is no
  `student.json`. The private pointer in the course workspace is what matches
  this repository to its author.
- Screenshots and the demo video use only the seeded demo library.

## Checklist

The full audit is [`SECURITY-CHECKLIST.md`](../SECURITY-CHECKLIST.md). In
summary:

- [x] `.env` is git-ignored, was ignored from the first commit, and was never committed
- [x] `.env.example` contains placeholders only — four empty values, no key
- [x] No billable or privileged key reaches the deployed build
- [x] No repository secrets are required to build or deploy
- [x] No hardcoded secrets anywhere in `lib/`, `web/` or `test/`
- [x] No logging, and no vendor name, model id or status code in any user-facing error
- [x] No real personal data in the code, the seed data, the screenshots or the video
- [x] No `student.json`, no student number
- [x] Deletion is reversible for 30 days and permanent afterwards
- [x] `flutter analyze` is clean and 279 tests pass
- [x] Dependencies are pinned by `pubspec.lock`, which is committed
- [x] Deletion clears every table, and the export writes every column
- [ ] **Five open items** remain in the checklist, including an opportunistic
      retention purge, two credentials that travel in query strings, and live
      third-party calls that this environment could not exercise
