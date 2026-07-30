---
name: ui-ux-web
description: Use when designing or reshaping any web UI — a page, screen, dashboard, form, table, modal, or component — in React, Next.js, Vue, Svelte, Angular, Astro, or plain HTML/Tailwind. Owns visual and interaction decisions (layout, hierarchy, type, color, spacing, motion, states, responsive behaviour) so stack skills like react-sdlc:react-slice never make them ad hoc. For mobile app UI use ui-ux-mobile; to audit UI that already exists use ui-ux-review.
---

# ui-ux-web

**Verb: design (web).**

You are designing as someone with fifteen years of shipped product behind them. That does not mean more decoration — it means fewer, better-justified decisions, and no unfinished edges. Amateur UI fails in two independent ways: it is *incomplete* (handles the happy path, forgets the other eight states) and it is *generic* (breaks no rule, looks like everything else). You have to beat both, and they need different tools.

## Three layers, invoked in this order

This skill orchestrates three other skills. The order is the important part — **taste first, data second, compliance last.** Start from a palette database and you get a compliant, forgettable page.

| Order | Skill | What it owns | Failure it prevents |
|---|---|---|---|
| 1 | **`frontend-design`** | Aesthetic direction, the design plan, typography personality, the one signature element, microcopy | Being **generic** |
| 2 | **`ui-ux-pro-max`** | The data: palettes, font pairings, styles, product-type patterns, per-stack guidance | Reinventing solved problems |
| 3 | **`ui-ux-review`** | Accessibility/touch/state audit, plus a Rams-principle audit via **`design-is`** | Being **wrong** or **unfinished** |

**Load `frontend-design` before you look up a single palette.** It is the only one of the three that addresses distinctiveness, and it is specific about how AI-generated design fails: it clusters into a handful of recognisable looks that appear regardless of subject. A rules database cannot catch that, because "generic" violates no rule. Take its two-pass discipline seriously — write the design plan (color / type / layout / signature), critique it against the brief for templated defaults, revise, *then* build.

Where the brief pins down a direction, the brief wins outright. Where it leaves an axis free, don't spend that freedom on a default.

## Where the raw design data comes from — don't reinvent it

The `ui-ux-pro-max` skill carries a searchable database: **85 styles, 161 colour palettes, 74 font pairings, 162 product types with reasoning rules, 99 UX guidelines, 26 chart types, and 16 per-stack guideline sets.** Invoke that skill and query it rather than inventing a palette or guessing a font pairing.

Its own SKILL.md advertises only `react-native` as a stack, but the underlying dataset covers far more. These stack names all work and are the ones relevant here:

`react` · `nextjs` · `shadcn` · `html-tailwind` · `vue` · `nuxtjs` · `nuxt-ui` · `svelte` · `angular` · `astro` · `threejs` · `laravel`

Typical calls (resolve the script path from the skill's own base directory — don't hardcode a version-pinned path, it moves between releases):

```bash
# Always start here: full design system with reasoning, for a product type
python scripts/search.py "<product type> <industry> <tone>" --design-system -p "<Project>"

# Then deep-dive whichever dimension you're unsure about
python scripts/search.py "<keywords>" --domain style
python scripts/search.py "<keywords>" --domain color
python scripts/search.py "<keywords>" --domain typography
python scripts/search.py "<keywords>" --domain landing
python scripts/search.py "<keywords>" --domain ux
python scripts/search.py "<keywords>" --domain chart

# Stack-specific implementation guidance
python scripts/search.py "<keywords>" --stack react
```

`--design-system --persist` writes a `design-system/MASTER.md` plus per-page override files. Use it on any project with more than a couple of screens — a design system that only exists in one conversation is not a design system.

For chart and dashboard work specifically, also load the `dataviz` skill: it owns chart-form choice, categorical/sequential palette construction, and accessible encoding. Don't invent chart colours here.

## The order decisions get made in

Working out of order is what produces UI that looks arbitrary. Hierarchy before aesthetics, always.

0. **Direction, via `frontend-design`.** Name the subject, its audience, and the page's single job. Produce the design plan — 4–6 named palette values, display/body/utility type roles, a layout concept, and the one signature element this screen will be remembered by. Critique it for templated defaults before writing any code. Skip this step and everything downstream is competent and forgettable.
1. **What job is this screen doing?** One sentence. What does the person need to accomplish, and what is the single most important thing on the screen? If you can't name one primary action, the screen isn't designed yet — it's a container.
2. **Information hierarchy.** Rank every element: primary, secondary, tertiary, incidental. Then express that ranking with **size, weight, spacing, and position** — not colour alone. Colour-only hierarchy fails in greyscale, in dark mode, and for colour-blind users.
3. **Layout and rhythm.** Pick a spacing scale (4/8px increments) and a type scale, then *stay on them*. Off-scale values are the single most common tell of unpolished work. Establish a max content width; long-form text sits at 60–75 characters per line.
4. **Component and pattern choice.** Query `--domain product` for the conventions of this product type. Use the boring, expected pattern unless you have a specific reason not to — novelty in navigation is a cost users pay, not a feature.
5. **Every state** (see below). This is the step that separates finished from unfinished.
6. **Motion, last.** Only after the static design is right. Motion clarifies causality and continuity; it is never decoration.

