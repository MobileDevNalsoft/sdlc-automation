---
name: flutter-slice
description: Use to implement one vertical feature slice in a Flutter/flutter_bloc project already scaffolded by flutter-bootstrap — Service (injected Dio) to Repository (Result<T>) to Cubit (freezed sealed state) to Screen (exhaustive switch, built from shared/widgets + design tokens + l10n) to route (go_router) to DI registration (get_it). Dispatched by sdlc-developer by name (flutter-sdlc:flutter-slice) for any Flutter task; owns the vertical-slice template and stack conventions so sdlc-developer doesn't re-derive them. The Repository layer is mandatory for new features only — never retrofit it onto existing code as a blanket requirement.
---

# flutter-slice

**Verb: slice.**

## Honesty notice — read before trusting anything below

**Toolchain these templates were written against: Flutter 3.41.6 / Dart
3.11.4, verified live on 2026-07-30** by running the SDK, not by reading a
doc. An earlier revision of this skill assumed Flutter 3.44.8 / Dart 3.12.2;
that was wrong against the installed SDK, and several pins in the stack exist
*because* of the older toolchain (see flutter-bootstrap's dependency table).

Every version number in this file is either fetched from
`https://pub.dev/api/packages/<name>` on the date stated at the point of the
claim, or carries a literal `ASSUMPTION:` marker where the claim is made.
There is no end-of-file caveat section, deliberately: a caveat that is not
adjacent to the claim it qualifies does not get read.

**No template in this directory was executed against a Flutter project during
the revision that introduced dio/get_it/go_router/tokens/l10n.** They were
written by reading the target APIs and the vendored ruleset. The one thing
they did get is `dart format`, which every file passes. Two specific
unverified dependencies, flagged here because feature code depends on them:

- `ASSUMPTION:` `lib/shared/widgets/app_scaffold.dart`'s constructor is
  `const AppScaffold({required Widget body, String? title, List<Widget>?
  actions, Widget? bottomAction, bool safeArea = true, Key? key})`. That is
  the shape the architecture spec mandates and the shape
  flutter-bootstrap's `app_router.dart` imports, but the widget's source was
  not read when this file was written. Check it before copying
  `product_screen.dart` verbatim.
- `ASSUMPTION:` the ARB's ICU `"format": "currency"` and `"format": "yMMMd"`
  spellings, and the `optionalParameters` key used with them, were not
  re-verified against Flutter 3.41.6's `gen-l10n` this session. Run
  `flutter gen-l10n` after adding them and read the error if there is one;
  the *principle* (format numbers and dates in the ARB, never with string
  interpolation in Dart) holds regardless of the exact spelling.

## The seam, in order

```
Service (data/services/)        raw API calls over an INJECTED Dio; throws
                                DioException; knows HTTP; knows no baseUrl
  -> Repository (data/repositories/)   catches DioException/FormatException;
                                       returns Result<T>; maps to AppError
    -> Cubit (presentation/bloc/)      switches on Result<T>; emits freezed
                                       sealed state; imports no HTTP client
      -> Screen (presentation/screens/) exhaustive switch on state; builds UI
                                        from shared/widgets + tokens + l10n
        -> Routes (presentation/<f>_routes.dart)  the feature's GoRoutes,
                                                  spread by core/router/
```

Each layer talks only to its immediate neighbour. A Screen never imports a
Service or Repository directly, and **a Cubit never imports `package:dio`**
(the previous revision of this line said `package:http`; the client changed,
the rule did not). This isn't a style preference — it's what makes each layer
replaceable and testable in isolation. A Cubit can be unit-tested against a
fake `Repository` with no network and no widget tree (see `flutter-verify`'s
`bloc_test` usage); a Repository can swap its data source without the Cubit or
Screen changing; and there is exactly one place — the Repository — where a
thrown exception becomes the typed `Result<T>` the rest of the app switches on
exhaustively, instead of every layer needing its own error story.

This layering is the same shape Google's own `app-architecture` guidance
prescribes (MVVM + repository layer + a command-like operation triggered from
the view). **That guidance does not endorse bloc or Riverpod by name**, and its
reference app uses bare `provider` for dependency injection only, not as a
state-management pattern. This plugin uses `flutter_bloc` because it satisfies
the same layering equally well (Cubit as the ViewModel-equivalent sitting on
top of the Repository) while additionally giving a falsifiable,
per-state-transition test assertion via `bloc_test` — not because of any claim
that Google recommends it.

## State management: `flutter_bloc` is settled; Cubit vs. full `Bloc` is the only open choice

**Unchanged. Nothing in the dio / get_it / go_router / design-system adoption
touches this section.**

`flutter_bloc` (built on `package:bloc`) is this stack's state-management
library, full stop — a settled decision, not something to re-evaluate per
feature. Riverpod, GetX, `provider` used as a state-management pattern,
signals-based packages, and MobX are surveyed and not used here; see
flutter-bootstrap's SKILL.md ("what this skill deliberately does not do") for
the full cut list, and don't reopen that decision while planning a feature.

The only choice left per feature is **Cubit vs. full `Bloc`**, and the rule is
plain:

- **Default to `Cubit`.** Nearly every feature is a direct method call
  (`load()`, `submit()`, `refresh()`) that triggers one asynchronous operation
  and emits a new state when it resolves — exactly what `product_cubit.dart`
  does. No event class, no `on<Event>` handler, no event transformer. If a
  feature doesn't need anything in the next bullet, it needs a `Cubit` and
  nothing more.
- **Reach for a full `Bloc`** only when the feature genuinely needs an *event
  stream* with a transformer applied to it — debouncing a search-as-you-type
  field, throttling scroll-triggered pagination, or restarting/dropping
  in-flight work when a newer event arrives before the previous one finished.
  `package:bloc_concurrency` (`restartable()`, `droppable()`, `sequential()`,
  `concurrent()`) is the standard way to express that on top of `Bloc`'s
  `on<Event>(transformer: ...)` parameter — fetched from pub.dev's package
  API: latest `0.3.0`, published 2025-01-12, so (like `bloc_test`, see
  `flutter-verify`) it is genuinely stale relative to core `bloc`'s more
  recent releases; treat a `bloc_concurrency` upgrade as its own verified
  change, not a drive-by pin bump. If nothing in the feature needs
  debounce/throttle/concurrency control over a stream of triggering events,
  that absence *is* the signal it's a `Cubit` — don't reach for the
  event-driven shape "for consistency" when nothing demands it.

Either way, state is an immutable, exhaustively-matchable sealed type — that
property holds regardless of which base class emits it, which is why a UI can
`switch` over either with no `default:` arm and an unhandled state becomes a
compile error instead of a blank screen.

## Templates (all in `templates/`, using a worked `product` feature as the running example)

`Product` (a placeholder catalog item — `id`, `name`, `price`, `createdAt`) is
a deliberately generic, obviously-illustrative entity, not a real feature from
any project. Swap it for whatever the real feature is.

**A slice is nine files: eight copied per feature, one copied per project.**

| File | Layer | Target path |
|---|---|---|
| `result.dart` | shared, **once per project** | `lib/core/result.dart` — **not** under `features/`. Every feature's Repository returns this. Copy once at scaffold time, never again. |
| `product_dto.dart` | data (wire) | `lib/features/<f>/data/dto/<f>_dto.dart` |
| `product_model.dart` | domain | `lib/features/<f>/domain/<f>_model.dart` |
| `product_service.dart` | data (HTTP) | `lib/features/<f>/data/services/<f>_service.dart` |
| `product_repository.dart` | data (seam) | `lib/features/<f>/data/repositories/<f>_repository.dart` |
| `product_state.dart` | presentation | `lib/features/<f>/presentation/bloc/<f>_state.dart` — **both paths use this file unchanged** |
| `product_cubit.dart` | presentation | `lib/features/<f>/presentation/bloc/<f>_cubit.dart` — **default path** |
| `product_event.dart` | presentation | `lib/features/<f>/presentation/bloc/<f>_event.dart` — **full-`Bloc` path only** |
| `product_bloc.dart` | presentation | `lib/features/<f>/presentation/bloc/<f>_bloc.dart` — **full-`Bloc` path only** |
| `product_screen.dart` | presentation | `lib/features/<f>/presentation/screens/<f>_screen.dart` |
| `product_routes.dart` | presentation | `lib/features/<f>/presentation/<f>_routes.dart` — **new in this revision** |

**Copy the Cubit path or the `Bloc` path, never both.** A feature has exactly
one emitter. The default is `product_cubit.dart` alone. Only if the
Cubit-vs-`Bloc` rule above puts this feature in the minority do you copy
`product_event.dart` + `product_bloc.dart` *instead* — and then also add
`bloc_concurrency: 0.3.0` to `pubspec.yaml`, which the default scaffold
deliberately omits.

`product_state.dart` and `product_screen.dart` are **identical either way** —
the state is a sealed type and the screen switches over it exhaustively
regardless of what emitted it. That is what confines the Cubit-vs-`Bloc`
decision to one or two files and makes switching later cheap.

Both `product_event.dart` and `product_bloc.dart` were written against
bloc_concurrency's README and bloc's `bloc.dart` source, both fetched
2026-07-31 and cited inline in those files (including the fact that bloc's
**default transformer is `concurrent()`**, which is usually the wrong one).
`ASSUMPTION:` neither template has been compiled — no project in this
marketplace has yet taken the full-`Bloc` path, so, like every other template
here, they carry the skill's standing "not executed" status. The specific
unverified point is called out at the point it matters in `product_bloc.dart`
(the exact cancellation semantics of `restartable()` for a handler with side
effects before its first `emit`).

The folder is `presentation/bloc/`, which now holds a `Cubit` *or* a `Bloc`
depending on the path taken — `bloc/` is the name `flutter-verify`'s
coverage ratchet scopes to (alongside `services/`), matching a convention
common across the `flutter_bloc` ecosystem where a `bloc/` folder holds Cubits
too. Naming it `cubit/` would be equally defensible in isolation but would
silently break the coverage-ratchet path match — so this skill and
`flutter-verify` agree on `bloc/` rather than each guessing independently.

**All template imports are `package:` imports using the placeholder package
name `my_app`.** Replace it with your project's `name:` from `pubspec.yaml`.
A previous revision used relative imports (`'../../../../core/result.dart'`),
which **violated `always_use_package_imports` — a rule in the very same
very_good_analysis@10.3.0 ruleset this plugin vendors.** The templates were
failing the gate they ship. Fixed; do not reintroduce relative imports, not
even for a file in the same directory.

## Where shared types live — the ownership split, so nothing is defined twice

A sealed type defined in two places is a sealed type that will drift, and two
`Success<T>`s from two definitions are not the same type. So:

| Type | File | **Shipped by** |
|---|---|---|
| `Result<T>`, `Success<T>`, `Failure<T>` | `lib/core/result.dart` | **flutter-slice** (`templates/result.dart`) |
| `AppError` + its 8 sealed variants | `lib/core/error/app_error.dart` | **flutter-bootstrap** |
| `mapDioException` | `lib/core/network/dio_error_mapper.dart` | flutter-bootstrap |
| `AppRoutes` | `lib/core/router/routes.dart` | flutter-bootstrap |
| `AppTokens`, `AppTheme` | `lib/core/theme/` | flutter-bootstrap |
| `AppButton`, `AppScaffold`, `AppLoader`, `AppErrorView`, `AppEmptyState`, `AppGap`, `AppTextField` | `lib/shared/widgets/` | flutter-bootstrap |
| `context.l10n` | `lib/l10n/l10n.dart` | flutter-bootstrap |

**Neither skill ships the other's file.** `AppError` used to be a flat class at
the bottom of this skill's `result.dart`; it moved out and became sealed. If a
project ends up with two definitions of either type, delete one *before* they
diverge — the compiler will not warn you, because two identically-named types
in two libraries are simply two different types.

**Migration cost, stated rather than buried:** sealing `AppError` is a breaking
change. `const AppError('...')` no longer compiles anywhere. This skill's own
`product_repository.dart` had three such call sites; each now names a concrete
variant. Any project scaffolded from the older templates has the same edit to
make, and any test asserting on `AppError` directly will need updating.

## `Result<T>`: sealed, not exceptions-as-control-flow

`lib/core/result.dart` is a plain Dart 3 `sealed class Result<T>` with two
subtypes, `Success<T>` and `Failure<T>` (carrying an `AppError`). This is
**not** a freezed class — freezed is reserved for Cubit state; `Result<T>` is
deliberately the simplest possible sealed type because it only ever needs two
variants and no generated `copyWith`/`toJson`. A Repository method's return
type is always `Future<Result<T>>`, never `Future<T>` with a thrown exception
— the Cubit `switch`es on the result instead of wrapping every call in
`try`/`catch`.

The Repository implementation is the *only* place a `try`/`catch` for this
feature's Service exceptions is allowed to live, and every `catch` there has an
explicit `on` type (`avoid_catches_without_on_clauses`, vendored in
flutter-bootstrap's `analysis_options.yaml`, fails a bare `catch (e)`).

Exactly two `on` clauses, and **the third one was deleted**:

```dart
} on DioException catch (e) {
  return Failure(mapDioException(e));
} on FormatException catch (e) {
  return Failure(SerializationError(message: 'Malformed: ${e.message}'));
}
```

`on Exception catch (e) { return Failure(AppError('Unexpected: $e')); }` used
to be the third arm. With a sealed `AppError` that catch-all is actively
harmful: every unclassified failure lands in one generic message, the UI can
never do better than "something went wrong", and nobody ever discovers which
case `mapDioException` is missing. Let an unexpected `Exception` propagate.

**Residual gap, flagged where it happens rather than footnoted:** a bad cast
inside a generated `fromJson` throws `TypeError`, which is an `Error`, not an
`Exception`, so neither clause catches it and it escapes the Repository
uncaught. The fix is defensive DTO parsing (see `product_dto.dart`'s header for
the three concrete techniques), **not** `on TypeError` —
`avoid_catching_errors` forbids that, and catching `Error` hides real bugs.

**The Repository layer is mandatory for new features only.** Do not retrofit a
`Repository`/`Result<T>` wrapper onto an existing feature that already calls a
Service directly, just because a new feature nearby now has one — that is a
separate, deliberately-scoped migration a plan should call out on its own, not
a drive-by refactor this skill forces.

## Service: an injected `Dio`, and four deletions

`package:http` is gone. `dio@5.11.0` (fetched from pub.dev's package API
2026-07-30, published 2026-07-25) is the client, and the Service receives it:

```dart
const ProductService(this._dio);
```

**Never `Dio? dio` with a `?? Dio()` fallback.** The old
`http.Client? client` + `?? http.Client()` shape is the anti-pattern this
change exists to kill: a test that forgets to pass a client doesn't fail, it
**silently opens real sockets**. A required positional has no such escape.

Four things left with the switch, and each removal is load-bearing:

1. **`baseUrl`** — lives once, in the `BaseOptions` that
   `lib/core/network/dio_client.dart` builds from `FlavorConfig.apiBaseUrl`.
   Service paths are relative (`'/products/$id'`), which is what makes them
   flavor-agnostic instead of every Service re-reading flavor config.
2. **The manual `if (statusCode < 200 || >= 300) throw` check** — dio's
   `validateStatus` already throws `DioException` with `type ==
   DioExceptionType.badResponse`. That was ~10 lines *per endpoint*.
3. **`class ProductServiceException`** — deleted entirely. It carried
   `message` + `statusCode`, which `DioException` already carries with more
   detail. One exception type per feature meant N Repositories each catching a
   different name for the same event.
4. **Any `Options(headers: {'Authorization': ...})`** — the token is stamped
   by `AuthInterceptor` on the shared `Dio`. A Service that sets its own auth
   header bypasses refresh-and-replay and will 401 forever once the token
   expires.

Error *mapping* is not the Service's job and not an interceptor's job either:
`ErrorInterceptorHandler.reject()` accepts a `DioException` and nothing else,
so **an interceptor is physically incapable of emitting a domain `AppError`**.
The Repository maps, because it is already the `Result<T>` seam.

## DTO / domain split

`product_dto.dart` is a `json_serializable@6.14.0` class
(`json_annotation@4.12.0`) annotated with a bare `@JsonSerializable()` —
`field_rename: snake` is set once, project-wide, in flutter-bootstrap's
`build.yaml`, so `createdAt` maps to a backend `created_at` key with no
per-field `@JsonKey`. `product_model.dart` is a plain domain class with
**zero imports at all** — `ProductDto.toDomain()` is the one place mapping
happens. This split exists so whatever JSON casing convention the real backend
uses never leaks past the data layer; delete the `field_rename: snake` line in
`build.yaml` if the target backend already returns lowerCamelCase.

Unchanged by the dio switch: the Service now hands the DTO a
`Map<String, dynamic>` decoded by dio instead of by `jsonDecode`, which from
the DTO's point of view is the same input.

Run `dart run build_runner build --delete-conflicting-outputs` after adding or
changing a DTO — `product_dto.g.dart` is generated, not hand-written (and is
already excluded from analysis and coverage by flutter-bootstrap's
`analysis_options.yaml`/`build.yaml`).

## Cubit + freezed sealed state — verified syntax, not memory

`product_state.dart` uses `sealed class ProductState with _$ProductState` —
**not** the older `@freezed class ProductState with _$ProductState` shape.
Checked directly against freezed's own migration guide (`rrousselGit/freezed`,
`packages/freezed/migration_guide.md`, "Migrate from v2 to v3"): freezed 3.x
made the `sealed`/`abstract` keyword mandatory on the class itself and stopped
generating `.when`/`.map` entirely — pattern matching goes through Dart's own
`switch`. Pinned: `freezed@3.2.5`, `freezed_annotation@3.1.0` (both fetched
from pub.dev's package API).

**`freezed@3.2.5` is why `build_runner` is pinned at `2.15.1` and not the
`2.15.3` an earlier revision of this plugin named.** freezed 3.2.5 declares
`analyzer >=9.0.0 <11.0.0`; build_runner 2.15.3 needs `analyzer >=13.3.0`.
That was a **real observed `flutter pub get` resolver failure on 2026-07-30**,
not a prediction. Any codegen package you propose for a feature must be
checked against **both** bounds of that window, and against a transitive
`lean_builder` dependency — see flutter-bootstrap's cut list.

**The `error` variant now carries `AppError`, not `String`.** That is what lets
`AppErrorView` switch on the variant and offer "Try again" for a `ServerError`
but "Sign in" for an `UnauthorizedError`, instead of string-matching a message
somebody will eventually reword. Flattening to a String is still a legitimate
per-feature choice when a feature has exactly one failure rendering — but make
it deliberately; the default is to keep the type.

`ProductCubit.load()` is the only place a `Result<T>` is `switch`ed on; it
never leaks a `Result` into `ProductState` — the Cubit maps
`Success`/`Failure` into `ProductState.loaded`/`.error` before emitting, so the
Screen only ever depends on `ProductState`.

### DI lifetime: feature Cubits are `registerFactory`. This is provable, not stylistic.

From bloc's own source (fetched
`raw.githubusercontent.com/felangel/bloc/master/packages/bloc/lib/src/bloc_base.dart`
2026-07-30):

```dart
// bloc_base.dart:97-101
void emit(State state) {
  try {
    if (_stateController.isClosed) {
      throw StateError('Cannot emit new states after calling close');
// bloc_base.dart:173-177
Future<void> close() async {
  _blocObserver.onClose(this);
  await _stateController.close();
}
```

`BlocProvider(create: ...)` **owns** the bloc it creates and closes it when its
subtree is disposed. A feature Cubit registered as a lazy singleton would
therefore be `close()`d the first time the user popped that screen, and every
later navigation would receive the **same closed instance** — first `emit`
throwing `StateError`. `registerFactory` hands out a fresh, open Cubit per
mount, which is exactly the ownership contract `create:` assumes.

**The one exception, and the highest-likelihood mistake in this whole stack:**
`AuthCubit` is app-scoped, because the router's redirect guard closes over it
for the app's lifetime. It is registered
`registerLazySingleton<AuthCubit>(..., dispose: (c) => c.close())` **and**
provided with **`BlocProvider.value(value: getIt<AuthCubit>())` — never
`create:`**. `.value` does not take ownership and does not close on dispose.
Getting that pair backwards reintroduces exactly the `StateError` above. Every
*feature* Cubit stays factory + `create:`. The inconsistency is the hazard,
which is why it is stated here and again in `product_cubit.dart`'s header.

`ASSUMPTION:` that `BlocProvider(create:)` closes the bloc it creates while
`BlocProvider.value` does not. The *consequence* was verified directly in
bloc's source (quoted above); `flutter_bloc 9.1.1`'s own `bloc_provider.dart`
was **not** fetched. It is long-standing documented behaviour, but it is the
linchpin of the app-scoped-AuthCubit design — confirm it before relying on it.

## Screen: exhaustive switch, no default case — and now, the design system

`product_screen.dart`'s `BlocBuilder` `builder` callback is a Dart `switch`
expression over `ProductState` with one case per freezed subtype and **no**
`default:` arm. Because `ProductState` is `sealed`, omitting a case (or adding
a fifth variant later without updating the switch) is a compile-time error —
the vendored `no_default_cases` rule is the second line of defence in case a
`default:` gets reintroduced during a later refactor.

**That part is unchanged. Everything around it changed.** The previous revision
of this skill said this template "makes no visual-design decisions" and handed
typography, spacing, colour and motion to `sdlc-core:ui-ux-mobile`. **That
stance is retired.** This template now makes exactly one design decision — *use
the design system* — and then has none left to make, because tokens and shared
widgets have already made the rest.

| Instead of | Use |
|---|---|
| `Scaffold` + `AppBar(title: Text('Product'))` | `AppScaffold(title: context.l10n.productTitle, body: ...)` |
| `Center(child: CircularProgressIndicator())` | `AppLoader()` |
| A hand-rolled error `Text('Error: $message')` | `AppErrorView(error: error, onRetry: ...)` |
| `SizedBox.shrink()` for an idle/empty state | `AppEmptyState(icon:, headline:, supporting:, action:)` |
| `SizedBox(height: 16)` | `const AppGap(AppGapSize.lg)` |
| `ElevatedButton` / `FilledButton` / `TextButton` | `AppButton(label:, onPressed:, variant:)` |
| `TextField` / `TextFormField` | `AppTextField(controller:, label:, autofillHints:)` |
| `Text('Save')` | `Text(context.l10n.actionSave)` |
| `Duration(milliseconds: 300)` | `Theme.of(context).tokens.motion.medium` |
| `Colors.green` for a success state | `Theme.of(context).tokens.success` |
| `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` | `AppSnack.success(context, message)` |

`ASSUMPTION:` when this file was written, `lib/shared/widgets/` in
flutter-bootstrap's templates contained `app_button`, `app_text_field`,
`app_gap`, `app_loader`, `app_error_view` and `app_empty_state`. **`AppScaffold`,
`AppSnack` and `AppErrorBanner` are named by the architecture spec and by
flutter-bootstrap's own `app_router.dart` import list, but their template files
were not present at that moment.** Check `lib/shared/widgets/` before assuming
a wrapper exists; if one is genuinely missing, add it there — do not work
around it with a raw framework widget in feature code, because that is the
first crack the whole rule below exists to prevent.

Two rules that are easy to get wrong and cost real UX:

- **Empty is not a failure.** `AppEmptyState`, never `AppErrorView`, for "there
  is nothing here". Rendering a failure for an empty condition teaches users
  the app is broken when it is merely idle. For a list-shaped feature, add a
  `const factory <F>State.empty()` variant so emptiness is its own branch
  rather than a conditional inside the loaded branch.
- **A screen that renders nothing on its first frame reads as broken.** The old
  `_InitialView` returned `SizedBox.shrink()`. It now renders an empty state
  with an action.

The `sdlc-core:ui-ux-mobile` / `sdlc-core:ui-ux-review` handoff still exists,
but it now happens **through** the design system rather than around it: those
skills change tokens and shared widgets, and every screen inherits the change.
A screen that hardcodes its own padding is a screen those skills cannot fix
centrally, which is the entire reason the next section is a rule and not a
suggestion.

## The UI/UX rule

**Feature code may not hardcode a colour, a dimension, a duration, a shape, or
a user-facing string.** In full:

1. **No colour literal.** No `Color(0x...)`, no `Colors.blue`, no
   `Colors.white`. Colours come from `Theme.of(context).colorScheme` (the M3
   roles) or `Theme.of(context).tokens` (`success`/`onSuccess`/`warning`/
   `onWarning`, which M3's `ColorScheme` does not model). `Colors.white` is
   the single most common cause of a screen that is unreadable in dark mode.
2. **No dimension literal.** No `EdgeInsets.all(16)`, no
   `SizedBox(height: 24)`, no `BorderRadius.circular(8)`. Gaps are
   `AppGap(AppGapSize.*)`; padding and radii are
   `Theme.of(context).tokens.space.*` / `.radius.*`. The gutter is
   `AppScaffold`'s, not yours.
3. **No duration or curve literal.** No `Duration(milliseconds: 300)`, no
   `Curves.easeInOut`. Use `tokens.motion.instant/fast/medium/slow` and
   `tokens.motion.standard/enter/exit`. The enter/exit asymmetry (decelerate
   in, accelerate out) is real M3 guidance and the thing hand-rolled Flutter
   motion most often gets wrong.
4. **No raw framework component.** No `Scaffold`, `AppBar`, `ElevatedButton`,
   `FilledButton`, `OutlinedButton`, `TextButton`, `TextField`,
   `TextFormField`, `CircularProgressIndicator`, or bare `SnackBar` under
   `lib/features/**`. Use the `shared/widgets` wrapper. They exist so a11y
   fixes land once: `AppScaffold`'s keyboard-dismiss `GestureDetector` carries
   `excludeFromSemantics: true`, without which **every screen in the app** fails
   `labeledTapTargetGuideline`; `AppButton` wraps its label in `Flexible` +
   `maxLines: 2`, without which a 2.0 text scale overflows the row.
5. **No user-facing string literal.** Every string a user can read comes from
   `context.l10n`. That includes button labels, headlines, validation
   messages, semantic labels and tooltips. It also includes **numbers and
   dates**: format them with an ICU placeholder in the ARB, never with `'$'`
   or `DateFormat` in Dart. Currency symbol, symbol position, decimal
   separator and digit grouping are all locale-dependent, and interpolating
   `'\$${product.price}'` gets four things wrong at once.

**Enforcement is the whole ballgame.** Tokens and a component library that
features are merely *encouraged* to use will be bypassed within two slices.
The architecture spec proposes three additive deny-rules in
`tools/check_boundaries.dart` (storage packages, raw design literals, raw
framework widgets, each scoped to `lib/features/**` with `lib/core/theme/**`
and `lib/shared/widgets/**` exempt). **`ASSUMPTION:` whether those rules have
actually shipped in `check_boundaries.dart` was not verified when this file was
written** — check the script, and if they are not there, the rule above is a
convention that a reviewer has to enforce by eye.

**The one legitimate escape hatch:** if a token you need does not exist, **add
it to `AppTokens`**. That is the correct move, it takes one line, and every
future feature gets it. Inlining the value "just this once" is how a design
system dies.

## The slice procedure, end to end

Copy the eight per-feature templates, rename every `Product*` identifier and
both path segments (`product` -> `<feature>`, `Product` -> `<Feature>`), then
do all of the following. **Steps 6 through 9 are the ones a slice most often
forgets, and every one of them is in a file the feature does not own.**

### 1. Data layer

Define the DTO against the endpoint's real payload; parse defensively (see
`product_dto.dart`'s header). Write the domain model with **zero imports**.
Write the Service with one method per endpoint over the injected `Dio`, and
no `try`/`catch`. Write the Repository with `Future<Result<T>>` returns and the
two `on` clauses.

### 2. Generate

```
dart run build_runner build --delete-conflicting-outputs
```

Needed for both the DTO's `.g.dart` and the state's `.freezed.dart`.

### 3. Presentation layer

Freezed sealed state (`error` carries `AppError`; add `empty()` if the feature
is list-shaped). Cubit that emits loading first and switches on `Result<T>`.
Screen built from `AppScaffold` + `shared/widgets` + tokens + `context.l10n`,
with an exhaustive switch and no `default:`.

### 4. Routes file

`lib/features/<f>/presentation/<f>_routes.dart`, exporting
`List<RouteBase> get <f>Routes` plus the feature's own path constants and a
`…For(id)` helper. Parse every path parameter **in the route builder**, and
fail closed to a real screen.

### 5. Register the feature in DI — `lib/core/di/injector.dart`

Three registrations, added **inside the existing cascade** (repeated
`getIt.registerX(...)` statements trip `cascade_invocations`):

```dart
getIt
  ..registerLazySingleton<ProductService>(
    () => ProductService(getIt<Dio>()),
  )
  ..registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(getIt<ProductService>()),
  )
  ..registerFactory<ProductCubit>(
    () => ProductCubit(getIt<ProductRepository>()),
  );
```

- `getIt<Dio>()` **unnamed** — the named `'replayClient'` instance is
  interceptor-free and exists only for the auth refresh. A Service resolving
  the replay client would silently send unauthenticated requests.
- The Repository is registered **against the abstract type**, never against
  `ProductRepositoryImpl`. That is what makes a test override one line:
  `getIt.registerLazySingleton<ProductRepository>(MockProductRepository.new)`.
- The Cubit is a **factory**. See the lifecycle proof above.
- **There is no `AppDependencies` any more.** The old instruction to add a
  field to a hand-written dependency bag is deleted; that class no longer
  exists, and `FlavorConfig.current` — the mutable global static it travelled
  with — is gone with it.

The container variable is named `getIt` (`final GetIt getIt = GetIt.instance;`
in `injector.dart`). If your project aliases it to `sl`, the registrations are
identical; only the identifier changes.

### 6. Add the routes to the aggregator — `lib/core/router/app_router.dart`

One import and one spread:

```dart
import 'package:my_app/features/product/presentation/product_routes.dart';
// ...
routes: <RouteBase>[...authRoutes, ...productRoutes],
```

This is legal by construction, not by exemption: `tools/check_boundaries.dart`
only walks `Directory('lib/features')`, so a file in `lib/core/` importing
every feature is never scanned. **A feature must never import another
feature's screen to navigate to it** — put the destination path in
`AppRoutes` (`lib/core/router/routes.dart`) and call
`context.go(AppRoutes.profile)`, which is a String owned by core, not a symbol
owned by feature B.

### 7. Add strings to the ARB and regenerate — `lib/l10n/arb/app_en.arb`

Every user-visible string, each with a `@key` description (`l10n.yaml` sets
`required-resource-attributes: true`, so a message without one **fails
generation**). Keys are prefixed by feature; the prefix *is* the namespace,
because ARB has none.

```json
"productTitle": "Product",
"@productTitle": {
  "description": "Title of the product detail screen's app bar."
},

"productPrice": "{price}",
"@productPrice": {
  "description": "The product's price, formatted for the current locale.",
  "placeholders": {
    "price": {
      "type": "double",
      "format": "currency",
      "optionalParameters": { "decimalDigits": 2 }
    }
  }
}
```

`ASSUMPTION:` the `"format": "currency"` / `"format": "yMMMd"` spellings and
the `optionalParameters` key were **not** re-verified against Flutter 3.41.6's
`gen-l10n` this session. Run the generator and read the error if there is one.

Then:

```
flutter gen-l10n
```

**Nothing runs this for you — `flutter test` in particular does not.** An ARB
edit with no regeneration is a getter that does not exist yet, and the failure
surfaces as a compile error in your screen, not as a localization problem.
The generated files under `lib/l10n/gen/` are **committed**; they carry
`ignore_for_file: type=lint` and `// coverage:ignore-file`, so they pollute
neither the analyze gate nor the coverage ratchet.

Two ARB rules worth stating because they fail silently:
- **Double every apostrophe** (`"couldn''t"`). `l10n.yaml` sets
  `use-escaping: true`, which makes `'` the ICU escape character; a single
  apostrophe does not error, it silently swallows the following characters.
- **Never concatenate translated fragments in Dart.** A sentence with a
  variable in it is ONE message with a placeholder. Word order differs between
  languages and concatenation hardcodes English's.

### 8. Add tokens if the design needs something new

If the screen needs a spacing step, a duration, or a semantic colour that
`AppTokens` does not have, **add it to `lib/core/theme/app_tokens.dart`** —
including its `lerp` behaviour (scales snap at the midpoint; colours
interpolate). Do not inline the value.

### 9. Delete what the feature replaces

The scaffold ships a throwaway landing screen on `AppRoutes.home` and a
`homePlaceholderHeadline` ARB message. The first real feature that owns `home`
deletes both. A placeholder left behind after the thing it stood in for
arrived is worse than no placeholder.

### 10. Test, then gate

See the checklist below for what to test. Then run the gate — `flutter-verify`
runs the blocking checks (`flutter analyze --fatal-infos`,
`dart run tools/check_boundaries.dart`, `flutter test`, secret scanning) plus a
dependency audit when `pubspec.yaml` changed.

---

## New-feature checklist

**The single artifact to work through when "everything should be perfectly
aligned".** A slice is not done until every line is either ticked or
explicitly, out-loud, declared not applicable. Items 12–17 are the ones that
touch files outside the feature directory; skipping any of them produces a
feature that compiles, passes its own tests, and is unreachable, untranslated,
or unwired.

**Decide**

1. [ ] **Cubit or full `Bloc`?** Default `Cubit`. Full `Bloc` only if the
       feature needs an event *transformer* (debounce, throttle, restartable,
       droppable). If you can't name the transformer, it's a Cubit.
       - Cubit → copy `product_cubit.dart`. No event file exists or is needed.
       - Full `Bloc` → copy `product_event.dart` + `product_bloc.dart`
         **instead of** the Cubit, and add `bloc_concurrency: 0.3.0` to
         `pubspec.yaml` (the default scaffold omits it on purpose).
       - Either way `<f>_state.dart` and `<f>_screen.dart` are the same files.
       - If you take the `Bloc` path, pass an explicit `transformer:` on
         **every** `on<>`: bloc's default is `concurrent()`, which lets two
         responses land out of order so the older one wins. Verified in
         bloc's own source — see `product_bloc.dart`'s header.
2. [ ] **Does this feature need a Repository?** Yes for every new feature. Do
       **not** retrofit one onto adjacent existing code as a side effect.

**Build the feature (`lib/features/<f>/`)**

3. [ ] `data/dto/<f>_dto.dart` — `@JsonSerializable()`, fields matching the
       real payload, **defensive** about types the backend is loose about.
4. [ ] `domain/<f>_model.dart` — plain Dart, **zero imports**, `const`
       constructible, no formatting getters.
5. [ ] `data/services/<f>_service.dart` — injected `Dio` (required, no
       fallback), relative paths, no `baseUrl`, no `try`/`catch`, no
       `Authorization` header.
6. [ ] `data/repositories/<f>_repository.dart` — `abstract interface class` +
       `final class …Impl`, returns `Future<Result<T>>`, exactly two `on`
       clauses (`DioException` → `mapDioException`, `FormatException` →
       `SerializationError`), **no `on Exception` catch-all**.
7. [ ] `presentation/bloc/<f>_state.dart` — `@freezed sealed class`, `error`
       variant carries `AppError`, `empty()` variant if list-shaped, doc
       comment on every factory.
8. [ ] `presentation/bloc/<f>_cubit.dart` — emits `loading()` **first**,
       switches on `Result<T>`, no `try`/`catch`, no form text in state.
9. [ ] `presentation/screens/<f>_screen.dart` — `AppScaffold`, exhaustive
       `switch` with **no `default:`**, `AppLoader` / `AppErrorView` /
       `AppEmptyState` for the non-happy states, `AppGap` for spacing,
       `context.l10n` for every string, `unawaited(...)` on fire-and-forget
       Cubit calls.
10. [ ] `presentation/<f>_routes.dart` — `List<RouteBase> get <f>Routes`,
        feature-private path constants, a `…For(id)` location builder, every
        path parameter parsed in the builder and **failing closed** to a real
        screen.
11. [ ] `dart run build_runner build --delete-conflicting-outputs` — for the
        `.g.dart` and `.freezed.dart` files.

**Wire it into the app (files the feature does *not* own)**

12. [ ] `lib/core/di/injector.dart` — three registrations inside the existing
        cascade: Service `registerLazySingleton`, Repository
        `registerLazySingleton` **against the abstract type**, Cubit
        **`registerFactory`**.
13. [ ] `lib/core/router/app_router.dart` — one import, one `...<f>Routes`
        spread.
14. [ ] `lib/core/router/routes.dart` — add a path to `AppRoutes` **only if**
        another feature, the auth guard, a deep link, or a push payload needs
        to name it. Feature-private paths stay in the feature.
15. [ ] `lib/l10n/arb/app_en.arb` — every user-visible string, each with a
        `@key` description; apostrophes doubled; numbers and dates as ICU
        placeholders, not Dart interpolation.
16. [ ] `flutter gen-l10n` — **run it.** Nothing else will.
17. [ ] `lib/core/theme/app_tokens.dart` — add any token the design needed and
        did not have (including its `lerp` behaviour). Never inline the value
        in the feature instead.

**Prove it**

18. [ ] Repository unit test — mock the Service, throw a real `DioException`
        per `DioExceptionType` you care about, assert the mapped `AppError`
        variant (not its message text).
19. [ ] Cubit test (`bloc_test`) — fake Repository, assert the exact emitted
        state sequence for both the success and the failure path.
20. [ ] Widget test per state variant — pump the screen inside a
        `MaterialApp` built with **the app's real theme** (a bare
        `MaterialApp()` has no `AppTokens` and `Theme.of(context).tokens`
        throws by design) and with `AppL10n.localizationsDelegates` /
        `supportedLocales` wired, then override the Cubit's dependencies via
        `getIt` (`reset()` in `setUp`/`tearDown`, or `pushNewScope`).
21. [ ] Text-scale test — pump the screen at `TextScaler.linear(1.0)`, `1.3`
        and `2.0` and assert `tester.takeException()` is null. This is the
        highest-yield "stays aligned" check there is; it caught a
        `RenderFlex overflowed by 136 pixels` in already-reviewed component
        code.
22. [ ] Accessibility test — `tester.ensureSemantics()` then
        `meetsGuideline(textContrastGuideline)`,
        `androidTapTargetGuideline`, `labeledTapTargetGuideline`, in **both**
        light and dark themes.
23. [ ] Route test — navigate to the feature's path, and to a malformed
        version of it, and assert the fail-closed screen appears rather than
        a crash.

**Ship it**

24. [ ] `flutter analyze --fatal-infos` — zero issues from your new files.
25. [ ] `dart run tools/check_boundaries.dart` — exit 0.
26. [ ] `flutter test` — green, and the coverage ratchet not regressed.
27. [ ] Delete every placeholder this feature replaced: the scaffold's
        throwaway home route and screen, its `homePlaceholderHeadline` ARB
        message, any `TODO` route stub.
28. [ ] Re-read the diff for the UI/UX rule: search your new files for
        `Color(`, `Colors.`, `EdgeInsets`, `SizedBox(`, `Duration(`,
        `BorderRadius`, `Scaffold(`, `TextField`, and any quoted string that
        a user can read. Every hit is either a token, a shared widget, or an
        ARB key that you have not yet created.

---

## What this skill still does not decide

- **The visual language itself** — the seed colour, the type scale, the
  component look. Those live in `lib/core/theme/` and `lib/shared/widgets/`,
  which flutter-bootstrap ships and `sdlc-core:ui-ux-mobile` /
  `sdlc-core:ui-ux-review` shape. What changed is that this skill now *requires
  features to consume them* rather than leaving styling to each screen.
- **Backend contract design** — endpoint shapes, pagination style, error
  envelope format. The DTO models whatever the backend actually sends.
- **Whether a feature needs a full `Bloc`** — the rule is stated above, the
  judgement is the plan's.
- **Retry/auth/timeout policy** — owned by `lib/core/network/` (interceptor
  order, the 401 single-flight refresh queue, the idempotent-methods-only retry
  restriction). A feature inherits all of it and configures none of it.

**What this skill no longer defers, and the two reversals worth naming:**

- *"Navigation/DI wiring for the Screen … is intentionally left to the slice's
  plan"* — **reversed.** Both are now steps 5 and 6 of the procedure and items
  12 and 13 of the checklist, with the exact code.
- *"`go_router` — adopting it is its own separate, recommended-not-required
  decision; nothing here assumes it's present"* — **reversed.** go_router
  17.3.0 (fetched from pub.dev's package API 2026-07-30, published 2026-06-02,
  first-party `flutter/packages`) is part of the stack, and a route file is
  part of a slice. `auto_route` and `go_router_builder` remain rejected —
  `auto_route_generator` on transitive arithmetic (`lean_builder ^1.2.0`
  requires `analyzer ^13.0.0` and `sdk >=3.12.0`, both unsatisfiable here),
  and `go_router_builder` **on policy alone, stated plainly: it would
  actually resolve against this project's analyzer ceiling.** Dressing a
  policy call up as a constraint failure is exactly what this plugin's
  evidence standard forbids.
