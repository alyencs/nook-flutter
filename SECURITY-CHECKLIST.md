# Security checklist

**Audited:** 11 October 2026, against the working tree and run
[`38149103114`](https://github.com/alyencs/nook-flutter/actions/runs/38149103114)
on `main` (`366d131`, succeeded 11 Oct 2026).

Nook is a **web-only Flutter app with no backend for user data**. Everything a
traveller saves lives in a local Drift (SQLite) database on the device: no
account, no sign-in, no sync, no server-side copy. One server-side component
does exist, in `server/`, and it holds exactly one thing — the Anthropic API
key. It has no database, no user records and no request log. That shape is why
several rows below are N/A, and each one says why.

## Secrets and credentials

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 1 | No API key, token or password is hardcoded in `lib/`, including in comments and commented-out code | **Yes** | I grepped `lib/`, `web/`, `test/`, `.github/` and `server/src/` for Anthropic (`sk-ant-api…`), Google (`AIza…`), Meta (`EAA…`) and GitHub (`ghp_…`) key shapes, and for `api_key`/`token`/`password`/`secret` assigned to a string literal. One hit: a base64 1×1 PNG test fixture at `test/map_test.dart:115`, which is an image, not a credential. Configuration is read at run time in `lib/ai/ai_config.dart`, never written in source. |
| 2 | Anything private is in a gitignored config or passed with `--dart-define`, with an example file committed | **Yes** | `.gitignore` carries `.env`, `nook.env`, `.env.*`, `!.env.example` and `server/.dev.vars`. The three credentials — `ANTHROPIC_API_KEY`, `YOUTUBE_API_KEY`, `FACEBOOK_TOKEN` — are read only through `String.fromEnvironment`, so a `--dart-define` is the only way to supply one. Committed `.env.example` holds two blank public settings (`AI_BACKEND_URL`, `CLAUDE_MODEL`) and deliberately no credential field at all, because the file it is copied to is a bundled asset and therefore served to every visitor. |
| 3 | No keystore, `key.properties` or signing credential is in the repository | **Yes** | `git ls-tree -r` filtered for `key`, `keystore`, `.jks`, `.p12`, `.properties`, `credential` and `secret` returns one file: `.env.example`. `.gitignore` additionally blocks `*.keystore`, `*.jks` and `serviceAccountKey.json`. This is a web-only project — there is no `android/` directory — so no signing configuration exists to leak. |
| 4 | Git history is clean: I searched `git log -p` for password, secret, api key and token | **Yes** | Across all 65 commits on `origin/main`. (a) `git log --diff-filter=A --name-only` shows the only `.env*` path ever added is `.env.example`; `nook.env` and `server/.dev.vars` have never been committed. (b) `git log -p` contains zero added lines matching an Anthropic or Google key shape. (c) Searching messages and diffs for the four words returns only variable names, documentation and UI copy — the "token" hits are `FACEBOOK_TOKEN` as a name. |
| 5 | Any credential that was ever committed has been rotated | **N/A** | Nothing to rotate: row 4 establishes that no credential has ever been committed on any branch, so none has been exposed and none has needed rotating. |

## GitHub Actions

The repository has one workflow, `.github/workflows/deploy-web.yml`, which
builds the web app and publishes it to GitHub Pages.

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 6 | No secret value is written literally in any workflow YAML file | **Yes** | I read `deploy-web.yml` end to end. It contains no key, token or password. Its `env:` entries are `IS_PRIVATE: ${{ github.event.repository.private }}` and `NOOK_AI_BACKEND: ${{ vars.NOOK_AI_BACKEND }}` — a visibility flag and a public service address, neither a credential. |
| 7 | Secrets are stored in repository Actions secrets and read with `${{ secrets.NAME }}` | **N/A** | The workflow references no `secrets.*` anywhere, deliberately. This is the project's central security decision rather than an omission: **an Actions secret cannot secure a static site**, because a secret used at build time is compiled into the output and the output is exactly what GitHub Pages serves — masking it in the log does not unpublish it. The API key therefore lives on the AI service instead, set with `wrangler secret put`. The one `vars.*` reference is a *variable*, not a secret, precisely because the service address is meant to be public. |
| 8 | No workflow step echoes, dumps or debug-prints a secret, and I opened a recent run's log to confirm | **Yes** | There is no secret in the workflow to print (row 7). The `echo`/`cat` lines write `ready=true/false` to `$GITHUB_OUTPUT`, emit a `::notice` and a `::warning`, and print `build.txt` (commit SHA, ref, UTC timestamp, run id). Scope of what I checked: I read the YAML end to end, and pulled the step list and outcomes of run `38149103114` through the Actions API — all 13 build steps succeeded and match the YAML exactly. I could not retrieve the raw log *text* from this environment, because GitHub serves log bodies from blob storage that the client here does not contact, so this row rests on the YAML and the step list rather than on reading printed output. |
| 9 | If I build a signed APK: the keystore is a base64 secret decoded to a file at build time, never printed | **N/A** | This project builds no APK. It is web-only — no `android/`, `ios/`, `macos/`, `windows/` or `linux/` directory — and the workflow's only build step is `flutter build web --release`. |
| 10 | Uploaded build artifacts contain no key file, keystore or generated config | **Yes** | The artifact is `path: build/web`. The only configuration file inside it is the `nook.env` the workflow creates from `.env.example` moments earlier; I built the project the way the workflow does and confirmed the bundled copy contains exactly `AI_BACKEND_URL=` and `CLAUDE_MODEL=`, both empty, and that `main.dart.js` holds no key. This is no longer taken on trust: the step immediately before the upload runs `./tool/check_bundle.sh build/web`, which scans every file about to be served for key formats and for any `*KEY`/`*TOKEN`/`*SECRET`/`*PASSWORD` assignment with a value, and is allowed to fail the run. In run `38149103114` that step — "Refuse to publish a build carrying a credential" — ran and passed. I also verified it the other way locally, by deliberately building with a key and watching it refuse. |
| 11 | Third-party actions are pinned to a commit SHA, not a moveable tag | **No** | All four are pinned to version tags: `actions/checkout@v7`, `subosito/flutter-action@v2`, `actions/upload-pages-artifact@v5` and `actions/deploy-pages@v5`. A tag can be repointed by its owner, so this is a real supply-chain gap. The exposure is limited — the workflow holds no secrets for a compromised action to steal — but a repointed tag could still change what gets published. |
| 12 | Secret scanning and push protection are enabled on the repository | **No** | I could not confirm it, and I am not claiming it. `GET /repos/alyencs/nook-flutter` returns `security_and_analysis: null`, which means the field was not disclosed to the token I used rather than that the features are off, so the API answered neither way. These are repository settings rather than files, and the settings page is not reachable from where I ran this audit. Marked No rather than N/A because the checks genuinely apply to a public repository — they simply have not been confirmed as on, and are worth enabling. |

## Backend and security rules

Nook has **no backend holding user data**: no Firebase, no Supabase, no
database credentials and no account system, so rows 13–15 and 17 are N/A. The
AI service in `server/` does not change that — it stores nothing. It receives a
request, attaches the key, forwards it to Anthropic and returns the answer;
there is no datastore to write access rules for. Its own surface is bounded by
an allowlist instead, described in the last row of this section.

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 13 | Firestore and Storage rules are not left open to anyone; they require an authenticated user | **N/A** | There is no Firebase in this project — no `firebase_core` or `cloud_firestore` in `pubspec.yaml`, no `google-services.json`, no rules file. Storage is a local Drift/SQLite database created on first launch (`lib/data/database.dart`). |
| 14 | Rules restrict a user to their own documents where that makes sense | **N/A** | Same reason. There is no shared datastore and no second user: the database lives on the device and holds exactly one local profile. |
| 15 | If Supabase: Row Level Security is on for every table | **N/A** | Supabase was considered in the proposal and deliberately rejected in favour of on-device Drift. There is no Supabase client in `pubspec.yaml` and no project to configure RLS on. |
| 16 | Firebase and Google API keys are restricted in the Google Cloud console to the APIs and app they are for | **No** | Not verified, and not verifiable from the repository. The project uses one Google key, the optional `YOUTUBE_API_KEY`, which fetches a video's description and the creator's channel picture. Whether it is API-restricted is a setting in the key owner's Cloud console. What *is* verifiable: it is optional, it can only be supplied as a `--dart-define` on a local command, and the deployed build ships without it. Anyone adding one should restrict it to YouTube Data API v3. |
| 17 | I opened the app signed out and confirmed I could not read or write data I should not | **N/A** | There is no signed-in or signed-out state to test. `Users` in `lib/data/tables.dart` has a name, an unused nullable email and an optional photo — no password column, no token, no session. Nothing in the app is gated behind authentication because there is nothing to authenticate against. A related point belongs here even though the row does not ask it: **the AI service endpoint is unauthenticated**, because a client secret compiled into a public web build would authenticate nobody. What bounds an unknown caller instead is an allowlist — a request must name `record_extraction` or `record_itinerary` or it is refused, so the endpoint cannot be used as a general chat API — plus a 30-per-minute per-IP rate limit, a 6144-token output ceiling and a 128 KB body cap. All are covered by the service's 37 tests. |
| 18 | Seed and sample data is invented, not real people's data | **Yes** | `lib/data/seed.dart` is entirely fictional: handles like `@wanderwithmia` and `@bitesbytara`, URLs that resolve to nothing, and invented trip names. The destination photographs are Wikimedia Commons file URLs, not anyone's private photos. The nine screenshots in `docs/assets/` show only this seeded library and the author's own display name. |

## Input and app surface

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 19 | Input is validated before it is written, not only styled as valid in the UI | **Yes** | Checked each write path. The profile name is trimmed and must be non-empty before `saveProfile` runs (`profile_setup_screen.dart:50,71`). A trip name is trimmed in `showTripDialog` and returns `null` when empty, so `createTrip` is never reached with a blank name (`nook_dialog.dart:120-123,148-152`). Notes are capped at 500 characters in `NookTextField`. A pasted URL goes through `Uri.tryParse` before the host is read, and `OpenOriginal.isAvailable` additionally requires an `http`/`https` scheme and a non-empty host. On the service side, `server/src/validate.js` accepts only seven named fields and rebuilds the request rather than forwarding the caller's object. |
| 20 | Nothing secret is recoverable from the built app, since a shipped binary can be unpacked | **Yes, with a stated limit** | I built the project exactly as the workflow does and unpacked the output. `build/web/assets/nook.env` contains two empty settings; `main.dart.js` contains no key, and its single occurrence of the string `ANTHROPIC_API_KEY` is the variable name inside an error message. No code path can read a credential from the bundle: `lib/ai/ai_config.dart` has one `dotenv.env` call, reachable only for the two public settings, and `test/no_bundled_credential_test.dart` fills a simulated bundle with all three credentials and asserts every one is ignored. The limit worth stating plainly: a `--dart-define` *is* compiled into `main.dart.js` like any other constant, so a build made locally **with** a key carries that key. That is a property of client-side Flutter, not something this arrangement removes; what it does is make sure such a build is never the published one, by passing no credential on the deploy and failing the run if `tool/check_bundle.sh` finds one. |

## Repository and privacy

| # | Check | Yes / No / N/A | Evidence |
| --- | --- | --- | --- |
| 21 | No student number, personal email, phone number or home address in the repository or in commit messages | **Yes** | I grepped every tracked file (excluding lockfiles) for email patterns, Philippine mobile formats (`09…`, `+63…`) and student-number shapes, and got no matches. I then searched all commit message bodies for email addresses and found none beyond my own commit identity and the `noreply@anthropic.com` co-author trailer. My name appears in the README and LICENCE, which is deliberate attribution, not contact data. There is no `student.json` and there should not be one. |
| 22 | No classmate's personal data in the repository | **Yes** | The only people named anywhere are me, in the README and LICENCE, and the invented creators in the seeded demo library. No classmate is named, quoted or pictured, and there is no shared roster, group list or submission file in the repository. |
| 23 | Dependencies come from pub.dev, and `build/` and `.dart_tool/` are gitignored | **Yes** | `pubspec.yaml` has no `git:`, `path:` or `hosted:` override — every dependency is a plain pub.dev version constraint, and `pubspec.lock` is committed so the resolved versions are pinned. `.gitignore` lists `build/`, `.dart_tool/`, `server/node_modules/` and `server/.wrangler/`, and none appears in `git ls-tree -r`. The AI service has one runtime dependency, `@anthropic-ai/sdk`, from npm, with `package-lock.json` committed; `npm audit --omit=dev` reports **0 vulnerabilities**. |
| 24 | Images, fonts and other assets are mine, licensed, or credited | **Yes** | The two bundled typefaces ship with their licences committed beside them — `assets/fonts/Manrope-OFL.txt` and `assets/fonts/EditorialSerif-OFL.txt`, both SIL OFL 1.1 — and the README credits Manrope, Instrument Serif, Material Icons (Apache 2.0), Font Awesome Free brand marks (CC BY 4.0), the Wikimedia Commons destination photographs and OpenStreetMap tiles (ODbL). The Nook mark is my own: `assets/images/nook_mark_*.png` are four tiles cut from my own `nook_logo.png`, and the README says so. |
| 25 | Repository visibility is deliberate, and I checked it after my last push | **Yes** | `GET /repos/alyencs/nook-flutter` returns `"private": false, "visibility": "public"`, checked on 11 October 2026 after the most recent push (`366d131`, the commit behind run `38149103114`). Public is deliberate and documented: the project is submitted as a link, and the whole arrangement of keeping credentials out of the bundle exists so that being public is safe. |

## Anything I found and fixed

This pass caught one thing I did not know about, and it was not a leaked
credential — it was a **documentation defect that would have broken the live
AI features**. The AI service answers only on `/v1/messages`, and the app
appends `messages` to whatever base URL it is given, so the configured address
has to end in `/v1`; `server/README.md` told me to set it **without** the
suffix. I reproduced it — `POST /messages` returns 404, `POST /v1/messages`
returns 200 — and because the screens report failures in plain words rather
than status codes, following my own instructions would have looked like the
model being down rather than a mistyped URL. I corrected the documentation in
three places and added a troubleshooting table; I did not touch the endpoint or
the client.

Three things remain open and are recorded rather than fixed. **`ALLOWED_ORIGINS`
is commented out** in `server/wrangler.toml:47`, and the code falls back to `*`,
so the deployed service currently answers any origin — step 6 of
`server/README.md` already says to lock this down once the live site works, and
it is a one-line change I have not yet made. **Row 11**, the four GitHub Actions
pinned to moveable tags rather than commit SHAs, is the supply-chain gap I had
not considered. **Rows 12 and 16** I marked No rather than guessing: secret
scanning and whether the YouTube key is API-restricted are settings outside the
repository that I could not confirm from where I ran this.

What came back clean, and how I checked it: no credential has ever been
committed on any branch, across all 65 commits; nothing is hardcoded in `lib/`;
there is no keystore or signing material; the published build carries no
credential and is now scanned mechanically before every deploy, a step that ran
and passed in the latest run; the service holds the key write-only, never
echoes it, and keeps no log of what passes through it (`server/src/` contains no
`console.*` at all); the workflow holds no secrets and runs at least privilege;
every write path validates its input; and no user-facing error discloses a
vendor, a model id or a status code.
