---
name: flutter-slice
description: Use to implement one vertical feature slice in a Flutter/flutter_bloc project already scaffolded by flutter-bootstrap — Service (raw API calls) to Repository (Result<T>) to Cubit (freezed sealed state) to Screen (exhaustive switch). Dispatched by sdlc-developer by name (flutter-sdlc:flutter-slice) for any Flutter task; owns the vertical-slice template and stack conventions so sdlc-developer doesn't re-derive them. The Repository layer is mandatory for new features only — never retrofit it onto existing code as a blanket requirement.
---

# flutter-slice

**Verb: slice.**

## Framing

Like the rest of `flutter-sdlc`, these templates were built from a prior
design pass's research plus live fetches done this session (cited inline
below) — not by running `flutter analyze`/`flutter test` against a real
project this session, since no locally-accessible Flutter project was
available. `dart format` was run against every `.dart` file in this
directory (`dart format` from the local Dart SDK, no pub packages needed for
a formatting pass) and every file parsed and formatted cleanly — that is the
one piece of verification these templates actually got.

## The seam, in order

```
Service (data/services/)      raw API calls; throws on failure; knows HTTP
   -> Repository (data/repositories/)   catches everything; returns Result<T>
        -> Cubit (presentation/bloc/)  switches on Result<T>; emits freezed state
             -> Screen (presentation/screens/)  exhaustive switch on state; builds UI
```

