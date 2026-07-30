---
name: ui-ux-review
description: Use to audit UI that already exists — a page, screen, component, or whole flow — for accessibility, interaction, layout, visual-consistency, and polish defects, on web or mobile. Produces severity-ranked findings with file:line and a concrete failure scenario. Run before calling any UI work done, and whenever UI "looks unprofessional" but the reason isn't obvious. For making design decisions use ui-ux-web or ui-ux-mobile.
---

# ui-ux-review

**Verb: review (UI/UX).**

Reviewing is a separate pass from designing. Doing both at once is how gaps survive — you see what you intended rather than what's there. Read the code as written.

## Two lenses, both required

A checklist finds **defects**. It cannot tell you the thing is merely adequate. Run both passes:

1. **The defect pass** — categories 1–11 below. Binary, evidence-cited, blocking where marked.
2. **The principle pass** — invoke **`design-is`** for a Dieter Rams audit: each of the ten principles scored 0–3 with evidence, producing a verdict of NEW / REFINE / REDESIGN. This is what catches a UI that violates no rule and still isn't good — where "innovative", "unobtrusive", "honest", and "thorough down to the last detail" are failing even though contrast and touch targets pass.

They disagree usefully. A screen can be defect-free and score 1/3 on *innovative* because it's the templated default — that's a real finding, and only the principle pass surfaces it. If it does, the fix is a direction problem: hand back to `ui-ux-web` / `ui-ux-mobile` with `frontend-design`, not a patch to spacing.

Report both. Don't let a clean checklist stand in for a design being good.

## Priority order

Work top to bottom. A contrast failure outranks a spacing inconsistency, and shipping is blocked by different things than polish is.

| # | Category | Severity | Blocks ship? |
|---|---|---|---|
| 1 | Accessibility | CRITICAL | Yes |
| 2 | Touch & interaction | CRITICAL | Yes |
| 3 | Missing states | HIGH | Yes |
| 4 | Performance & layout stability | HIGH | Usually |
| 5 | Layout & responsive | HIGH | Usually |
| 6 | Visual consistency | MEDIUM | No |
| 7 | Typography & colour | MEDIUM | No |
| 8 | Forms & feedback | MEDIUM | Sometimes |
| 9 | Navigation | HIGH | Usually |
| 10 | Motion | MEDIUM | No |
| 11 | Charts & data | LOW–HIGH | Depends |

Query `ui-ux-pro-max` (`--domain ux`, or `--stack <stack>`) for the detailed rule set behind any category, and `dataviz` for chart-specific review. Don't restate those rule sets here — cite them.

## 1. Accessibility (CRITICAL)

- Body text below 4.5:1 contrast; large text or meaningful glyphs below 3:1. **Measure it.** Check light *and* dark independently — passing one says nothing about the other.
- `outline: none` / removed focus rings with no stronger replacement.
- Interactive element unreachable by keyboard, or tab order not matching visual order.
- `<div>`/`<span>` with a click handler instead of a real button — loses role, focus, and keyboard activation.
- Icon-only control with no accessible label.
- Input with no visible label, or a placeholder standing in for one.
- Meaning conveyed by colour alone.
- Heading levels skipped.
- Modal that doesn't trap focus, doesn't restore it on close, or doesn't close on `Esc`.
- Motion that ignores `prefers-reduced-motion`.
- Zoom disabled (`user-scalable=no`, `maximum-scale=1`).
- Mobile: text that clips or reflows broken at largest Dynamic Type; missing screen-reader labels; state changes not announced.

## 2. Touch & interaction (CRITICAL)

- Hit target under 24×24px (pointer) or 44×44pt / 48×48dp (touch); adjacent targets closer than 8px.
- Primary interaction available only on hover — unreachable on touch entirely.
- No pressed/active feedback, or feedback slower than ~100ms.
- Async action with no pending state — button stays live, double-submits.
- Disabled control that still looks enabled, or looks disabled but still fires.
- Gesture-only action with no visible alternative and no discoverable affordance.
- App gesture colliding with a system gesture (edge-back, Control Center, home indicator).
- Destructive action with neither confirmation nor undo.

## 3. Missing states (HIGH)

For every fetching, submitting, or possibly-empty view, confirm each exists — this is the most commonly skipped category and the one that most makes UI feel unfinished:

**empty** (and first-run vs. filtered-to-nothing distinguished) · **loading** (skeleton with reserved dimensions, not a bare spinner) · **partial** · **error** (cause *and* recovery, user input preserved) · **offline/stale** · **overflow** (long text, huge lists) · **underflow** (one character, zero items) · **permission-denied** · **success**

A blank region where data hasn't arrived, or a raw "Something went wrong", is a finding.

## 4. Performance & layout stability (HIGH)

