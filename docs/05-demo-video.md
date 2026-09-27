# Demo video

**File:** `docs/demo.mp4` *(record and add; then link it from the README)*

## What it has to show

The live link cannot demonstrate everything, and one thing in particular has to
be shown here instead: **real Gemini extraction**. The published build ships
without an API key on purpose, so extraction there is the sample fallback. The
video is where the real thing gets demonstrated, running locally with a
`GEMINI_API_KEY` in `.env`.

Two optional values make the extraction noticeably better and are worth having
set before recording: `YOUTUBE_API_KEY`, which gives the model a video's
description rather than only its title, and `FACEBOOK_TOKEN`, which is the only
way an Instagram or Facebook caption can be read at all. Both are described in
the [README](../README.md#environment-variables).

## Suggested run, about three to four minutes

1. **Cold start.** Launch with no profile: the logo assembling from its four
   quarters, the four onboarding pages, Get Started, Set Up Profile. It asks
   what to call you and offers a photo — no email, no password, because there is
   no account. Type a name and continue to Home.
2. **Home.** The greeting, Recent Saves, Your Trips with their folder colours,
   Recently Viewed. Say that the library is seeded demo data and entirely
   fictional.
3. **Save something real — with the key present.** Add → Paste Link → paste a
   real travel URL → Analyze. Show the loading state, then the detected
   destination and category. **Point out that there is no sample-data notice
   here, and that there is one in the deployed build** — that difference is the
   secrets decision made visible.
4. **Correct the extraction.** Type over the destination, or pick a different
   category chip. This is the answer to the proposal's biggest risk.
5. **Finish the save.** Choose a trip (create one to show the folder springing
   in, and the colour picker), add a note, then Review & Save. Show the new post
   on Home.
6. **The signature screen.** Open the post → Travel Details. Location, Country,
   Best Time to Visit, Budget, the places the post named and its tips. Tap the
   map to open it full screen and drag, pinch and zoom it. Mention that the pin
   is dropped only when the extraction found somewhere specific — a region keeps
   the placeholder and says why — and that the tiles are OpenStreetMap, so they
   need no key and label places in local script.
7. **Search.** Search a destination and show results matching on destination
   rather than title.
8. **Delete, and undo it.** Delete a post and follow the card flying to the
   Profile tab. Open Profile → Recently Deleted, show the 30-day window stated on
   the row, and restore it. Show it back in its trip, with the count restored and
   no duplicate. This is the safety net the confirmation dialog used to be.
9. **Persistence.** Reload the browser and show the saved post still there —
   this is the storage decision working.
10. **Failure, honestly.** Paste something that is not a link, or an opaque URL,
    and show the error state with Retry and Enter manually. Note that the message
    is plain English: no vendor name, no model id, no status code.

Optional, if there is time: **Export Data** in Settings, and **Share to Nook** —
with the app installed to a home screen it appears in the Android share sheet,
and picking it opens Nook with analysis already running.

## What to say about the AI

Say plainly what extraction actually reads. Nook fetches what each platform
publishes about a link — a YouTube title and, with a key, its description; a
TikTok caption — and hands that to the model, rather than asking the model to
guess from a bare URL. Instagram and Facebook withdrew public oEmbed in 2020, so
without a Meta token those two are read from the URL alone and the prompt tells
the model it is working blind. A post whose platform publishes real text extracts
well; one that does not may come back without a destination. That is why every
field is optional and the destination is editable.

Worth one sentence: the model is asked not to think before answering
(`thinkingBudget: 0`). This is schema-constrained extraction from text already in
the prompt, and leaving thinking on was costing seconds and thousands of
invisible tokens per save.

## Before recording

- [ ] A `GEMINI_API_KEY` is in `.env` so extraction is real
- [ ] `YOUTUBE_API_KEY` and `FACEBOOK_TOKEN` set if the run includes those platforms
- [ ] Nothing personal is on screen: no real bookmarks, tabs, notifications or names
- [ ] The seeded demo library is intact — a fresh browser profile is the simplest way
- [ ] Recorded at phone proportions, or with the `device_preview` frame visible
