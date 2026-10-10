# Demo video

**File:** `docs/demo.mp4` *(record and add; then link it from the README)*

## What it has to show

The live link cannot demonstrate everything, and two things in particular have
to be shown here instead: **real extraction** and **a real generated
itinerary**. The published build ships without an API key on purpose, so both
are the sample fallback there. The video is where the real thing gets
demonstrated, running locally with an `ANTHROPIC_API_KEY` in `.env`.

Two optional values make the extraction noticeably better and are worth having
set before recording: `YOUTUBE_API_KEY`, which gives the model a video's
description rather than only its title, and `FACEBOOK_TOKEN`, which is the only
way an Instagram or Facebook caption can be read at all. Both are described in
the [README](../README.md#environment-variables).

## Suggested run, about three to four minutes

1. **Cold start.** Launch with no profile: Nook's mark assembling from its own
   four quarters over about two and a half seconds, then the four onboarding
   pages, Get Started, Set Up Profile. It asks what to call you and offers a
   photo — no email, no password, because there is no account. **Add a photo and
   drag it around in the crop window**, so the framing is visibly a choice rather
   than a centre crop. Type a name and continue to Home.
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
8. **Explore Itinerary.** Trips → Explore itineraries → pick the trip the new
   post went into → choose a number of days → Generate. Point out the list of
   saved posts above the chooser: that is the material the plan is built from,
   and it is on screen before the button is pressed. Show the finished plan —
   the day titles, the activities, the places and times — and say that the venues
   in it came out of posts the traveller saved rather than from the
   destination's reputation. Tap **Change number of days**, pick a different
   length and regenerate, so the chosen duration is visibly what comes back.
9. **Delete, and undo it.** Delete a post and follow the card flying to the
   Profile tab — it runs for 1.4 seconds and the tab pulses as it lands, so there
   is time to narrate the four beats: the list settling, the card crossing, the
   tab answering, the confirmation. Open Profile → Recently Deleted, show the
   30-day window stated on the row, and restore it: the same arc read backwards,
   out of the bar and back into the row. Show it back in its trip, with the count
   restored and no duplicate.
10. **Persistence.** Reload the browser and show the saved post still there —
   this is the storage decision working.
11. **Failure, honestly.** Paste something that is not a link, or an opaque URL,
    and show the error state with Retry and Enter manually. Note that the message
    is plain English: no vendor name, no model id, no status code.

Worth a beat if the run includes a YouTube link with a key configured: the
creator's **profile picture** appears beside their name on Post Details. On the
other three platforms it is their initial instead, because no route Nook can
legitimately use exposes an avatar there — worth saying out loud rather than
letting it look like a bug.

Optional, if there is time: **Export Data** in Settings, which now writes every
column rather than most of them, and **Share to Nook** —
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

Worth one sentence each on the two AI features. **Extraction** asks for a fixed
set of fields and is run at temperature zero, so the same link extracts the same
way twice. **Explore Itinerary** is given the saved posts for one trip and a
number of days, and runs a little warmer, because ordering a day is a choice
rather than a lookup. Both ask for their answer through a declared schema rather
than as prose, so nothing has to be guessed at on the way back in.

Worth saying out loud: the itinerary prompt is the one place a personal note
leaves the device, and only for the trip being planned. Nothing from another
trip, the profile or the search history goes with it.

## Before recording

- [ ] An `ANTHROPIC_API_KEY` is in `.env` so extraction and the itinerary are real
- [ ] `YOUTUBE_API_KEY` and `FACEBOOK_TOKEN` set if the run includes those platforms
- [ ] Nothing personal is on screen: no real bookmarks, tabs, notifications or names
- [ ] The seeded demo library is intact — a fresh browser profile is the simplest way
- [ ] Recorded at phone proportions, or with the `device_preview` frame visible
- [ ] A photograph ready to use for the profile picture, so the crop window has
      something to position
- [ ] A trip with two or three saved posts in it, so Explore Itinerary has
      enough to plan from