Each layer only talks to its immediate neighbor: a Screen never imports a
Service or Repository directly, and a Cubit never imports `package:http` (or
any other HTTP client) directly. This isn't a style preference — it's what
makes each layer replaceable and testable in isolation. A Cubit can be unit
tested against a fake `Repository` with no network call and no widget tree
involved (see `flutter-verify`'s `bloc_test` usage); a Repository can swap
its data source (a different backend, a local cache, a mock) without the
Cubit or Screen above it changing at all; and there is exactly one place —
the Repository — where a thrown exception is translated into the typed
`Result<T>` the rest of the app switches on exhaustively, instead of every
layer needing its own error-handling story.

This layering is the same shape Google's own `app-architecture` guidance
prescribes (MVVM + repository layer + a command-like operation triggered from
the view) — **that guidance does not endorse bloc or Riverpod by name**, and
its own reference app uses bare `provider` for dependency injection only, not
as a state-management pattern. This plugin uses `flutter_bloc` because it
satisfies the same layering equally well (Cubit as the ViewModel-equivalent
sitting on top of the Repository) while additionally giving a falsifiable,
per-state-transition test assertion via `bloc_test` (see `flutter-verify`) —
not because of any claim that Google recommends it.

## State management: `flutter_bloc` is settled; Cubit vs. full `Bloc` is the only open choice

`flutter_bloc` (built on `package:bloc`) is this stack's state-management
library, full stop — a settled decision, not something to re-evaluate per
feature. Riverpod, GetX, `provider` used as a state-management pattern,
signals-based packages, and MobX are surveyed and not used here; see
flutter-bootstrap's SKILL.md ("what this skill deliberately does not do")
for the full cut list, and don't reopen that decision while planning a
feature.

The only choice left per feature is **Cubit vs. full `Bloc`**, and the rule
is plain:

- **Default to `Cubit`.** Nearly every feature is a direct method call
  (`load()`, `submit()`, `refresh()`) that triggers one asynchronous
  operation and emits a new state when it resolves — exactly what
  `product_cubit.dart` does below. No event class, no `on<Event>` handler,
  no event transformer. If a feature doesn't need anything in the next
  bullet, it needs a `Cubit` and nothing more.
- **Reach for a full `Bloc`** only when the feature genuinely needs an
  *event stream* with a transformer applied to it — for example, debouncing
  a search-as-you-type field, throttling a scroll-triggered pagination
  request, or restarting/dropping in-flight work when a newer event of the
  same type arrives before the previous one finished. `package:bloc_concurrency`
  (`restartable()`, `droppable()`, `sequential()`, `concurrent()`) is the
  standard way to express that on top of `Bloc`'s `on<Event>(transformer:
  ...)` parameter — fetched from pub.dev's package API: latest `0.3.0`,
  published 2025-01-12, so (like `bloc_test`, see `flutter-verify`) it is
  genuinely stale relative to core `bloc`'s more recent releases; treat a
  `bloc_concurrency` upgrade as its own verified change if one is ever
  needed, not a drive-by pin bump. If nothing in the feature needs
  debounce/throttle/concurrency control over a stream of triggering events,
  that absence *is* the signal it's a `Cubit` — don't reach for the
  event-driven shape "for consistency" when nothing demands it.

Either way, state is an immutable, exhaustively-matchable sealed type (see
"Cubit + freezed sealed state" below) — that property holds regardless of
which of the two base classes emits it, which is why a UI can `switch` over
either with no `default:` arm and an unhandled state becomes a compile error
instead of a blank screen.

## Templates (all in `templates/`, using a worked `product` feature as the running example)

`Product` (a placeholder catalog item — `id`, `name`, `price`, `createdAt`)
is a deliberately generic, obviously-illustrative entity, not a real feature
from any project. Swap it for whatever the real feature is.

| File | Layer | Target path (relative to `lib/features/<feature>/`) |
|---|---|---|
| `result.dart` | shared | `lib/core/result.dart` — **not** under `features/`; every feature's Repository returns this, so it belongs in the shared layer `tools/check_boundaries.dart` (flutter-bootstrap) exempts from the cross-feature-import check. Copy once per project, not once per feature. |
| `product_service.dart` | Service | `data/services/product_service.dart` |
| `product_dto.dart` | Service (DTO) | `data/dto/product_dto.dart` |
| `product_model.dart` | Domain | `domain/product_model.dart` |
| `product_repository.dart` | Repository | `data/repositories/product_repository.dart` |
| `product_state.dart` | Cubit (state) | `presentation/bloc/product_state.dart` |
| `product_cubit.dart` | Cubit | `presentation/bloc/product_cubit.dart` |
| `product_screen.dart` | Screen | `presentation/screens/product_screen.dart` |

Note the folder is `presentation/bloc/`, not `presentation/cubit/`, even though
this template only ever defines a `Cubit` subclass, never a full `Bloc`
subclass — `bloc/` is the name `flutter-verify`'s coverage ratchet scopes to
(alongside `services/`), matching a naming convention common across the
`flutter_bloc`/`package:bloc` ecosystem where a `bloc/` folder holds Cubits
too (Cubit is part of `package:bloc`, just without explicit events). Naming it
`cubit/` instead would be equally defensible in isolation, but would silently
break the coverage-ratchet path match — so this skill and `flutter-verify`
agree on `bloc/` rather than each guessing independently.

To slice a new feature: copy all eight files, rename every `Product*`
identifier and the two path segments (`product` -> `<feature>`,
`ProductX` -> `<Feature>X`), and replace the one HTTP call in the Service with
the feature's real endpoint(s). `result.dart` is the one file that is *not*
copied per-feature — it already exists in `lib/core/` after
`flutter-bootstrap` runs.

## Result&lt;T&gt;: sealed, not exceptions-as-control-flow

`core/result.dart` is a plain Dart 3 `sealed class Result<T>` with two
subtypes, `Success<T>` and `Failure<T>` (carrying an `AppError`). This is
**not** a `freezed` class — freezed is reserved for the Cubit's state (below)
per this marketplace's design; `Result<T>` is deliberately the simplest
possible sealed type because it only ever needs two variants and no
generated `copyWith`/`toJson`. A `Repository` method's return type is always
`Future<Result<T>>`, never `Future<T>` with a thrown exception — the
`Cubit` layer `switch`es on the result instead of wrapping every call in
`try`/`catch`.

The `Repository` implementation is the *only* place a `try`/`catch` for this
feature's Service exceptions is allowed to live — every `catch` clause there
has an explicit `on` type (`avoid_catches_without_on_clauses`, vendored in
`flutter-bootstrap`'s `analysis_options.yaml`, fails a bare `catch (e)`).

**The Repository layer is mandatory for new features only.** Do not retrofit
a `Repository`/`Result<T>` wrapper onto an existing feature that already
calls a Service directly, just because a new feature nearby now has one —
that is a separate, deliberately-scoped migration a plan should call out on
its own, not something this skill forces as a drive-by refactor.

## DTO / domain split

`product_dto.dart` is a `json_serializable@6.14.0` class (`json_annotation@4.12.0`)
annotated with a bare `@JsonSerializable()` — `field_rename: snake` is set
once, project-wide, in `flutter-bootstrap`'s `build.yaml`, so a field like
`createdAt` maps to a backend `created_at` key with no per-field `@JsonKey`
override. `product_model.dart` is a plain domain class with **zero** import of
`json_annotation`/`json_serializable` — `ProductDto.toDomain()` is the one
place the mapping happens. This split exists so whatever JSON casing
convention the real backend uses never leaks past the data layer into
anything a `Cubit` or `Screen` touches — delete the `field_rename: snake`
line in `build.yaml` if the target backend already returns lowerCamelCase.

Run `dart run build_runner build --delete-conflicting-outputs` after adding or
changing a DTO — `product_dto.g.dart` is generated, not hand-written (and is
already excluded from analysis and coverage by `flutter-bootstrap`'s
`analysis_options.yaml`/`build.yaml`).

## Cubit + freezed sealed state — verified syntax, not memory

`product_state.dart` uses `sealed class ProductState with _$ProductState` —
**not** the older `@freezed class ProductState with _$ProductState` shape.
This was checked directly against freezed's own migration guide
(`rrousselGit/freezed`, `packages/freezed/migration_guide.md`, "Migrate from
v2 to v3" section) because freezed 3.x made the `sealed`/`abstract` keyword
mandatory on the class itself and stopped generating `.when`/`.map` entirely
— pattern matching goes through Dart's own `switch`, which is exactly what
`product_screen.dart` does. Pinned: `freezed@3.2.5`, `freezed_annotation@3.1.0`
(both fetched live from pub.dev's package API — these are fetched-latest
values, re-verified before this rewrite, not carried over from memory).

`ProductCubit.load()` (`product_cubit.dart`) is the only place a `Result<T>`
is `switch`ed on; it never leaks a `Result` into `ProductState` — the Cubit
maps `Success`/`Failure` into `ProductState.loaded`/`ProductState.error`
before emitting, so the Screen only ever depends on `ProductState`.

## Screen: exhaustive switch, no default case

`product_screen.dart`'s `BlocBuilder` `builder` callback is a Dart `switch`
expression over `ProductState` with one case per freezed subtype and **no**
`default:` arm. Because `ProductState` is `sealed`, omitting a case (or
adding a fifth state variant later without updating the switch) is a
compile-time error — the vendored `no_default_cases` lint rule
(`flutter-bootstrap`'s `analysis_options.yaml`) is the second line of defense
in case a `default:` case gets reintroduced during a later refactor by
someone unaware of why it was left out.

**This skill decides state-to-widget mapping, not visual design.** Which
state produces which widget subtree is this skill's job; typography,
spacing, color, motion, and platform-convention decisions are not — those
belong to a separate UI/UX skill pairing in this same marketplace:
`sdlc-core:ui-ux-mobile` for making those design decisions and
`sdlc-core:ui-ux-review` for auditing them retroactively. `flutter-slice`
does **not** make visual design decisions itself; treat `product_screen.dart`
as a structural skeleton to hand off to those skills, not a finished design.

## What this skill does not decide

- Navigation/DI wiring for the Screen (how it gets a `ProductCubit` — via
  `BlocProvider`, `RepositoryProvider`, or the project's existing pattern) is
  intentionally left to the slice's plan; this skill's `product_screen.dart`
  assumes a `ProductCubit` is already available via `context.read`/
  `BlocBuilder`'s implicit lookup, same as any `flutter_bloc` app.
- Visual design (see the UI/UX cross-reference above) — layout, styling, and
  interaction polish are `sdlc-core:ui-ux-mobile`/`sdlc-core:ui-ux-review`'s
  job, not this skill's.
- `go_router` — adopting it (see `flutter-bootstrap`'s SKILL.md) is its own
  separate, recommended-not-required decision; nothing here assumes it's
  present.
