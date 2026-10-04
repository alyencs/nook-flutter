# AI usage

This project was built with AI assistance. This file is the record of it.

**Assistant:** Claude (Anthropic), used through Claude Code against this repository.
**Repository:** https://github.com/alyencs/nook-flutter
**Author:** Alison C. Sampang — `alyencs` / `acsampang07@gmail.com`

I used Claude heavily on Nook, and I ran the project while I did it. Every entry
below is tied to a real commit in this repository, and the authorship figures in
section 3 come from `git blame` and `git log` with the commands written out so
anyone can re-run them.

**Twenty-seven of the repository's forty-seven commits are mine**, and **23% of
`lib/` and 29% of `test/` carry my name**. The most recent phase of the project —
the Explore Itinerary feature, moving the whole AI layer onto the Anthropic
Messages API, and roughly two thousand lines of tests — I built on my own, with
no AI co-authorship on any of those commits.

**Contents:** [1. How I used AI](#1-how-i-used-ai) ·
[2. Where the AI got it wrong](#2-where-the-ai-got-it-wrong) ·
[3. Who wrote what](#3-who-wrote-what)

---

## 1. How I used AI

Eight entries. Each names the tool, what I asked for, what I kept and what I
changed, and the commit it belongs to.

### 1.1 — Finding the conflicts in my own planning documents

- **Tool:** Claude (Claude Code)
- **What I asked for:** read my proposal, mockup and design system against each
  other and list every place they disagree. Find the conflicts, do not resolve
  them.
- **What I kept, what I changed:** I kept the list — twelve real conflicts,
  including a navigation bar that is flat white in my design system and solid
  orange in my mockup, a Search screen drawing six categories against an Add
  screen drawing seven, and a Trips tab in the bar with no Trips screen behind
  it. Every resolution is mine. The mockup wins on the bar because the pixels are
  my later decision. The category list becomes the union of both at eight values,
  because dropping either loses a screen I had already drawn. Trips and Trip
  Details get designed rather than cut.
- **Commit:** https://github.com/alyencs/nook-flutter/commit/572c3ff

### 1.2 — Reviewing the first build against the frames I drew

- **Tool:** Claude (Claude Code)
- **What I asked for:** not "is this good" but a comparison of the implemented
  app against my own mockup frames, one screen at a time.
- **What I kept, what I changed:** six items came back and three were bugs rather
  than missing work — onboarding that could never be reached, a note field that
  collapsed to zero height, and Travel Details values that would not sit flush
  right. The onboarding bug was mine to find: I installed the app fresh, watched
  it skip straight to Home, and reported that symptom, which is what led to the
  seed inserting a *named* user row that the launch gate was reading as "already
  set up". I kept all three fixes and verified the onboarding one by clearing the
  database and running the whole sequence again.
- **Commit:** https://github.com/alyencs/nook-flutter/commit/88c1224

### 1.3 — Refusing "the API is busy" as a root cause, twice

- **Tool:** Claude (Claude Code)
- **What I asked for:** find out why extraction kept failing with 503s, and do
  not come back with "the service is overloaded".
- **What I kept, what I changed:** the first investigation found a model the
  vendor had retired three months earlier, no retry path at all, and an SDK that
  folded the HTTP status into a message string. I rejected that as complete,
  because the symptom returned — and the second investigation found the real
  cause: the model was thinking before answering by default, so every extraction
  burned seconds and thousands of invisible tokens on a JSON shape it had already
  been handed, blew the timeout, and was retried four times. The app was
  generating its own load. I tested both fixes against real links before
  accepting them. This is also why I later rewrote the AI layer myself around a
  client that keeps the status code — see 3.2.
- **Commits:** https://github.com/alyencs/nook-flutter/commit/954fe18 ·
  https://github.com/alyencs/nook-flutter/commit/c68a89f

### 1.4 — Troubleshooting my animation integration when it would not build

- **Tool:** Claude (Claude Code)
- **What I asked for:** I had written Nook's motion layer and integrated it into
  the app, and the build was failing. I asked Claude to work out why, and
  afterwards to review what I had written for lifecycle problems I might have
  missed.
- **What I kept, what I changed:** the build failures were in my integration and
  I fixed them with its help. The review then turned up three things worth
  keeping: four `CurvedAnimation` objects I had constructed inside `build()`,
  each leaking a listener every frame; a stagger I was holding in an uncancelled
  `Future.delayed`, which outlived the widget that scheduled it; and a missing
  re-entrancy guard on Review & Save that let a fast double-tap write two rows. I
  reviewed each fix against what I had intended, kept all three, and have since
  reworked both `folder_motion.dart` and `press_effect.dart` myself — those files
  are now 93% and 100% mine.
- **My work:** https://github.com/alyencs/nook-flutter/commit/6067a0e ·
  https://github.com/alyencs/nook-flutter/commit/72fe45a
- **The fixes I reviewed and kept:** https://github.com/alyencs/nook-flutter/commit/3ee4606 ·
  https://github.com/alyencs/nook-flutter/commit/4d8b587

### 1.5 — Proving the animations actually ran

- **Tool:** Claude (Claude Code), driving Chromium
- **What I asked for:** a way to see individual frames of the real web build. The
  analyzer was clean and every test passed and I still could not tell whether
  anything was moving, and a screenshot cannot sample a 420ms animation.
- **What I kept, what I changed:** the recordings showed three of my four
  animations were running and invisible — the delete card spent most of its
  journey at roughly 30×17 pixels on a cream background, the folder lid moved a
  72pt card's top edge by about two pixels, and the tab pulse had faded to a
  third of its opacity by the time it was large enough to notice. I kept the
  measurements and chose every replacement value myself: 132pt for the delete
  card, deeper perspective and a wider tilt on the lid, a pulse that stays inside
  the 68pt bar, and 1400ms on an ease-in-out curve for the flights, because at
  900ms on an ease-out two thirds of the distance went by in the first third of
  the time.
- **Commits:** https://github.com/alyencs/nook-flutter/commit/4d8b587 ·
  https://github.com/alyencs/nook-flutter/commit/5a6cef2

### 1.6 — Auditing my security claims, then rewriting the result myself

- **Tool:** Claude (Claude Code)
- **What I asked for:** test what the app actually does against what my
  documentation claims, and mark anything that cannot be verified as
  unverifiable rather than assuming it is fine.
- **What I kept, what I changed:** I kept two findings that were real defects I
  had not noticed — `clearAll()` left `app_settings` behind while the dialog said
  it erased everything on the device, and Export Data omitted fifteen columns
  while its own comment claimed it wrote everything. I made the call on both, and
  it was the same call twice: fix the behaviour, do not soften the wording. The
  document itself I discarded and rewrote: the audit was not in the format my
  course requires, so `SECURITY-CHECKLIST.md` is now my own 25-row numbered
  checklist with a Yes/No/N\A column and an evidence column for every row. Three
  rows are marked **No** rather than guessed at, including that all four GitHub
  Actions are pinned to moveable version tags rather than commit SHAs — a
  supply-chain gap nothing else in the project had looked at.
- **My commit:** https://github.com/alyencs/nook-flutter/commit/ea2cc38 ·
  **the audit I worked from:** https://github.com/alyencs/nook-flutter/commit/10464e3

### 1.7 — Getting my real logo into the splash

- **Tool:** Claude (Claude Code)
- **What I asked for:** the splash was assembling a mark that was not Nook's. I
  supplied `nook_logo.png` and the per-letter SVGs and asked for the
  implementation to be rebuilt around my actual artwork.
- **What I kept, what I changed:** I required proof rather than assurance — the
  four quarters are cut from my file along its own gutters, composited back
  together and differenced against the original, and no pixel differs. I also had
  to point out that only `N.svg` and two identical copies of `O.svg` had been
  supplied and there is no `K.svg`, which is why all four quarters come from the
  PNG. I have since gone back over `logo_assembly.dart` myself to apply the
  primary colour and blend mode, so the mark sits on the splash's warm background
  instead of floating on it.
- **Commits:** https://github.com/alyencs/nook-flutter/commit/5a6cef2 ·
  https://github.com/alyencs/nook-flutter/commit/92fee19

### 1.8 — Reviewing and merging every change into `main`

- **Tool:** GitHub pull requests, with Claude's work as the input
- **What I asked for:** nothing reaches `main` without going through a PR I read.
- **What I kept, what I changed:** nine merges, and they are not rubber stamps.
  PR #8 is where I caught that the security audit was in the wrong format and
  rewrote it. PR #10 onward is where my own itinerary work landed. The review
  step is the reason the two defects in 1.6 were fixed rather than documented.
- **Commits:** [#1](https://github.com/alyencs/nook-flutter/commit/4153180) ·
  [#2](https://github.com/alyencs/nook-flutter/commit/912f96c) ·
  [#3](https://github.com/alyencs/nook-flutter/commit/d3670b0) ·
  [#4](https://github.com/alyencs/nook-flutter/commit/1008fda) ·
  [#5](https://github.com/alyencs/nook-flutter/commit/0a24ade) ·
  [#6](https://github.com/alyencs/nook-flutter/commit/cfa9be5) ·
  [#7](https://github.com/alyencs/nook-flutter/commit/a6ac0e1) ·
  [#8](https://github.com/alyencs/nook-flutter/commit/c817e6c) ·
  [#9](https://github.com/alyencs/nook-flutter/commit/3553010)

---

## 2. Where the AI got it wrong

Three cases. Each names what it produced, what was wrong with it, how I found it,
what I changed, and the commits involved.

### Case 1 — It invented a logo, and its own correction did not fix it

- **What it produced:** asked to animate the Nook mark assembling, Claude wrote a
  widget that drew four charcoal rounded squares and set a letter in Manrope in
  each one. It chose `N`, `V`, `V`, `K`, so the animation assembled into
  **NVVK**.
- **What was wrong:** two things, and its own correction only caught one. Claude
  later noticed the spelling and changed the two `V`s to `O`s, and reported that
  as the fix. It was not. **Nook's mark is not type at all.** It is four tiles
  with the letterforms cut out of them as counters, and the two O tiles read as a
  check rather than a round O — which is almost certainly why an AI looking at it
  guessed `V`. Setting the right letters in the wrong medium is still the wrong
  logo, and the "fix" addressed the symptom it could see instead of the mistake
  underneath.
- **How I found it:** I put the splash next to `nook_logo.png`, the file I had
  supplied. It was not a near miss — it was a different mark.
- **What I changed:** I required the real artwork, used as artwork, and verified
  by differencing the reassembly against my original rather than asserted. This
  is the first screen anyone sees and it was showing a logo that does not exist.
- **Commits:** wrong https://github.com/alyencs/nook-flutter/commit/ec783d7 ·
  wrong again https://github.com/alyencs/nook-flutter/commit/4d8b587 ·
  fixed https://github.com/alyencs/nook-flutter/commit/5a6cef2

### Case 2 — Suggested edits that did not compile and did not match this codebase

- **What it produced:** a set of file-by-file edits for the animation work,
  presented as ready to apply, with the explicit claim that it contained no
  placeholders and no elisions.
- **What was wrong:** three of the blocks were not valid Dart or referred to
  things this project does not have. One carried the literal line
  `child: /* the existing _Pin build() body goes here, unchanged */,`. One called
  `SavedPostCard`, when the class in this codebase is `SavedPostGridCard`. A
  third placed an `Expanded` where its `stage` variable was out of scope, inside
  an unbounded `Column` that made it illegal anyway.
- **How I found it:** I applied them to the app and the build failed. I read the
  errors and reported the three specific failures rather than guessing at
  repairs, which is what let them be fixed at the cause instead of patched over.
- **What I changed:** the three blocks were corrected, and my rule since then is
  that no generated patch counts as applicable until it has been applied once and
  built. That rule is why case 3 was caught at all.
- **Commits:** https://github.com/alyencs/nook-flutter/commit/ec783d7 ·
  https://github.com/alyencs/nook-flutter/commit/3ee4606

### Case 3 — A folder spring that never played, behind a green test suite

- **What it produced:** a suggestion to clear the trips grid's "just created"
  flag inside a post-frame callback.
- **What was wrong:** that tore `FolderArrive` out of the widget tree on the very
  next frame and disposed its controller before any of its 340ms had run. **The
  spring never played once.** Nothing failed — `flutter analyze` was clean and
  every test passed, because a test that pumps frames and checks the end state
  cannot see an animation that was removed before it started.
- **How I found it:** I created a trip and watched the grid. Nothing happened. No
  tool told me; I had to look at it.
- **What I changed:** the flag is not cleared at all now, because the widget key
  is what stops the spring repeating. The wider change is in how I work: a
  passing test suite tells you the code runs, not that the animation does, which
  is what led to the frame-by-frame verification in 1.5. I have since rewritten
  `folder_motion.dart`'s tap handling around an explicit timer and reworked
  `press_effect.dart`'s state management, both on my own, because this is the
  part of the app where the gap between "compiles" and "behaves" is widest.
- **Commits:** https://github.com/alyencs/nook-flutter/commit/3ee4606 ·
  https://github.com/alyencs/nook-flutter/commit/4d8b587 ·
  fixed further by me: https://github.com/alyencs/nook-flutter/commit/05ce07e ·
  https://github.com/alyencs/nook-flutter/commit/69d6917

---

## 3. Who wrote what

### How I measured it

```bash
# surviving lines, excluding generated .g.dart, grouped by author
for f in $(git ls-tree -r HEAD --name-only | grep '^lib/.*\.dart$' | grep -v '\.g\.dart$'); do
  git blame -w --line-porcelain HEAD -- "$f" | grep '^author '
done | sort | uniq -c | sort -rn
```

`git blame` attributes a line to whoever last committed it. Generated drift
output is excluded, because nobody writes it by hand.

| Measure | Mine | Total | My share |
| --- | --- | --- | --- |
| Surviving lines in `lib/` | **3,819** | 16,523 | **23.1%** |
| Surviving lines in `test/` | **2,072** | 7,171 | **28.9%** |
| `lib/` and `test/` together | **5,891** | 23,694 | **24.9%** |
| Lines ever added to `lib/` (`git log --numstat`) | **5,691** | 22,559 | **25.2%** |
| Commits in the repository | **27** | 47 | **57%** |

Two independent methods — what survives today, and what was ever written — agree
at roughly a quarter of the application.

---

### 3.1 Explore Itinerary — a complete feature, mine end to end

**Commits:** [`d4d7876`](https://github.com/alyencs/nook-flutter/commit/d4d7876) ·
[`d85d268`](https://github.com/alyencs/nook-flutter/commit/d85d268)

**Eight files, 1,906 lines, 100% mine by blame**, with no AI co-authorship on
either commit. This was a stretch goal the project had previously drawn as a
disabled button.

| File | Lines | What it is |
| --- | --- | --- |
| `lib/ai/claude_itinerary_generator.dart` | 372 | The real generator |
| `lib/screens/explore/itinerary_result_screen.dart` | 371 | The finished plan, day by day |
| `lib/ai/sample_itinerary_generator.dart` | 293 | The keyless fallback |
| `lib/screens/explore/itinerary_plan_screen.dart` | 281 | Source posts and trip length |
| `lib/ai/itinerary_generator.dart` | 195 | The interface and `ItinerarySource` |
| `lib/ai/itinerary.dart` | 157 | `GeneratedItinerary`, `ItineraryDay` |
| `lib/screens/explore/explore_itineraries_screen.dart` | 156 | Which trip to plan |
| `lib/explore/itinerary_context.dart` | 81 | Wiring the generator into the app |

**In my own words.** This turns what someone has already saved into a day-by-day
plan, which is the whole point of Nook — the posts were never the product, the
trip was.

`ItineraryPlanScreen` shows the posts it is planning from *before* anything is
generated. That was a deliberate choice: a plan built out of your own saved
material should show its working, so it is obvious where the days came from and
obvious when there is not enough to go on. A generator that produces a confident
three-day plan from two saved posts is lying, and this screen makes that visible
before anyone presses the button.

The structure mirrors the decision I made about extraction at the start of the
project. `ItineraryGenerator` is an interface with two implementations, and which
one runs is decided once at startup by whether an API key is present. With a key,
`ClaudeItineraryGenerator` writes the plan; without one,
`SampleItineraryGenerator` arranges the saved posts deterministically and the
screen says so rather than passing it off as a generation. That is the same
honesty rule the extractor follows, and it is the only reason the deployed build
can show this feature at all — the published site has no key, so without a
fallback the whole thing would be a dead button again.

`ItinerarySource` is a value type rather than the Drift row on purpose: `lib/ai`
knows nothing about the database, so the generator is testable without one and
the data layer can change shape without reaching into it.

### 3.2 The Anthropic Messages API client — `lib/ai/claude_api.dart`

**Commit:** [`d85d268`](https://github.com/alyencs/nook-flutter/commit/d85d268) ·
**384 lines, 100% mine**

I moved Nook's entire AI layer off Gemini and onto the Anthropic Messages API,
and I wrote the client by hand over plain `http` rather than taking an SDK.

**In my own words.** That decision came straight out of the bug in 1.3. The SDK
we had been using folded the HTTP status into a message string, so a retryable
overload and a fatal bad request were indistinguishable by the time they reached
the app — which is exactly why the first diagnosis was wrong and the app spent
months retrying things that were never going to succeed.

So `ClaudeApiException` carries the status, `error.type` and the server's own
`retry-after` as separate fields, and `isRetryable` is a decision made on those
rather than on string matching. `retry-after` is honoured over my computed
backoff, because the server knows when it will be ready and I am guessing.
`lib/ai/claude_extractor.dart` is the extractor rebuilt against that client,
using tool use for structured output instead of a JSON response schema.

### 3.3 Tests — 1,977 lines, written by me

**Commits:** [`372ab00`](https://github.com/alyencs/nook-flutter/commit/372ab00) ·
[`d4d7876`](https://github.com/alyencs/nook-flutter/commit/d4d7876)

| File | Lines | Covers |
| --- | --- | --- |
| `test/claude_test.dart` | 701 | The API client: status handling, retries, `retry-after`, tool-use parsing |
| `test/itinerary_test.dart` | 689 | Both generators, the model, and the keyless path |
| `test/itinerary_flow_test.dart` | 587 | The three Explore screens end to end |

All three are 100% mine by blame. `claude_test.dart` is the one I would point at
first: it scripts a server through every failure the client can meet — a 429 with
a `retry-after`, a 529 overload, an authentication error that must *not* be
retried — and asserts the number of requests actually made, because "it retries"
and "it retries four times and then stops" are different claims.

### 3.4 Nook's motion system

**Commits:** [`6067a0e`](https://github.com/alyencs/nook-flutter/commit/6067a0e) ·
[`72fe45a`](https://github.com/alyencs/nook-flutter/commit/72fe45a) ·
[`69d6917`](https://github.com/alyencs/nook-flutter/commit/69d6917) ·
[`05ce07e`](https://github.com/alyencs/nook-flutter/commit/05ce07e) ·
[`92fee19`](https://github.com/alyencs/nook-flutter/commit/92fee19) ·
[`a0a6058`](https://github.com/alyencs/nook-flutter/commit/a0a6058)

| File | My lines | Total | Mine |
| --- | --- | --- | --- |
| `lib/widgets/folder_motion.dart` | 143 | 153 | 93% |
| `lib/widgets/tab_pulse.dart` | 100 | 106 | 94% |
| `lib/widgets/press_effect.dart` | 53 | 53 | 100% |
| `lib/widgets/entrance.dart` | 56 | 81 | 69% |
| `lib/widgets/delete_flight.dart` | 61 | 96 | 63% |
| `lib/theme/nook_motion.dart` | 51 | 59 | 86% |
| `lib/widgets/logo_assembly.dart` | 100 | 206 | 48% |
| `lib/widgets/flight.dart` | 58 | 194 | 29% |

**In my own words.** Four animations ship: the delete and restore flight with the
tab pulse that catches it, folder open and arrive on trip cards, the logo
assembly on the splash, plus entrance staggers and press effects. All of it is
`AnimationController`, `Transform`, `CustomPainter` and `OverlayEntry` — **no
dependency was added for any of it.**

The decisions are the part I can explain without looking anything up. Deleting a
post flies its card to the **Profile** tab, and the destination is the entire
point: Recently Deleted lives under Profile, so the animation answers "where did
it go" instead of decorating the word "deleted". Restoring is the same arc read
backwards, because delete and restore are one interaction with a direction, and
two unrelated motions would make them look like two unrelated features. A trip
folder opens on tap *before* its screen arrives, so the folder is visibly open
under the page rather than behind it. The splash takes the mark apart along lines
it already has, because it is a 2×2 grid and no piece needed inventing.

The timings live as tokens in `nook_motion.dart` rather than scattered through
widgets, for the same reason the colours do: a dozen screens each picking their
own 180ms-ish easing is how motion stops reading as one system.

The values are mine and most of them replaced something that technically worked:
132pt for the delete card, deeper perspective and a wider tilt on the folder lid,
a pulse that stays inside the bar, 1400ms on an ease-in-out curve for the
flights, 2400ms for the logo assembly with its pieces 260ms apart. Claude's part
in this work was troubleshooting when my integration would not build and
reviewing it for lifecycle problems afterwards — the detail is in 1.4.

### 3.5 Assets, and getting the demo library to actually load

**Commits:** [`5804507`](https://github.com/alyencs/nook-flutter/commit/5804507) ·
[`622c843`](https://github.com/alyencs/nook-flutter/commit/622c843) ·
[`b431139`](https://github.com/alyencs/nook-flutter/commit/b431139)

I replaced the seeded destination photographs and the onboarding images with
**local bundled assets** instead of remote Wikimedia URLs.

**In my own words.** Those URLs went through a redirect that carries no CORS
header, which meant CanvasKit could not fetch the bytes at all and the onboarding
pages rendered as flat blocks of tint. Bundling the photographs removes the
network from the path entirely, so the demo library looks right on first launch
with no connection — which matters, because that is exactly what someone opening
the live link for the first time sees.

### 3.6 Documentation I wrote

**`SECURITY-CHECKLIST.md`** —
[`ea2cc38`](https://github.com/alyencs/nook-flutter/commit/ea2cc38). The 25-row
numbered checklist my course requires, with an evidence column for every row and
three rows marked **No** rather than guessed at. Writing it is what surfaced the
GitHub Actions supply-chain gap.

**The planning documents** — the proposal, the mockup, the design system, and all
twelve resolutions between them. The app's shape comes from those: Drift over
Hive because a post belonging to exactly one trip is a foreign key and not a
key-value pair; Search inside the Home tab because my own frames are labelled
"Home: Search" and draw the tab bar on them; a local profile instead of accounts
because there is no server to authenticate against.

---

### 3.7 The AI-assisted part I understand best — `lib/ai/source_metadata.dart`

This file was written by Claude, to my brief, and I can explain exactly what it
does and why it has to exist.

**What it does.** Before anything is sent to a model, it fetches what each
platform already publishes about a link: keyless oEmbed for YouTube and TikTok,
the Graph API for Instagram and Facebook when a token is configured. It returns a
`SourceMetadata` with the real title, description, creator, handle, media type
and thumbnail — or, when a lookup is not possible, an object built from the URL
alone with `fetched: false`.

**Why it exists.** Early on, the app sent the model a bare URL. For
`youtube.com/watch?v=Sf9ihvL0Usk` that is eleven characters of video id, and the
model answered "Japan" — which is a perfectly reasonable answer to the question
it was actually asked. The post was about a cafe in Nakazakicho. No better model
would have fixed that, because the information was never in the request.

**The part I think is cleverest, and why I kept it.** It does not pretend the
four platforms are equivalent. `endpointFor` returns `null` for Instagram and
Facebook when there is no token, and the prompt block then states outright that
the model is working from the URL alone and must not invent a caption. Degrading
to "I cannot see this" is more useful than degrading to a confident guess, and
that single decision is why Nook's extraction returns empty fields instead of
plausible fiction.

**What I took from it into my own code.** `claude_extractor.dart` keeps the same
shape deliberately: fetch what the platform actually publishes, hand the model
only what it can legitimately work from, and let every field come back null
rather than guessed. The idea is Claude's; carrying it into the Anthropic client
was mine.

---

## Project state at the time of writing

`flutter analyze` is clean. **331 of 336 tests pass.** The five failures are in
`dao_test.dart` and `widget_test.dart` and are assertions about the demo seed
rather than about the app: they still expect the old remote `https://` thumbnail
URLs and the old post counts, both of which changed when I moved the seeded
photographs to local assets. Fixing those assertions is the next thing on my
list, and it is recorded in the README's known issues rather than left for
someone else to discover.

---