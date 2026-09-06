# Demo video

**File:** `docs/demo.mp4` *(record and add; then link it from the README)*

## What it has to show

The live link cannot demonstrate everything, and one thing in particular has to
be shown here instead: **real Gemini extraction**. The published build ships
without an API key on purpose, so extraction there is the sample fallback. The
video is where the real thing gets demonstrated, running locally with a
`GEMINI_API_KEY` in `.env`.

## Suggested run, about three minutes

1. **Cold start.** Launch with no profile: splash, the four onboarding pages,
   Get Started, Set Up Profile. Type a name and email, continue to Home.
2. **Home.** The greeting, Recent Saves, Your Trips, Recently Viewed. Say that
   the library is seeded demo data and entirely fictional.
3. **Save something real — with the key present.** Add → Paste Link → paste a
   real travel URL → Analyze. Show the loading state, then the detected
   destination and category. **Point out that there is no sample-data notice
   here, and that there is one in the deployed build** — that difference is the
   secrets decision made visible.
4. **Correct the extraction.** Type over the destination, or pick a different
   category chip. This is the answer to the proposal's biggest risk.
5. **Finish the save.** Choose a trip (create one to show that path), add a
   note, then Review & Save. Show the new post on Home.
6. **The signature screen.** Open the post → Travel Details. Location, Country,
   the map placeholder, Best Time to Visit, Budget. Mention that the map is a
   stretch goal and labelled as one.
7. **Search.** Search a destination and show results matching on destination
   rather than title.
8. **Persistence.** Reload the browser and show the saved post still there —
   this is the storage decision working.
9. **Failure, honestly.** Paste something that is not a link, or an opaque URL,
   and show the error state with Retry and Enter manually.

## What to say about the AI

Say plainly that extraction reads the link — its host, its slug, its handle —
because a browser cannot fetch a TikTok or Instagram page directly. A URL that
names its subject extracts well; an opaque one may come back without a
destination. That is why every field is optional and the destination is
editable.

## Before recording

- [ ] A `GEMINI_API_KEY` is in `.env` so extraction is real
- [ ] Nothing personal is on screen: no real bookmarks, tabs, notifications or names
- [ ] The seeded demo library is intact (Settings → Reset Demo Data)
- [ ] Recorded at phone proportions, or with the `device_preview` frame visible
