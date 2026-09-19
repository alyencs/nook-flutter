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

**Typeface: Inter**, bundled as a local asset rather than fetched from a CDN, so
the deployed build has no third-party dependency and renders identically
offline.

| Style | Size | Weight | Used for |
| --- | --- | --- | --- |
| Display *(added)* | 32 | Bold | Screen-owning headings: "Set Up Profile", "Review & Save" |
| Heading | 24 | Bold | Screen titles, section headers, trip names |
| Title *(added)* | 20 | SemiBold | App-bar titles, card titles |
| Body | 16 | Regular | Saved posts, notes, descriptions |
| Caption | 12 | Regular | Creator names, platform labels, dates, hints |
| Overline *(added)* | 12 | SemiBold, uppercase, +0.08em | Field labels: "DETECTED DESTINATION", "SUPPORTED PLATFORMS" |

Display, Title and Overline are additions: the mockup draws all three, and the
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
