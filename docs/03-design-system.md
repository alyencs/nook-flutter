# Design system

The visual language behind every screen. The exported visual is in
[assets/](assets/) alongside the mockup frames.

Every value below exists as a constant in `lib/theme/`. No screen hardcodes a
colour, a size or a radius, and Material's defaults — the purple seed palette,
Roboto, the elevation shadows — are switched off rather than overridden case by
case.

## Colour palette

Nook is meant to feel calm, cosy and modern, which is where the warm off-white
and the burnt orange come from.

| Role | Colour | Used for |
| --- | --- | --- |
| Primary | `#DD700B` Burnt Orange | Primary buttons, active navigation, links, accents |
| Secondary / accent | `#FCF8D8` Soft Butter | Chip fills, selected states, the foot of the screen gradient |
| Background | `#FAFAF8` Warm Off-White | The head of the screen gradient |
| Surface | `#FFFFFF` White | Cards, search bar, dialogs |
| Error | `#D9534F` Soft Red | Validation errors, delete actions |
| Text | `#2E2E2E` Charcoal | Body copy and headings |
| Border | `#D9DADF` | Field and card outlines |
| Muted text *(added)* | `#8A8F98` | Creator names, captions, section labels, inactive navigation |
| Placeholder *(added)* | `#F0F1F4` | Thumbnail and avatar placeholder fills |

**Screen gradient.** Every screen carries a vertical gradient from `#FAFAF8` at
the top to `#FCF8D8` at the foot, drawn once in `NookScaffold`.

**Two revisions to this document**, both made so it describes the app that was
actually built:

1. The background is a gradient, not a flat fill. The mockup draws it on every
   frame, and it is what makes the app feel warm rather than clinical.
2. The **navigation bar is solid Burnt Orange with white icons and labels**, not
   a white bar with orange active icons. Again, the mockup draws it that way on
   every frame.

The two added colours are here for the same reason: the mockup clearly renders
captions and inactive navigation in a lighter grey than the single body colour
this document originally named.

## Type scale

Nook is about reading and organising, so typography prioritises readability.

**Two typefaces, both bundled as local assets** rather than fetched from a CDN,
so the deployed build has no third-party dependency and renders identically
offline.

- **Manrope** does the work: body, labels, buttons, navigation, every piece of
  functional UI. It is the voice of the app.
- **Instrument Serif** is the accent, and it is rationed — one emphasised phrase
  inside an otherwise plain line, four times in the whole app. It always carries
  Nook's orange, because emphasis and brand colour are one decision, not two.

The design direction calls for **PP Editorial New** in that second role. It is
licensed from Pangram Pangram and free for personal use only, so it cannot be
committed to a public repository. Instrument Serif (SIL OFL) stands in. Every
editorial style resolves through one family constant, so swapping in the
licensed face is two edits: drop the files into `assets/fonts/` and repoint the
`EditorialSerif` family in `pubspec.yaml`.

| Style | Size | Weight | Used for |
| --- | --- | --- | --- |
| Display *(added)* | 25 | ExtraBold | Screen-owning headings: "Set Up Profile", "Review & Save" |
| Heading | 20 | Bold | Screen titles, section headers, trip names |
| Title *(added)* | 16.5 | Bold | App-bar titles, card titles |
| Body Strong *(added)* | 14 | SemiBold | Saved post titles in lists and cards |
| Body | 14 | Regular | Saved posts, notes, descriptions |
| Button *(added)* | 14.5 | Bold | Button labels |
| Caption | 11 | Medium | Creator names, platform labels, dates, hints |
| Overline *(added)* | 10 | Bold, uppercase, +1.4 tracking | Field labels: "DETECTED DESTINATION", "SUPPORTED PLATFORMS" |

The editorial accents pair with the Manrope line they sit inside: **Display
Accent** at 29 and **Heading Accent** at 23, both italic, plus a standalone
**Figure** at 30 for a count or a stat.

**These sizes are not the ones this document originally named.** The scale
started at 32 / 24 / 20 / 16 / 12 and came down about 10% in week 3, when a
dozen screens had drifted from it independently with ad-hoc `fontSize`
overrides; the editorial redesign in week 5 settled it here. Display, Title,
Body Strong, Button and Overline are additions: the mockup draws them and the
original 24/16/12 scale had no name for them.

## Spacing rule

- **Tight** (between related items): 8 px
- **Standard** (between sections): 16 px
- **Screen edge padding**: 24 px

## Radius

| Token | Value | Applies to |
| --- | --- | --- |
| `sm` | 12 | Navigation tiles, thumbnails, avatar squares |
| `md` | 16 | Cards, buttons, text fields, dialogs |
| `pill` | 999 | Chips and the search bar |

## Elevation

One shadow in the whole app: `0 2 8 rgba(46,46,46,0.06)`, on white cards and the
dialog. Nothing else casts one.

## Reusable components

Each is exactly one widget in `lib/widgets/`. Screens compose these; they never
build their own buttons or cards.

| Component | Widget | Looks like | Contains |
| --- | --- | --- | --- |
| Navigation bar | `NookBottomNav` | Solid Burnt Orange; active icon and label in white, inactive in translucent white | Home, Trips, Add, Profile |
| App bar | `NookAppBar` | Rounded-square outlined back button, then the title | Back, title, optional action |
| Search bar | `NookSearchBar` | White pill with a light grey border and muted placeholder | Search icon, placeholder, input, clear |
| Primary button | `NookPrimaryButton` | Rounded filled Burnt Orange with white text | Label, optional icon, busy spinner |
| Secondary button | `NookSecondaryButton` | White with a light grey outline and charcoal text | Label, optional icon; destructive variant in Soft Red |
| Saved post card | `SavedPostGridCard` / `SavedPostRowCard` | Rounded white card, subtle shadow, Soft Butter metadata chips | Thumbnail, title, creator or destination, platform and category chips |
| Trip card | `TripCard` | Rounded white card with a folder glyph in a pale tile | Trip name and saved-post count |
| Text field | `NookTextField` / `NookNoteField` | Rounded white input, light grey border | Label, placeholder, input; the note variant carries the 0/500 counter |
| Section header | `SectionHeader` | Bold charcoal title with a Burnt Orange "See All" | Title, optional action |
| Metadata chip | `MetadataChip` | Soft Butter pill with Burnt Orange text | Platform, category or tag; outlined variant for suggestions |
| Empty state | `NookEmptyState` | Centred outlined glyph, heading, message, primary action | Message and call to action |
| Dialog | `showNookDialog` | White rounded modal, subtle shadow; destructive actions in Soft Red | Title, message, Cancel, Confirm |
| Card surface | `NookCard` | The one white card surface, one shadow | Anything |
| Thumbnail | `ThumbPlaceholder` | Pale panel crossed corner to corner with a small image glyph | — |

## The mark

Nook's logo is a 2×2 grid of solid tiles whose letterforms are **counters** —
cut out of the tile rather than set on top of it. The two O tiles read as a check
rather than a round O, which is a property of the mark and not an error in it.

It is never reproduced in type. `assets/images/nook_mark_*.png` are four
transparent tiles cut from the supplied `nook_logo.png` along its own gutters;
laid out at 427/852 across and 423/846 down they reassemble into that file
exactly. `LogoAssembly` flies them into place on the splash; `NookLogo` draws
them still, wherever the logo is wanted without the performance.
