# Security and privacy

This repository is public.

**Last checked:** 2026-10-10, against schema version 7.

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

### The constraint everything here follows from

A Flutter web build is public in full. `main.dart.js` is a text file the
browser downloads; every bundled asset is fetched by URL. There is no private
region inside one, so a credential compiled into a published build is a
published credential, whatever it was called on the way in.

This rules out the hiding places that look like they should work:

| Attempt | Why it fails |
| --- | --- |
| A GitHub Actions secret, read at build time | The secret is compiled into the output and the output is what GitHub Pages serves. Masking it in the build log does not unpublish it. |
| A `--dart-define` on the deploy | Same thing by a different route: a define becomes a string constant in `main.dart.js`. |
| An asset file read at startup | An asset is served by URL. `nook.env` is downloadable at `/assets/nook.env`. |
| Obfuscating or splitting the value | The running app has to reassemble it, so the browser can too. This buys minutes, not security. |

The only arrangement that holds is for the key never to be in the build, which
means something else has to hold it. That is what `server/` is for.

### Where each value lives now

| Value | Privileged | Where it lives | Reaches the browser? |
| --- | --- | --- | --- |
| `ANTHROPIC_API_KEY` | **Yes, billable** | The AI service's encrypted environment, set with `wrangler secret put`. Write-only: it cannot be read back, only replaced. | **Never** |
| `AI_BACKEND_URL` | No — a public address | `nook.env`, or the `NOOK_AI_BACKEND` repository variable for the deploy | Yes, by design: the browser has to know where to knock |
| `CLAUDE_MODEL` | No | `nook.env`, or the service's own `[vars]` | Yes, and harmless |
| `YOUTUBE_API_KEY` | **Yes, quota-bearing** | A `--dart-define` on a local command only | Only in a local build, which must not be published |
| `FACEBOOK_TOKEN` | **Yes, app-scoped** | A `--dart-define` on a local command only | Only in a local build, which must not be published |

None of the three credentials is a repository secret, and the deploy workflow
passes no define carrying one. The workflow copies `.env.example` over
`nook.env`, which holds two empty settings and no credential field at all.

### How the separation is enforced rather than remembered

A rule that lives only in a document is one edit away from being gone, and the
failure is silent — the site still works, the key just starts shipping. So the
separation is checked in three places:

1. **No code path reads a credential from the bundle.** `NookAi` takes
   `ANTHROPIC_API_KEY`, `YOUTUBE_API_KEY` and `FACEBOOK_TOKEN` from
   `String.fromEnvironment` only; its `_env` helper, which reads the asset, is
   not reachable from any of them.
2. **A test asserts that absence.** `test/no_bundled_credential_test.dart`
   loads a bundle with all three credentials filled in, checks the app still
   falls back to the sample extractor and sample planner, and inspects the
   configuration source to confirm the only names read from the asset are
   `AI_BACKEND_URL` and `CLAUDE_MODEL`.
3. **The built output is scanned before it is published.**
   `tool/check_bundle.sh` greps the finished build for Anthropic and Google key
   formats and for any `*KEY`/`*TOKEN`/`*SECRET`/`*PASSWORD` assignment with a
   value in a bundled env file. The deploy workflow runs it as the last step
   before handing the build to Pages, and unlike `analyze` and `test` it is
   allowed to fail the run: a failing test costs a green tick, a published key
   costs an Anthropic balance and cannot be undone by pushing a fix.

### What the service will and will not do

The key being server-side moves the risk rather than removing it: the address
is public, so anyone who finds it can spend against the key unless the endpoint
is bounded. It is written as an allowlist — fields, models, tools, output size,
body size and rate are each capped, and a request naming no tool of Nook's is
refused, so the endpoint cannot be used as a general-purpose chat API. The full
table is in [`../server/README.md`](../server/README.md), including the two
limits worth stating plainly: the rate limit is per instance and in memory
rather than distributed, and CORS restricts browsers but not scripts.

Credential failures are never passed through as such. If the service's own key
is rejected, the caller is told the service is misconfigured — not that a key
was refused, which would confirm to a stranger that they had found a live
endpoint with a broken key.

### How the remaining credentials travel

`YOUTUBE_API_KEY` and `FACEBOOK_TOKEN` are sent as query parameters, because
that is the only form the YouTube Data API and the Meta Graph API accept. Both
go over HTTPS. A query string is encrypted in transit but is visible in the
browser's network inspector and to any proxy that terminates TLS, so prefer
keys scoped to those two APIs and revoke them if a machine is shared. These two
have not moved behind the service: they are only used on a local build, and
neither is billable in the way the Anthropic key is.

**The Meta value is a client token, not an app secret.** A client token is
designed to be used from a client: it cannot read user data or change app
settings. An app secret would be the wrong value and is never asked for.

### What a visitor to the deployed site can read