- Image or media without dimensions / `aspect-ratio` — causes layout shift.
- Async content with no reserved space; content that visibly jumps on load.
- Animating `width`/`height`/`top`/`left` instead of `transform`/`opacity`.
- Long list not virtualized beyond ~50 items.
- High-frequency handler (scroll, resize, input) not debounced or throttled.
- Fonts without `font-display: swap`, or every weight preloaded.
- Blocking work on the main thread pushing frames past ~16ms.

## 5. Layout & responsive (HIGH)

- Horizontal scroll on the page body. Wide content must scroll inside its own container.
- Fixed pixel container widths where the viewport varies.
- Body text under 16px on mobile (also triggers iOS auto-zoom).
- Line length outside ~35–60 characters (mobile) or ~60–75 (desktop).
- `100vh` on mobile instead of `min-h-dvh`.
- Content permanently hidden behind a fixed header or bottom bar.
- Safe areas ignored — content under the notch, Dynamic Island, or gesture bar.
- Landscape broken or untested.
- Nested scroll regions fighting the main scroll.

## 6. Visual consistency (MEDIUM)

- Off-scale spacing values — the clearest tell of unpolished work. Everything on a 4/8 rhythm or there's a reason.
- Mixed icon families, stroke widths, or arbitrary icon sizes.
- Emoji used as structural icons.
- Ad-hoc shadow values instead of one elevation scale.
- Raw hex in components instead of semantic tokens.
- Filled and outline icons mixed at the same hierarchy level.
- Inconsistent border radius across sibling components.
- More than one primary CTA competing on a screen.

## 7. Typography & colour (MEDIUM)

- Body line-height outside 1.5–1.75.
- Type sizes off the scale.
- Hierarchy carried by colour rather than size/weight/spacing.
- Dark mode built by inverting light values rather than using desaturated tonal variants.
- Grey-on-grey secondary text below contrast minimums.
- Proportional figures in numeric columns where tabular figures belong — numbers shift as they change.

## 8. Forms & feedback (MEDIUM)

- Validation on every keystroke instead of on blur.
- Errors collected at the top only, not beside the field.
- Failed submit that doesn't focus the first invalid field.
- Required fields unmarked.
- Long form with no draft persistence.
- Sheet/modal dismissing unsaved changes without confirmation.
- Toast that steals focus, or isn't announced to screen readers.
- Error text that states a problem but no fix.
- Wrong mobile keyboard type; autofill attributes missing.

## 9. Navigation (HIGH)

- Bottom nav over 5 items, or icon-only.
- Current location not visually marked.
- Back not restoring scroll position, filters, or input.
- Navigation stack silently reset, or unexpected jump to home.
- Modal used as a primary navigation flow.
- Key screen with no deep link.
- Navigation placement shifting between pages.
- Tab + sidebar + bottom nav mixed at one hierarchy level.
- Destructive item (delete account, log out) sitting among ordinary nav items.

## 10. Motion (MEDIUM)

- Duration outside 150–300ms for micro-interactions, or over 500ms anywhere.
- Linear easing on UI transitions.
- Exit animation as slow as or slower than its entrance.
- Animation that can't be interrupted, or that blocks input while running.
- Decorative motion communicating nothing.
- More than one or two elements animating for attention in a single view.
- Transition causing reflow or layout shift.

## 11. Charts & data (LOW–HIGH)

Load `dataviz` for the full treatment. Minimum bar: chart type matching the data question; legend present and near the chart; exact values reachable on hover/tap; axes labelled with units; meaning never carried by colour alone (pattern, shape, or direct label as well); empty and error states handled; responsive reflow on small screens; keyboard-reachable interactive elements; a text summary or table alternative for screen readers.

## Output

Report through `ReportFindings` when running as part of a review pass; otherwise a plain ranked list. Either way, every finding carries:

- **`file:line`** — where it is.
- **The concrete failure scenario** — the state or input that triggers it and what breaks. "Contrast is low" is not a finding; "secondary label `#9CA3AF` on `#F3F4F6` is 2.1:1, unreadable for low-vision users, at `Card.tsx:42`" is.
- **Severity**, per the priority table.
- **The category number**, so a reader can pull the underlying rule set.

Then the principle pass, reported separately so it can't be diluted by defect counts:

```
## Rams audit (via design-is)
| Principle | Score /3 | Evidence |
|---|---|---|
| Innovative | <n> | <file:line, measured value, or copy excerpt> |
| ... (ten rows) | | |

Verdict: <NEW | REFINE | REDESIGN>
```

Do not pad either list. Twelve real findings beat forty where thirty are nitpicks — a review nobody can act on is a review nobody acts on. If a category is genuinely clean, say so; that's information too. And if the defect pass is clean while the verdict is REDESIGN, lead with the verdict — that is the more important result, and burying it under "all checks passed" is how mediocre work ships.
