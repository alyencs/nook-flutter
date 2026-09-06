# Proposal

*The revised proposal, as submitted (m6a1, revised in m7a1). The scope below is
what was built; anything that changed during the build is recorded in
[07-build-plan.md](07-build-plan.md).*

**Nook — never lose your next favourite find.**

## The problem, in one sentence

Travellers constantly discover destinations, itineraries and travel tips on
TikTok, Instagram, Facebook and YouTube, but saving them inside each platform
scatters trip research across four different apps, making it hard to pull
everything together when it is actually time to plan the trip.

## Who it is for

Travellers actively researching a trip: someone building a real itinerary for an
upcoming date, and someone collecting "someday" destination ideas for a trip
that is not booked yet. Both behaviours are the same core loop — see something,
save it, find it again later when planning.

What they do today instead: each platform's own Saved folder, screenshots piling
up in a camera roll, or a Notes app where a pasted link sits next to a grocery
list. None of these group content by trip or destination, and none are
searchable across platforms.

## Core features

| # | Feature | What it needs | Estimate |
| --- | --- | --- | --- |
| 1 | Paste link to save | URL field, a `SavedPost` model, `flutter_dotenv` for the key, the API call, a loading state | ~5 h |
| 2 | AI destination and category detection | `google_generative_ai` (Gemini) wrapped in try/catch with the `if (!mounted) return` guard, JSON decoded into the post's fields, a fallback when extraction fails | ~6 h |
| 3 | Collections, reframed as Trips | list of trips, a field plus dialog to create one, navigation into trip details | ~3 h |
| 4 | Search saved posts | a field with an `onChanged` filter over the saved list | ~2 h |
| 5 | Personal notes | a multiline field saved onto the post record | ~1.5 h |
| | | **Total** | **~17.5 h** |

## Out of scope, and why

- **Auto-sync from connected accounts** — needs each platform's API. Stretch
  goal #1; the Connected Platforms screen exists but is disabled.
- **Map pins per trip** (`flutter_map`) — stretch. The app is fully usable
  without it: trips and posts read as lists. Travel Details draws the map
  placeholder, labelled.
- **Itinerary generator** — stretch goal #3.
- **Recipe and shopping metadata** — dropped with the audience narrowing. Those
  belong to readers this proposal no longer targets.
- **Real accounts, passwords, password reset, email verification** — there is no
  server to authenticate against. Replaced by a local profile.

## Data the app remembers, and where it is saved

| Thing | Fields | Where |
| --- | --- | --- |
| User | Name, Email, Profile Picture | Drift `users` table, one local row |
| Saved Post | Title, Creator, Platform, Original URL, Import Method, Thumbnail, AI Destination, AI Category, AI Summary, Trip ID, Personal Note, Date Saved | Drift `saved_posts` |
| Trip | Trip Name, Item Count, User ID | Drift `trips` |

**The choice: Drift (SQL, on-device, works on web).**

- *Do two different people need to see the same data?* No. A traveller's saved
  library is personal. Nothing in Nook requires that another traveller ever sees
  my trips, so this is not the "chat, marketplace, leaderboard" case that points
  to a server.
- *Roughly how many records in a realistic week?* ~15 saved posts across 2–3
  active trips, so roughly 150–200 `saved_posts` rows and under 10 `trips` rows
  over a term of testing — the "hundreds of items" bucket, not the sub-100
  `shared_preferences` bucket.
- *Why not the others?* `shared_preferences` is out on volume alone: a JSON blob
  under one key gets slow and awkward well before 150 rows. Hive was the other
  on-device option, but a saved post belongs to exactly one trip — a foreign-key
  relationship, not a flat key-value box. Supabase and Firebase were
  reconsidered and dropped: a "no" to the shared-data question makes a server
  weeks of work for nothing, and Drift's web backend satisfies the
  must-run-on-web rule without an account, an API key or row-level security.
- *The trade-off accepted:* saved trips do not sync between phone and laptop —
  each install has its own local database. If cross-device sync became a real
  requirement rather than a nice-to-have, that is the point to move to Supabase.

## Screens

1. Landing / onboarding
2. Get Started → Local Profile Setup *(replaced the login flow)*
3. Home — recent saves, trips, search
4. Add Post — paste link, review the detected destination and category, choose or create a trip, add a note, save
5. Saved Post Details — including the Travel Metadata view (location, map, best time to visit, budget)
6. Profile

## Risks

- **AI reliability.** Detecting a destination from a social link is a harder
  extraction problem than reading generic link metadata, and narrowing the
  audience raised the bar on it rather than lowering it. Mitigated in the
  design: every extracted field is optional, the destination is editable before
  saving, and failure offers Retry or manual entry.
- **Vague destinations.** Extraction may return a country instead of a city, or
  nothing at all, because the link does not always name a place. Same
  mitigation, plus an em dash rather than a blank wherever a value is missing.
- **First step to reduce each.** Test the extraction call against 10 real travel
  links per platform and log how often a usable destination comes back versus
  needing manual entry.

## Changes since the last version

| Section | Prelim said | Now says | Why |
| --- | --- | --- | --- |
| Audience | Students, travellers, home cooks, fitness enthusiasts | Travellers only | Too broad to sharpen an MVP against; saved travel content already clusters around a trip |
| Feature 2 | A generic category | A destination plus a travel category | Once every save is travel-related, extraction can target travel-specific fields |
| Collections | Generic user-named groupings | Renamed Trips, same structure | Matches how a traveller actually organises saves |
| Stretch goals | Recipe and shopping metadata alongside travel | Travel only | The dropped ones served an audience the proposal no longer targets |
| Screens | Recipe Metadata and Travel Metadata detail screens | Recipe Metadata removed; Travel Metadata becomes core | No longer serves the audience |
| Persistence | Not addressed | Drift, on-device, not Supabase | The decision tree above |
| Auth | Login / Create Account / Forgot Password / verification | Local profile setup only | Drift has no built-in auth; an auth-shaped flow with no server behind it would contradict the storage choice |
| AI and secrets | Generic "AI extraction service" | `google_generative_ai` with the `flutter_dotenv` / `.gitignore` / `.env.example` pattern | Naming it precisely is more defensible than describing it |
| Stretch: map | Vaguely "content-specific metadata" | `flutter_map`, with a `kIsWeb`-selected fallback | No billing risk, and a specific fallback beats a hand-wave |