The service's address, the model id if one is pinned, and nothing else. With
the service configured, extraction and Explore Itinerary are real on the
published site — which they were not before, because the only way to have them
real used to be a key in the build.

Without the service configured, `AiExtractor` and `ItineraryGenerator` fall
back to `SampleExtractor` and `SampleItineraryGenerator` — deterministic,
offline, and labelled on the screens where their output appears. The same rule
extends to the two optional lookups: absent, they simply do less, and the
prompt tells the model it is working blind rather than inviting it to invent
what it cannot see.

## What leaves the device, and when

Only when the user asks for it — tapping **Analyze** on a pasted link, or
**Generate Itinerary** on a trip — and only ever the material described below:

| Host | Purpose | Credential |
| --- | --- | --- |
| Nook's AI service | Extraction, and Explore Itinerary generation. The request carries no credential; the service attaches the key and calls `api.anthropic.com` itself. | none from the browser |
| `api.anthropic.com` | The same, called directly — local builds only, never the deployed site | `ANTHROPIC_API_KEY`, as a header |
| `www.youtube.com/oembed` | Title, channel, thumbnail | none — public |
| `www.googleapis.com/youtube/v3` | The video description, then the channel's picture | `YOUTUBE_API_KEY`, as a query parameter |
| `www.tiktok.com/oembed` | Caption, author, thumbnail | none — public |
| `graph.facebook.com/v21.0` | Instagram and Facebook oEmbed | `FACEBOOK_TOKEN`, as a query parameter |
| `tile.openstreetmap.org` | Map tiles for a post that has coordinates | none — public |

Every call is HTTPS. There is no analytics, telemetry, crash reporting or
background sync anywhere in the app.

**The extraction prompt** contains the platform, the URL, the source id, the
creator, the media type, the title and the description — **not** the user's
personal note, their profile, or any of their other saved posts. A failed lookup
degrades to URL-only metadata rather than failing the save.

**The itinerary prompt is the one place a note does leave the device**, and only
when the user presses Generate Itinerary on a trip. It carries the posts saved
into *that* trip — their titles, captions, summaries, place names, areas, cities,
countries, best times, budget notes, tips and personal notes — plus the
destination and the number of days. It carries no profile, no search history,
and no post from any other trip. The screen names the trip and lists the posts
it will plan from before the button is pressed, so what is being sent is on
screen first.

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
  sentence, rather than a vendor name, a model id and a retry schedule in front
  of someone who pasted a link. A test asserts that no failure mode can leak a
  vendor name, a model id or a status code.
- **Nothing is ever faked.** Every failure path throws. `SampleExtractor` is
  reached only by having no key at all, and when it runs the UI says so.
- **Model output is parsed, not trusted.** Both features ask for structured
  output through a forced tool call, so the reply arrives as an object of a
  declared shape rather than prose. Every field is nullable, unknown values are
  dropped, and an itinerary that comes back with the wrong number of days, no
  days, or a field running to thousands of characters is reported or cut rather
  than rendered. Text is
  rendered through `Text` widgets — there is no HTML renderer in this app, so a
  caption or summary has no script surface.
- **Coordinates are dropped rather than approximated.** A model asked for the
  coordinates of "Japan" returns the centre of Japan: true as a fact, false as a
  statement about the post. Anything broader than a city stores no coordinate and
  Travel Details shows the placeholder with the reason.
- **Requests are bounded.** Extraction gets four attempts with exponential
  backoff and jitter, 20s per attempt and 45s overall; planning, being a bigger
  job, gets three attempts, 45s and 100s. `retry-after` is honoured over the
  computed backoff. Every request carries a `max_tokens` ceiling, so a reply
  cannot run until it times out. In-flight work is de-duplicated — extractions by
  URL, plans by destination and day count — so a second tap cannot start a second
  billable call. Cost control on a billable key is a security concern.
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

- [x] `nook.env` is git-ignored, was ignored from the first commit, and was never committed
- [x] `.env.example` has no credential field at all — two empty public settings
- [x] No billable or privileged key reaches the deployed build
- [x] No code path reads a credential from the bundled asset, and a test asserts it
- [x] The built output is scanned for credentials before it is published
- [x] No repository secrets are required to build or deploy
- [x] No hardcoded secrets anywhere in `lib/`, `web/` or `test/`
- [x] No logging, and no vendor name, model id or status code in any user-facing error
- [x] No real personal data in the code, the seed data, the screenshots or the video
- [x] No `student.json`, no student number
- [x] Deletion is reversible for 30 days and permanent afterwards
- [x] `flutter analyze` is clean, 383 Flutter tests pass and 31 service tests pass
- [x] Dependencies are pinned by `pubspec.lock`, which is committed
- [x] Deletion clears every table, and the export writes every column
- [ ] **Five open items** remain in the checklist, including an opportunistic
      retention purge, two credentials that travel in query strings, and live
      third-party calls that this environment could not exercise
