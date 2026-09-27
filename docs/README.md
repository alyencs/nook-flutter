# Project documentation

Everything about Nook that is not code lives here, so the repository is the
single place the work exists. Nothing is submitted separately: the submission is
**one link — the public repository** — and this folder is half of what gets read.

| File | What is in it |
| --- | --- |
| [01-proposal.md](01-proposal.md) | The revised proposal as submitted: the problem, the users, the five core features, what is out of scope, and the storage decision. |
| [02-mockup.md](02-mockup.md) | The screens, the flow between them, and the three places the built app departs from a frame. |
| [03-design-system.md](03-design-system.md) | Palette, type scale, spacing, radius and the component inventory, as shipped. |
| [04-weekly-reports.md](04-weekly-reports.md) | The development history, week by week, reconstructed from the commit history. |
| [05-demo-video.md](05-demo-video.md) | What the recording has to show, and the run to follow. |
| [06-security-and-privacy.md](06-security-and-privacy.md) | Why the data and the keys are handled the way they are. |
| `assets/` | Screenshots and diagrams. |

The security **audit** — every item checked against the code, with the open ones
listed — is [`SECURITY-CHECKLIST.md`](../SECURITY-CHECKLIST.md) at the root of
the repository, next to the README, because that is where a reader looks for it.
`06` explains the reasoning; the checklist is the evidence.

## Reading these

- **01, 02 and 03 are the planning documents**, kept as submitted. Where the
  build departed from them, the document says so in place rather than being
  quietly rewritten.
- **04 is a historical record.** It contains work that was later replaced —
  Inter as the typeface, email in onboarding, a destructive delete, CARTO tiles.
  That is deliberate. For what Nook is *now*, read the [README](../README.md).
- **Everything else describes the current build** and is dated where it matters.

Three working documents were removed once the project was finished: a build plan
that tracked the twelve conflicts between the planning documents, a note on
native share plumbing, and an animation implementation guide. All three had done
their job and had started to contradict the shipped app. Their outcomes are in
the weekly reports and in the code.
