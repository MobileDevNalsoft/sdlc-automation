---
name: ui-ux-mobile
description: Use when designing or reshaping any mobile app UI — a screen, sheet, tab flow, form, list, or component — in Flutter, React Native, SwiftUI, or Jetpack Compose. Owns visual and interaction decisions (layout, hierarchy, type, colour, spacing, motion, gestures, safe areas, platform idioms) so stack skills like flutter-sdlc:flutter-slice never make them ad hoc. For web UI use ui-ux-web; to audit UI that already exists use ui-ux-review.
---

# ui-ux-mobile

**Verb: design (mobile).**

Design as someone who has shipped to both stores for fifteen years. The difference from web is not just screen size — it's that a phone is held in one hand, used in motion, interrupted constantly, and governed by two platforms with genuine opinions about how apps should behave. Fighting those opinions produces an app that feels wrong in a way users can't articulate but do abandon.

## Three layers, invoked in this order

This skill orchestrates three others. **Taste first, data second, compliance last** — start from a palette database and you get a compliant, forgettable app.

| Order | Skill | What it owns | Failure it prevents |
|---|---|---|---|
| 1 | **`frontend-design`** | Aesthetic direction, the design plan, typography personality, the one signature element, microcopy | Being **generic** |
| 2 | **`ui-ux-pro-max`** | The data: palettes, font pairings, styles, product-type patterns, per-stack guidance | Reinventing solved problems |
| 3 | **`ui-ux-review`** | Accessibility/touch/state audit, plus a Rams-principle audit via **`design-is`** | Being **wrong** or **unfinished** |

**Load `frontend-design` before looking up a palette.** It is the only one addressing distinctiveness, and it is concrete about how AI-generated design fails — it collapses into a few recognisable looks that show up regardless of subject. A rules database can't catch that, because "generic" breaks no rule. Use its two-pass discipline: write the design plan (color / type / layout / signature), critique it for templated defaults, revise, then build.

**The mobile-specific caveat:** distinctiveness is spent on brand surfaces — onboarding, empty states, the signature interaction, motion character, iconography — *not* on reinventing navigation, controls, or gestures. Users learn those from their OS, and a novel tab bar is a cost they pay rather than a feature. Take the aesthetic risk somewhere it doesn't fight muscle memory.

## Where the raw design data comes from — don't reinvent it

The `ui-ux-pro-max` skill carries a searchable database: **85 styles, 161 colour palettes, 74 font pairings, 162 product types with reasoning rules, 99 UX guidelines, 26 chart types, and 16 per-stack guideline sets.** Invoke it and query it rather than inventing a palette or guessing a font pairing.

Relevant stack names (all present in the dataset even though its SKILL.md advertises only `react-native`):

`flutter` · `react-native` · `swiftui` · `jetpack-compose`

```bash
# Start here: full design system with reasoning
python scripts/search.py "<product type> <industry> <tone>" --design-system -p "<Project>"

# Deep-dive a dimension
python scripts/search.py "<keywords>" --domain style
python scripts/search.py "<keywords>" --domain color
python scripts/search.py "<keywords>" --domain typography
python scripts/search.py "<keywords>" --domain ux

# App-interface rules (safe areas, touch, Dynamic Type, platform a11y APIs)
python scripts/search.py "<keywords>" --domain web

# Stack-specific implementation guidance
python scripts/search.py "<keywords>" --stack flutter
```

Use `--design-system --persist` to write `design-system/MASTER.md` plus per-screen overrides on any app beyond a few screens.

For charts, dashboards, or any data display, load the `dataviz` skill as well — it owns chart-form choice, categorical/sequential palette construction, and accessible encoding. Don't invent chart colours here. Mobile charts additionally need ≥44pt tap areas on interactive marks and simplified forms at small widths.

## Platform idioms — the thing web designers get wrong first