## The states you must design, not just the happy one

For every view and every component that fetches, submits, or can be empty:

| State | What it must do |
|---|---|
| **Empty** | Explain why it's empty and offer the action that fills it. Never a blank region. First-run empty ≠ filtered-to-nothing empty — they need different copy. |
| **Loading** | Skeleton matching the eventual layout for anything over ~300ms. Reserve the final dimensions so nothing jumps when data lands. |
| **Partial** | Some data arrived, some didn't. Don't block the whole view on the slowest request. |
| **Error** | State the cause *and* the recovery path. "Something went wrong" is not an error message. Keep the user's input — never make them retype after a failure. |
| **Offline / stale** | Say the data may be out of date, and when it was last fetched. |
| **Too much data** | 10,000 rows, a 200-character name, a 40-item nav. Decide now: virtualize, paginate, truncate-with-full-text-available, or wrap. |
| **Too little / long text** | One-character names and untruncatable German compound nouns both break naive layouts. |
| **Permission-denied** | Hide it, or show it disabled with the reason. Never a control that fails silently on click. |
| **Success** | Confirm briefly and specifically. Then get out of the way. |

## Non-negotiables

These are not stylistic preferences; shipping without them is a defect.

- **Contrast**: 4.5:1 body text, 3:1 large text and meaningful UI glyphs. Verify with a tool, don't eyeball it.
- **Visible focus** on every interactive element, 2px minimum. Never `outline: none` without a stronger replacement — keyboard users navigate by it.
- **Keyboard reachable**: every action, in an order matching the visual layout. Modals trap focus and restore it on close; `Esc` closes.
- **Semantic HTML first.** A `<div>` with a click handler is not a button — it loses focus, keyboard activation, and screen-reader role for free. Reach for ARIA only when no element carries the semantics.
- **Hit targets** ≥24×24px on pointer, ≥44×44px on touch, with 8px of separation.
- **Never colour alone** to convey meaning — pair it with an icon, label, or shape.
- **Labels stay visible.** A placeholder is not a label; it disappears exactly when the user needs it.
- **Errors sit next to the field they describe**, and the first invalid field takes focus on failed submit.
- **Confirm destructive actions**, or offer undo. Undo is the better pattern where it's feasible.
- **`prefers-reduced-motion`** respected — reduce or remove non-essential animation.
- **Zoom never disabled.** `user-scalable=no` is an accessibility failure.
- **Design light and dark together.** Dark mode uses desaturated tonal variants, not inverted values, and its contrast is verified independently.
- **Semantic colour tokens** (`surface`, `on-surface`, `primary`, `danger`), never raw hex in components — it's what makes theming and dark mode tractable.
- **SVG icons from one family**, consistent stroke width and size tokens. Emoji are not icons: they render differently on every platform and can't be themed.

## Motion, used correctly

150–300ms for micro-interactions, up to 400ms for larger transitions, never beyond 500ms. Exits run at roughly 60–70% of entrance duration — it makes the UI feel responsive rather than sluggish.

Animate `transform` and `opacity` only. Animating `width`, `height`, `top`, or `left` triggers layout on every frame and janks. Ease-out for entering, ease-in for exiting; linear reads as mechanical for UI.

Animation must be interruptible — a user's click cancels it immediately, and input is never blocked while something is moving. Stagger list entrances 30–50ms per item. Every animation should express a cause-and-effect relationship; if you can't say what a motion communicates, delete it.

## Responsive

Mobile-first, then scale up. Systematic breakpoints (375 / 768 / 1024 / 1440). No horizontal scroll on the page body — wide content (tables, code, diagrams) scrolls inside its own container. Body text at 16px minimum on mobile, which also prevents iOS auto-zoom on focus. Prefer `min-h-dvh` to `100vh`. Verify at 375px and in landscape before calling it done.

## What this skill does not decide

Component file placement, state-management wiring, data fetching, and cache invalidation belong to the stack skill (`react-sdlc:react-slice`). This skill decides what the interface looks like and how it behaves; that one decides how it's built. When they appear to conflict, the stack skill wins on structure and this one wins on interaction and appearance.

## Restraint

Spend your boldness in one place. The signature element is the memorable thing; everything around it stays quiet and disciplined. Cut decoration that doesn't serve the brief — and note that *not* taking a risk is itself a risk, because the result is the templated default. Match execution to ambition: maximalist directions need elaborate follow-through, minimal ones need precision in spacing and type. Elegance is executing the chosen direction well, not doing less of it.

## Copy is design material

Words exist to make the interface easier to understand, so give them the same intentionality as spacing. Name things by what the person controls, not how the system is built. Active voice, and an action keeps its name through the whole flow — a "Publish" button produces a "Published" toast, never "Success". Errors state what happened and how to fix it, in the interface's voice, without apologising. An empty state is an invitation to act, not a shrug. Generic copy makes a design feel as templated as generic layout does.

## Before handing off

Run `ui-ux-review` against what you built — it covers both the accessibility/state checklist and a Rams-principle pass. Designing and reviewing are different passes, and doing both in one go is how gaps survive.
