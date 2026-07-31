// lib/app/app.dart
//
// The root widget. Constructed by `bootstrap()` as `bootstrap(config, () =>
// const App())`, it does exactly five things: provide the app-scoped
// AuthCubit, name the app, install the theme, install localization, and hand
// navigation to the router. It holds no state and takes no constructor
// parameters, because everything it needs already exists in DI by the time it
// is built.
//
// THIS FILE EXISTS TO KILL TWO SPECIFIC DEFECTS.
//
// DEFECT 1: the previous version read `FlavorConfig.current.flavor.name`, a
// mutable global static. Reading it before some `main()` had assigned it threw
// LateInitializationError; every widget test had to assign it before pumping;
// and because it was ONE slot on ONE class, two differently-flavored tests in
// the same isolate overwrote each other. Here the config comes from
// `getIt<FlavorConfig>()` — an immutable instance registered once in
// `configureDependencies()`. A test overrides it with one
// `registerSingleton<FlavorConfig>(...)` line.
//
// DEFECT 2: the previous version was `MaterialApp(...)` with NO `theme:` at
// all, so everything rendered in Flutter's stock Material-3 baseline. That is
// the direct, mechanical cause of a scaffolded app looking generic — not the
// individual screens. A screen built carefully on top of no theme still looks
// like a demo. `theme:` and `darkTheme:` below are that fix, and they are why
// every screen inherits a designed surface instead of a default one.
//
// WHY `darkTheme:` IS WIRED FROM DAY ONE
// `themeMode` already defaults to `ThemeMode.system`, so supplying
// `darkTheme` is the whole switch: from the first frame, a device in dark
// mode renders the dark scheme. Bolted on after half a dozen features have
// shipped, you discover those features hard-coded `Colors.white` and every
// one has to be revisited.
//
// AND WHY THERE IS NO `themeMode:` LINE. Passing `ThemeMode.system`
// explicitly trips `avoid_redundant_argument_values` — an `info`, which
// `flutter analyze --fatal-infos` turns into a GATE FAILURE. Its absence is a
// decision, not an omission. Pin `themeMode: ThemeMode.light` only if the
// product must be light-only; that value is not the default, so it does not
// trip the lint and it makes the restriction something somebody wrote down.
//
// WHY THE l10n LISTS ARE SPREAD FROM THE GENERATED CLASS
// `AppL10n.localizationsDelegates` and `AppL10n.supportedLocales` are both
// generated from lib/l10n/arb/. Wiring the generated getters — rather than
// hand-writing `supportedLocales: [Locale('en')]` — is what makes adding a
// language a zero-code change: drop `app_es.arb`, run `flutter gen-l10n`,
// done. That payoff only exists if they are wired this way from the start,
// which is why a single-language app still does it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:my_app/core/config/flavor_config.dart';
import 'package:my_app/core/di/injector.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:my_app/l10n/gen/app_localizations.dart';

/// The application root widget.
///
/// Built once by `bootstrap()`; takes no parameters on purpose — everything
/// it needs is resolved from DI inside [build], so a test can swap any of it
/// with a single `getIt` registration and still pump `const App()`.
class App extends StatelessWidget {
  /// Creates the application root.
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final config = getIt<FlavorConfig>();

    return BlocProvider<AuthCubit>.value(
      // `.value`, NEVER `BlocProvider(create: ...)`. The difference is
      // ownership: `create:` makes the provider OWN the Cubit and CLOSE it
      // when its subtree is disposed, while `.value` does not take ownership.
      // AuthCubit is a lazy singleton (with `dispose: (c) => c.close()`, so
      // DI still closes it) precisely because the router closes over it for
      // the app's whole lifetime. Hand it to `create:` and the first disposal
      // closes it; every later `emit` then throws `StateError('Cannot emit
      // new states after calling close')` — verified in bloc 9.2.1's own
      // bloc_base.dart:97 — and the router's guard is reading a corpse.
      //
      // Every OTHER feature Cubit is the mirror image: `registerFactory` in
      // DI and `BlocProvider(create: ...)` at the screen. The two rules look
      // contradictory and are not — they are the same ownership contract
      // applied to two different lifetimes.
      value: getIt<AuthCubit>(),
      child: MaterialApp.router(
        title: config.appName,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // The debug banner only ever renders in a debug build, so this hides
        // it in exactly one case: a prod-flavored DEBUG build — the kind you
        // hand to a stakeholder for a demo.
        debugShowCheckedModeBanner: !config.isProduction,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        routerConfig: getIt<GoRouter>(),
      ),
    );
  }
}
