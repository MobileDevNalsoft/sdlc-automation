---
name: docs-guide
description: Use to write end-user documentation — task-oriented guides for people using the application, not developers reading its code — with screenshots driven by a checked-in manifest so they can be regenerated deterministically instead of hand-pasted. Requires a browser automation tool (Playwright MCP or equivalent); with none available it writes the guides and the manifest and reports screenshots NOT RUN, never a placeholder image and never an invented description of a screen it could not see.
---

# docs-guide

**Verb: guide.**

## Different audience, different rules

Every other skill in this plugin writes for developers and agents. This one
writes for **someone using the product who does not know or care how it is
built**. That changes what is correct:

| Developer docs | User guides |
|---|---|
| organised by architecture | organised by **task** — "Create an order", not "The Orders module" |
| naming internals is precise | naming internals is a leak — the user does not have a `features/orders` directory |
| "invalidates the query cache" | "the list updates automatically" |
| completeness matters | **completeness is harmful** — a guide covering every option buries the 5% people actually need |

**Structure by task, always.** A guide titled "Orders" is a reference nobody
reads. "How to place an order" is a guide. If you cannot phrase a section as
something the user is trying to *do*, it does not belong here.

## Screenshots: a manifest, never hand-pasted

The default failure mode of screenshot documentation is well known: the UI
changes, the screenshots do not, and within two releases the guide actively
misleads. Nobody re-takes forty screenshots by hand.

So screenshots are **declared as data and generated**, exactly like any other
build artifact. `templates/screenshot-manifest.json` is the shape:

```json
{
  "baseUrl": "http://localhost:5173",
  "outputDir": "docs/guides/images",
  "shots": [
    {
      "id": "order-form-empty",
      "route": "/orders/new",
      "viewport": [1280, 800],
      "waitFor": "[data-testid='order-form']",
      "actions": [],
      "mask": ["[data-testid='user-email']"],
      "file": "order-form-empty.png"
    }
  ]
}
```

Why each field earns its place:

- **`waitFor` a selector, never a fixed delay.** A `sleep(2000)` produces a
  screenshot of a spinner on a slow run and passes on a fast one — flaky in
  the worst way, because the artifact looks fine until someone reads it.
- **`mask`** blanks regions before capture. This is a **privacy control**:
  real names, emails, and account numbers must never be baked into a
  screenshot that ships in documentation. Masking is not cosmetic.
- **`viewport` is explicit** so the same shot is the same size every run, and
  a diff is a real UI change rather than a window-size change.
- **`id` is stable, `file` is derived.** Referencing shots by id in the
  markdown means renaming an image does not break every guide.

**Seed the app with fixture data, never a real account.** A guide screenshotted
against production is a data-leak incident waiting to happen, and it will
contain someone's real order history.

## When no browser tool is available

Write the guide text and the manifest, generate nothing, and report:

```
| Check | Result | Detail |
|---|---|---|
| screenshots | NOT RUN | no browser automation tool available |
```

**Three things are forbidden here**, and they are the tempting shortcuts:

1. **Do not describe a screen you have not seen.** "The Orders page shows a
   table with Date, Customer, and Total columns" is a *guess* unless you read
   the component or saw it rendered. Read the component and cite it, or write
   the step without the description.
2. **Do not emit placeholder images** or `![screenshot](TODO.png)` links. A
   broken image in shipped documentation is worse than no image, and it will
   survive to production because nobody re-reads a guide they just wrote.
3. **Do not report NOT RUN as a pass.** Same rule as everywhere else in this
   marketplace — an unrun step is a reportable state.

The manifest still ships. That is the point of the split: when a browser tool
is wired up later, the screenshots generate with no rewrite of the guides.

## Required structure per guide

1. **What you will accomplish** — one sentence, in the user's words.
2. **Before you start** — prerequisites, permissions, required data.
3. **Steps** — numbered, one action each, screenshot only where the UI is
   genuinely ambiguous.
4. **How you know it worked** — the observable confirmation. Routinely
   omitted, and it is the step that tells a user whether to keep going or
   call support.
5. **If it doesn't work** — the two or three realistic failure modes and what
   to do. Map these to the **actual error states the code produces** (the
   `ApiError` kinds, the validation messages) rather than inventing generic
   advice.

## Screenshot only where words fail

Every screenshot is a maintenance liability. Take one when the UI is genuinely
ambiguous — an unlabelled icon, a specific spot in a dense form, a screen
whose layout is the information. Do **not** screenshot a page just to prove it
exists, and do not screenshot a step whose instruction is "click Save".

A guide with six well-chosen screenshots stays accurate far longer than one
with forty, because there is less to go stale and someone might actually
regenerate six.

## Keeping guides honest over time

- Regenerate screenshots whenever the manifest's routes change; a UI diff that
  touches a screenshotted route should regenerate that shot in the same
  change.
- Date each guide, and record the app version it was written against.
- When a feature is removed, delete its guide. A guide for a feature that no
  longer exists is the most confusing artifact in any documentation set.

## Cross-references

- `docs-architect:docs-onboarding` is the developer-facing counterpart. Do not
  cross-link them into each other's audiences — a user guide linking to an
  architecture doc is a leak, and vice versa.
- `sdlc-core:ui-ux-review` audits the UI these guides document; if a guide
  needs three paragraphs to explain one screen, that is a UI finding, not a
  documentation problem.
- `docs-architect:docs-reference` covers the API for integrators — a different
  audience again, and not a substitute for either.
