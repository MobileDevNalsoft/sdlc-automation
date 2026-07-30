// lib/bootstrap.dart
//
// Central app bootstrap: wires dependencies (services -> repositories),
// installs a BlocObserver for state-transition logging/crash reporting, and
// initializes Sentry. Each flavor entrypoint (main_dev.dart / main_staging.dart
// / main_prod.dart) sets `FlavorConfig.current` then calls
// `bootstrap((deps) => PlaceholderApp(dependencies: deps))` — this file has no
// flavor-specific knowledge of its own.
//
// API usage below (SentryFlutter.init signature, BlocObserver overrides) was
// checked against live sources on 2026-07-29, not written from memory:
//   - getsentry/sentry-dart packages/flutter/README.md ("Usage" section) —
//     confirms `SentryFlutter.init((options) {...}, appRunner: () => runApp(...))`
//     and that, on Flutter >= 3.3 (this project pins 3.44.8), the SDK already
//     hooks `PlatformDispatcher.onError` itself — wrapping this in a second,
//     manual `runZonedGuarded` is unnecessary and a known source of
//     zone-mismatch bugs, so this file deliberately does NOT add one.
//   - getsentry/sentry-dart packages/dart/lib/src/sentry_options.dart —
//     confirms `environment` (String?), `tracesSampleRate` (double?), and
//     `dsn` are real SentryOptions fields (line-checked, not assumed).

import 'package:bloc/bloc.dart'; // bloc@9.2.1
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart'; // sentry_flutter@9.25.0

/// Which build flavor is currently running. Set once, in each
/// `main_<flavor>.dart` entrypoint, before [bootstrap] is called; read
/// anywhere via `FlavorConfig.current.flavor`.
enum Flavor { dev, staging, prod }

/// Per-flavor configuration threaded into [bootstrap]. Each `main_<flavor>.dart`
/// constructs one of these with its own values before calling [bootstrap].
class FlavorConfig {
  const FlavorConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.sentryDsn,
  });

  final Flavor flavor;
  final String apiBaseUrl;
  final String sentryDsn;

  /// Set by each flavor entrypoint's `main()` before [bootstrap] runs.
  static late FlavorConfig current;
}

/// Everything a screen/cubit needs, constructed once at startup and threaded
/// down via the widget tree. Deliberately a plain, constructor-injected class
/// — not a generated service locator (this marketplace's cut list rejects
/// `injectable` and similar codegen-DI packages). Add one field per repository
/// as each flutter-slice feature is sliced in, e.g.:
///
/// ```dart
/// class AppDependencies {
///   const AppDependencies({required this.productRepository});
///   final ProductRepository productRepository;
/// }
/// ```
class AppDependencies {
  const AppDependencies();
}

/// Logs every bloc/cubit state transition and forwards uncaught bloc/cubit
/// errors to Sentry. Installed once via `Bloc.observer = const
/// AppBlocObserver();` inside [bootstrap], before `appRunner` runs.
class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    // debugPrint, not a logging package — bootstrap stays dependency-free.
    // Swap for a real structured logger once the target project picks one;
    // that choice is out of scope for this scaffold.
    debugPrint('${bloc.runtimeType} $change');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    Sentry.captureException(error, stackTrace: stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}

/// Call once from each flavor's `main()`, after setting [FlavorConfig.current].
/// [builder] receives the constructed [AppDependencies] and returns the root
/// widget.
Future<void> bootstrap(
  Widget Function(AppDependencies dependencies) builder,
) async {
  WidgetsFlutterBinding.ensureInitialized();

  Bloc.observer = const AppBlocObserver();

  // Wire real services -> repositories here as features are sliced in, e.g.:
  //   final productService = ProductService(baseUrl: FlavorConfig.current.apiBaseUrl);
  //   final productRepository = ProductRepositoryImpl(productService);
  //   final dependencies = AppDependencies(productRepository: productRepository);
  const dependencies = AppDependencies();

  await SentryFlutter.init(
    (options) {
      options.dsn = FlavorConfig.current.sentryDsn;
      options.environment = FlavorConfig.current.flavor.name;
      // ASSUMPTION: 0.2 is a placeholder trace-sampling rate, not sized
      // against any real traffic/cost figures — no target project's traffic
      // volume was available this session. Revisit once real usage data
      // exists; sampling at 1.0 in production is usually cost-prohibitive at
      // scale, and this scaffold would rather under-sample by default than
      // surprise a team with a Sentry bill.
      options.tracesSampleRate = 0.2;
    },
    appRunner: () => runApp(builder(dependencies)),
  );
}

/// Minimal root widget so this template compiles standalone. Replace with the
/// project's real `App` (typically `lib/app/app.dart`, wired to `go_router`
/// or whatever navigation the project already uses) once the first
/// flutter-slice feature lands — this placeholder is intentionally throwaway.
class PlaceholderApp extends StatelessWidget {
  const PlaceholderApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App (${FlavorConfig.current.flavor.name})',
      home: Scaffold(
        body: Center(
          child: Text(
            'Bootstrap OK — flavor: ${FlavorConfig.current.flavor.name}\n'
            'Replace PlaceholderApp with the real app root widget.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
