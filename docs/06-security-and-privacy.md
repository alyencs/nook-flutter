# Security and privacy

This repository is public.

**Last checked:** 2026-09-06

## What this app stores

| Data | Where it lives | Who can see it |
| --- | --- | --- |
| Local profile: name, email, optional photo | On the device, in a Drift (SQLite) database | Only that user |
| Saved posts: title, creator, platform, URL, extracted travel metadata, personal note | Same local database | Only that user |
| Trips | Same local database | Only that user |
| Recent searches | Same local database | Only that user |

Nothing is uploaded, shared or synced. There is no account, no server and no
analytics. On the web the database lives in the browser's own storage (IndexedDB
or OPFS, whichever the browser supports), which is per-origin and per-browser.

The profile photo is stored as a base64 data URI inside the local database
rather than as a file path, because `image_picker` returns bytes rather than a
path on the web. It does not leave the device either way.

**Deleting the data.** "Clear All Data" in Settings and "Delete my account" on
the Account screen both empty the database. Since nothing is stored anywhere
else, that is the whole deletion process — there is no copy on a server to
request the removal of.

## Secrets

- **Values the app needs at run time:** `GEMINI_API_KEY`, and optionally
  `GEMINI_MODEL`. Both are read from `.env`.
- **Where they live locally:** `.env`, which is git-ignored. `.gitignore` has
  ignored `.env` since before any such file existed in this repository.
- **Where the deploy workflow gets them:** it does not. `GEMINI_API_KEY` is
  deliberately **not** a repository secret and **not** passed as a
  `--dart-define`. The workflow creates a keyless `.env` by copying
  `.env.example`, so the published build has no key to leak.
- **What the deployed build carries that a visitor could read:** nothing
  sensitive. There is no backend URL, no publishable key and no project
  identifier, because there is no backend.

### Why the key is handled this way

A Gemini key is billable. Anything compiled into a web build is readable by
anyone who opens the site, so shipping the key would let a stranger spend the
quota behind it. Two options were available: put a server in front of it as a
proxy, or keep the feature local. Nook keeps it local, because a proxy would
mean running a server for an app whose entire storage argument is that it does
not need one.

The consequence is designed for rather than hidden: `AiExtractor` has two
implementations, and the one that runs is decided at startup by whether a key is
present. The published build runs `SampleExtractor` — deterministic, offline,
and labelled *"Sample data — this build ships without an AI key"* on the screen
where the extracted values appear. Real Gemini extraction runs locally and is
shown in the demo video.

## What protects the data on the service side

Nothing leaves the device, so there is no service side. No Firestore rules, no
Supabase RLS policies, no database credentials to manage.

## Personal data in this repository

- The demo library seeded on first run — trips, posts, creator handles, links,
  the profile name and email — is entirely invented. `alisampang@email.com` is a
  placeholder domain, not a mailbox. The handles (`@wanderwithmia`,
  `@backpackbetter`, and the rest) are not real accounts, and the URLs are
  illustrative rather than links to real posts.
- No student number appears anywhere in this repository, and there is no
  `student.json`. The private pointer in the course workspace is what matches
  this repository to its author.
- Screenshots and the demo video use only the seeded demo library.

## Checklist

- [x] `.env` is git-ignored and was never committed
- [x] `.env.example` contains placeholders only, no real values
- [x] No billable or privileged key reaches the deployed build
- [x] No repository secrets are required to build or deploy
- [x] No real personal data in the code, the seed data, the screenshots or the video
- [x] No `student.json`, no student number
- [x] `flutter analyze` is clean
- [x] Dependencies are pinned by `pubspec.lock`, which is committed
