# Mockup and screen flow

The five screens the mockup brief singled out, plus everything around them. Frame
IDs are the mockup's own labels.

The full mockup PDF is in [assets/](assets/) alongside the exported frames.

## The five that carry the proposal

| # | Screen | Why it is one of the five |
| --- | --- | --- |
| 1 | **Home (Default)** `H1` | The screen a returning traveller lives in |
| 2 | **Add Post → Review & Save** `A6` | The important action, showing the detected destination, the trip picker and the note together |
| 3 | **Saved Post Details with Travel Metadata** `S1`/`S2` | The signature screen — it explains Nook without a word of narration |
| 4 | **Search Results** `H6` | The one MVP feature not otherwise visible |
| 5 | **Local Profile Setup** `LO1` | The clearest evidence the persistence decision changed the app, not just the proposal text |

## The flow

```
Splash LA1 ─► Onboarding LA2-LA5 ─► Get Started LA6 ─► Set Up Profile LO1 ─┐
   └── a profile already exists on this device ───────────────────────────┤
                                                                          ▼
                        ┌──────────────────── Home H1 ────────────────────┐
                        │  search bar ─► Search H5 ─► Search Results H6    │
                        │  Recent Saves ─► See All ─► post list           │
                        │  Your Trips ─► See All ─► Trips ─► Trip Details │
                        │  Recently Viewed ─► post                        │
                        └──────────────┬──────────────────────────────────┘
                                       ▼
   Add A1 ─► Paste Link A2 ─► Destination & Category A3 ─► Choose Trip A4
                  │                                             │
                  └── Create Note ─────────────────────────────►┤
                                                                ▼
                                     Personal Note A5 ─► Review & Save A6 ─► saved
                                       
   any post ─► Post Details S1 ─┬─► Travel Details S2
                                ├─► Personal Notes S3
                                └─► Manage Post S4 (move / delete)

   Profile P1 ─► Account P2 | Settings P3 | Connected Platforms P4 | About P5 | Help P6
```

## What changed from the wireframes, and why

The revision table from the mockup brief, and what the built app does about each.

| Screen | Required change | Built |
| --- | --- | --- |
| Sign In Method | Rename "Get Started"; drop Google/Email; single CTA to local profile | Yes |
| Login, Login Landing, Forgot Password, Verification Success | Delete — nothing to log into without a server | Deleted |
| Create Account | Rename "Local Profile Setup"; keep name, email, photo; drop password | Yes |
| Home: Default / Scrolled / Populated | "Collections" → "Your Trips" | Yes |
| Home: Empty | Copy: "No trips yet — save your first find" | Yes, verbatim |
| Home: Search Results | Cards show destination and a category chip, not just title and creator | Yes |
| Add Post: Detected Category | Rename "Detected Destination & Category"; destination primary, category secondary | Yes |
| Add Post: Choose Collection | Rename "Choose Trip"; new-trip hint "e.g. Japan 2027" | Yes, verbatim |
| Add Post: Review & Save | Add the destination to the summary | Yes |
| Saved Post Details | Destination near the top of the summary | Yes |
| Saved Post Details: Recipe Metadata | Delete — belongs to an audience now out of scope | Deleted |
| Saved Post Details: Travel Metadata | Keep and elevate; the most visual care of any screen | Yes |
| Saved Post Details: Edit Collection | Rename "Edit Trip / Delete"; "Move to Collection" → "Move to Trip" | Yes, as "Manage Post" |
| Profile | "collection count" → "trip count" | Yes |
| Profile: Account | Drop "Change Password" | Yes |
| Profile: Connected Platforms | Keep, label as stretch, keep out of the demo path | Yes — drawn, disabled, labelled |

## Two screens the mockup never drew

The tab bar has a **Trips** tab and MVP feature #3 needs somewhere to browse
them, but no frame exists for either. Both were designed from the same cards,
grid and spacing as the drawn screens:

- **Trips** — the trip grid over every trip, with a New Trip tile and an empty
  state.
- **Trip Details** — one trip's saved posts as row cards, with rename and delete
  behind the "…" action.

## Where the built app departs from a frame

Three, each with its reason, all recorded in [07-build-plan.md](07-build-plan.md):

1. **Post Details' primary button** reads **Travel Details**, not "Continue".
   "Continue" says nothing on a detail screen, and Travel Details — the
   signature screen — would otherwise have no way in.
2. **Search lives inside the Home tab.** The mockup names these frames "Home:
   Search" and "Home: Search Results" and draws the tab bar on both. As a pushed
   route it would have been a dead end with no back button.
3. **Home's section order follows H1** (Recent Saves → Your Trips → Recently
   Viewed). H2, the scrolled state, draws a different order; H1 is the canonical
   default frame.