You are targeting two platforms with different conventions. Decide deliberately whether this app is **platform-adaptive** (follows each platform's native idiom) or **brand-consistent** (looks identical on both). Both are legitimate; choosing by accident is not. Write the choice down.

| Concern | iOS (HIG) | Android (Material) |
|---|---|---|
| Top-level navigation | Bottom tab bar | Bottom nav bar, or navigation rail on large screens |
| Back | Swipe-from-left edge + explicit back | System back gesture / button, predictive back |
| Screen title | Large title collapsing on scroll | Top app bar |
| Modal | Sheet, swipe-down to dismiss | Bottom sheet / full-screen dialog |
| Press feedback | Opacity / subtle scale | Ripple from touch point |
| Primary control | System controls, SF Symbols | Material components, Material Symbols |
| Transient message | Toast-style overlay | Snackbar, optionally with action |

In Flutter this is an explicit decision, since Material renders on iOS too and will look subtly foreign there unless you intend it.

## The order decisions get made in

0. **Direction, via `frontend-design`.** Name the subject, audience, and this screen's single job. Produce the design plan — palette, type roles, layout concept, and the one signature element — and critique it for templated defaults before writing code. Then decide platform-adaptive vs. brand-consistent (below), because that choice constrains everything after it.
1. **What job is this screen doing?** One sentence, one primary action. On mobile the constraint is harsher than web — a screen doing three things does none of them well at 375pt wide.
2. **Thumb reachability.** Where do the hands go? Primary actions belong in the lower-middle third; destructive actions do not belong next to them. Top corners are the hardest reach on a large phone.
3. **Information hierarchy** via size, weight, spacing, position — not colour alone.
4. **Layout on a 4/8dp rhythm**, respecting safe areas from the start (see below) rather than patching them later.
5. **Every state** (see the table further down).
6. **Gestures** — and always a visible control alongside any gesture.
7. **Motion, last**, once the static design is right.

## Safe areas and system chrome

The most common mobile layout defect. Every fixed header, tab bar, bottom CTA, and floating action button must respect:

- The status bar, notch, and Dynamic Island at the top.
- The home indicator / gesture bar at the bottom — a bottom button flush to the screen edge competes with the system's back gesture.
- Rounded display corners, where content clips invisibly.
- Landscape insets, which differ from portrait on both platforms.

Scrollable content needs bottom and top insets so list items aren't permanently hidden behind fixed bars. Never block a system gesture region with an app gesture.

## Touch

- **≥44×44pt (iOS) / ≥48×48dp (Android)** for anything tappable. If the visual is smaller, expand the hit area — Flutter's tap targets, React Native's `hitSlop`.
- **≥8dp between targets.** Adjacent small targets produce mis-taps, which on a destructive action is a real failure.
- **Visual feedback within 100ms** of touch — ripple, opacity, or scale (0.95–1.05).
- **Never require precision.** Thin edges and tiny icons are hostile on a moving bus.
- **Gestures need affordances.** A swipe action nobody can discover doesn't exist. Show a chevron, a peek, or a first-run hint — and always provide a visible control that does the same thing.
- **Use a movement threshold before starting a drag**, or scrolling triggers accidental drags.
- **Haptics for confirmation and consequential actions only.** Overused haptics get the whole app muted.

## The states you must design

| State | What it must do |
|---|---|
| **Empty** | Explain and offer the filling action. Distinguish first-run from filtered-to-nothing. |
| **Loading** | Skeleton/shimmer matching final layout beyond ~300ms, dimensions reserved. Not a centred spinner over a blank screen. |
| **Offline** | Mobile networks fail constantly. Say what's stale, when it was fetched, and what still works offline. This is not an edge case. |
| **Slow network** | Degrade: lower-res images, fewer animations. Don't just wait. |
| **Error** | Cause plus recovery path, and never lose the user's input. |
| **Interrupted** | A call, notification, or backgrounding mid-flow. Multi-step forms auto-save drafts; a dismissed sheet with unsaved changes confirms first. |
| **Long / short text** | Dynamic Type at largest setting, and one-character names. Prefer wrapping to truncation; when truncating, make the full value reachable. |
| **Permission denied** | Camera/location/notifications refused — explain the consequence and offer the settings path. Never a dead control. |
| **Success** | Brief, specific confirmation, then out of the way. |

## Non-negotiables

- **Contrast** 4.5:1 body, 3:1 large text and meaningful glyphs — verified separately in light and dark.
- **Dynamic Type / system font scaling** supported without layout breakage or clipped text.
- **Screen reader** (VoiceOver / TalkBack): meaningful labels on every control, reading order matching visual order, state changes announced. Icon-only buttons always carry a label.
- **`prefers-reduced-motion`** equivalent respected on both platforms.
- **Never colour alone** to convey meaning.
- **Visible labels**, not placeholder-only.
- **Semantic keyboard types** per field (email, tel, number) — and autofill attributes wired, so password managers work.
- **One primary action per screen**; secondary actions visually subordinate; destructive actions in the platform's danger colour and spatially separated.
- **Semantic colour tokens**, never per-screen hex, with light and dark mapped together.
- **One icon family**, consistent stroke and size tokens. Emoji are not icons.
- **Deep-linkable screens** — anything reachable from a notification or share link needs a route.
- **Back must be predictable**: restore scroll position, filters, and input. Never silently reset the navigation stack.
- **Bottom nav ≤5 items**, icon *and* label, current destination clearly marked, top-level destinations only.

## Motion

150–300ms micro-interactions, ≤400ms transitions. Prefer spring/physics curves — on mobile they read as natural where cubic-bezier reads as mechanical. Exits at ~60–70% of entrance duration.

Modals and sheets animate from their trigger for spatial context. Forward navigation moves left/up, backward right/down — consistently. Shared-element transitions preserve continuity between list and detail. Animation is always interruptible, never blocks input, and never causes layout reflow.

Keep per-frame work under ~16ms for 60fps. Virtualize lists beyond ~50 items. Animate transform/opacity equivalents, not layout properties.

## What this skill does not decide

State management, repository/service layering, navigation wiring, and build config belong to the stack skill (`flutter-sdlc:flutter-slice`, which uses `flutter_bloc` with Cubit as its default). This skill decides appearance and behaviour; that one decides construction. On conflict, the stack skill wins on structure, this one on interaction and appearance.

## Restraint and copy

Spend your boldness in one place — the signature element carries the identity, everything around it stays quiet. Cut decoration that doesn't serve the brief; note that refusing any risk is itself a risk, since the result is the default look.

Copy is design material, not labelling. Name things by what the person controls, not how the system works. Active voice, and an action keeps its name through the flow — a "Publish" button produces a "Published" confirmation, never "Success". Errors say what happened and how to fix it without apologising. Empty states invite action. Mobile amplifies this: there's no room for filler, and generic copy reads as templated as generic layout.

## Before handing off

Run `ui-ux-review` against what you built — it covers the accessibility/touch/state checklist and a Rams-principle pass. Test on a small phone (375pt), a large phone, and in landscape, with largest Dynamic Type and reduced motion enabled, in both themes.
