// lib/core/di/injector.dart
//
// The composition root. One function, [configureDependencies], builds every
// long-lived object in the app in dependency order and registers it with
// get_it. `bootstrap()` awaits it before `runApp`, and nothing else in the
// app constructs a Service, a Repository, a `Dio`, a store, or the router.
//
// WHY get_it AT ALL — and what specifically it replaced
// The previous scaffold threaded a hand-written `AppDependencies` bag down
// the widget tree and read flavor config from `static late FlavorConfig
// current`. That static was the actual defect: reading it before assignment
// threw `LateInitializationError`, every widget test had to assign it before
// pumping, and because it is ONE mutable slot on ONE class, two
// differently-flavored tests in the same isolate overwrote each other.
//
// The fix is NOT "we adopted a DI package because DI is nice". It is that the
// config became a value passed as a parameter and registered as an IMMUTABLE
// INSTANCE — `registerSingleton<FlavorConfig>(config)` below — so there is no
// writable slot left to race on.
//
// BE HONEST ABOUT WHAT get_it IS: `GetIt.instance` is itself process-global
// mutable state. It is a service locator, and that is inherent. What it buys
// over the static is real but bounded: deterministic LIFO teardown,
// `isRegistered<T>()` for assertions, type-keyed override seams, scopes, and
// `GetIt.asNewInstance()` — a genuinely separate container with no shared
// state, which is exactly the class of test the old static broke.
//
// CODEGEN DI IS STILL REJECTED. `injectable`/`injectable_generator` are out,
// and not only on policy: `injectable_generator 3.1.1` declares
// `analyzer >=13.0.0` and `sdk >=3.12.0`, both unsatisfiable here (freezed
// 3.2.5 caps analyzer below 11.0.0, and the verified toolchain is Dart
// 3.11.4). Registration below is hand-written on purpose.
//
// ---------------------------------------------------------------------------
// WHY THIS FUNCTION IS ASYNC AND PHASED
// ---------------------------------------------------------------------------
// Storage handles are only constructible after awaits. Registering a store
// before its `await` completes creates a race where the first read beats the
// open — an intermittent bug that will not reproduce on a warm reload,
// because by then the box is already open. Hence: await the opens first,
// register second.
//
// ---------------------------------------------------------------------------
// REGISTRATION ORDER IS ALSO TEARDOWN ORDER
// ---------------------------------------------------------------------------
// get_it 9.0.0's single breaking change across the whole 9.x line, verbatim
// from its CHANGELOG: "**BREAKING**: Disposal order now always follows strict
// LIFO (Last-In-First-Out) based on registration order". That is a gift for
// test isolation — `reset()` tears down in reverse registration order rather
// than hash-map order, so a Cubit is always closed before the Repository it
// holds. Keep the order below meaningful.
//
// ---------------------------------------------------------------------------
// LIFETIMES — THE RULES, AND THE ONE EXCEPTION
// ---------------------------------------------------------------------------
// - Config and stores: `registerSingleton` (eager, instance already exists).
// - `Dio`, interceptors, Services, Repositories, the router:
//   `registerLazySingleton`.
// - Repositories are registered against the ABSTRACT type, which is what
//   makes a test override a one-liner.
// - FEATURE CUBITS ARE `registerFactory`. Provable from bloc's source:
//   `BlocProvider(create: ...)` owns and closes the bloc it creates when its
//   subtree is disposed, and `BlocBase.emit` throws `StateError('Cannot emit
//   new states after calling close')` once closed (bloc_base.dart:97-101). A
//   feature Cubit registered as a lazy singleton would be closed the first
//   time the user popped that screen, and every later navigation would
//   receive the SAME CLOSED INSTANCE.
// - THE ONE EXCEPTION IS `AuthCubit`, a lazy singleton with
//   `dispose: (c) => c.close()`, because the router closes over it for the
//   app's whole lifetime. It MUST be provided with
//   `BlocProvider.value(value: getIt<AuthCubit>())` and NEVER
//   `BlocProvider(create: ...)`. This app currently has exactly one Cubit, so
//   there is no factory registration below to compare against — which is
//   precisely why the rule is written down here rather than inferred from an
//   example.
//
// ASSUMPTION: the `create:`-owns / `.value`-does-not asymmetry is documented,
// long-standing flutter_bloc behaviour, and its CONSEQUENCE was verified
// directly in bloc's `bloc_base.dart`. But `flutter_bloc 9.1.1`'s own
// `bloc_provider.dart` was not read to confirm the ownership rule itself.
//
// ---------------------------------------------------------------------------
// WHAT TO CHANGE WHEN YOU SLICE IN A FEATURE
// ---------------------------------------------------------------------------
// Three lines, in this order: Service, then Repository (against the abstract
// type), then Cubit (as a FACTORY). Plus one `...<f>Routes` spread in
// lib/core/router/app_router.dart.

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:my_app/core/config/flavor_config.dart';
import 'package:my_app/core/network/auth_interceptor.dart';
import 'package:my_app/core/network/dio_client.dart';
import 'package:my_app/core/router/app_router.dart';
import 'package:my_app/core/storage/flutter_secure_store.dart';
import 'package:my_app/core/storage/hive_key_value_store.dart';
import 'package:my_app/core/storage/key_value_store.dart';
import 'package:my_app/core/storage/secure_store.dart';
import 'package:my_app/features/auth/data/repositories/auth_repository.dart';
import 'package:my_app/features/auth/data/services/auth_service.dart';
import 'package:my_app/features/auth/data/services/mock_auth_service.dart';
import 'package:my_app/features/auth/presentation/bloc/auth_cubit.dart';

/// The app's service locator.
///
/// A top-level `final` rather than `GetIt.instance` at every call site, so
/// that swapping the whole container (for example to `GetIt.asNewInstance()`
/// in a test harness) is a one-line change in one file.
final GetIt getIt = GetIt.instance;

/// Name of the hive_ce box holding non-secret app settings.
const String settingsBoxName = 'settings';

/// Builds and registers every long-lived dependency, in dependency order.
///
/// Call once, from `bootstrap()`, and await it before `runApp`. [config] is
/// constructed by the flavor entrypoint (`lib/main_dev.dart` and friends) and
/// is the only argument the whole graph needs from the outside.
Future<void> configureDependencies(FlavorConfig config) async {
  // Phase 0 — binding. Kept explicit even though `Hive.initFlutter()` calls
  // `WidgetsFlutterBinding.ensureInitialized()` itself: relying on a
  // transitive package's internals for binding initialisation is exactly the
  // invisible coupling that breaks on a minor upgrade.
  WidgetsFlutterBinding.ensureInitialized();

  // Phase 1 — Hive init. On native this resolves the app-documents directory
  // via path_provider. On web it SKIPS that entirely and uses IndexedDB.
  // Consequence worth knowing: forgetting this call throws
  // `HiveError('You need to initialize Hive ...')` on NATIVE ONLY — so a
  // web-first dev loop will not surface the mistake, and it appears on the
  // first device build.
  await Hive.initFlutter();

  // Phase 2 — open the box BEFORE registering anything that needs it.
  // Opening the same box twice throws `HiveError('The box "settings" is
  // already open ...')`, which is realistic in a test suite that runs a
  // bootstrap path per case. Such tests should register
  // `InMemoryKeyValueStore` instead of coming through here at all.
  final settingsBox = await Hive.openBox<Object?>(settingsBoxName);

  // A single cascade rather than repeated `getIt.registerX(...)` statements:
  // `cascade_invocations` requires it, and it also makes the registration
  // order — which is now also the teardown order — read as one list.
  getIt
    // Phase 3 — config. Registering the INSTANCE (not a factory) is what
    // makes it immutable by construction. THIS SINGLE LINE IS WHAT KILLS
    // `static late FlavorConfig current`.
    ..registerSingleton<FlavorConfig>(config)
    // Phase 4 — key/value store. The OPEN box is injected, so
    // `HiveKeyValueStore` never calls `Hive.box()`. That turns a runtime
    // `HiveError` into an unsatisfiable constructor and confines the Hive
    // global to the line above.
    ..registerSingleton<KeyValueStore>(HiveKeyValueStore(settingsBox))
    // Phase 5 — secure store. `const`-constructible only because
    // `FlutterSecureStorage`'s own constructor is const, which is what makes
    // `prefer_const_constructors` satisfiable at this call site.
    ..registerSingleton<SecureStore>(
      const FlutterSecureStore(FlutterSecureStorage()),
    )
    // Phase 6 — the INTERCEPTOR-FREE replay client, registered under a name.
    // Its emptiness is a hard requirement: a refresh issued on the main
    // client can deadlock `AuthInterceptor`'s serialized error queue with no
    // timeout, hanging the app. See auth_interceptor.dart NOTE 2.
    ..registerLazySingleton<Dio>(
      () => buildReplayDio(getIt<FlavorConfig>()),
      instanceName: kReplayClientName,
    )
    // Phase 7 — the auth interceptor. ONE instance, because its task queues
    // are per-instance and the serialized error queue IS the single-flight
    // refresh guarantee. A second instance would defeat it outright.
    ..registerLazySingleton<AuthInterceptor>(
      () => AuthInterceptor(
        secureStore: getIt<SecureStore>(),
        replayClient: getIt<Dio>(instanceName: kReplayClientName),
        refreshToken: _sessionCannotBeRefreshed,
      ),
    )
    // Phase 8 — the shared client every Service uses. One instance for
    // connection pooling and, more importantly, so the auth attach/refresh
    // chain is installed exactly once.
    ..registerLazySingleton<Dio>(
      () => buildDio(
        config: getIt<FlavorConfig>(),
        authInterceptor: getIt<AuthInterceptor>(),
      ),
    )
    // Phase 9 — auth Service.
    //
    // `MockAuthService`, NOT `AuthService`. This app has no auth backend;
    // `apiBaseUrl` points at a placeholder host. The mock extends the real
    // service and receives the same shared Dio, so the wiring exercised in
    // development is the wiring production will use. MIGRATING TO A REAL
    // BACKEND IS THIS ONE LINE plus deleting mock_auth_service.dart.
    ..registerLazySingleton<AuthService>(() => MockAuthService(getIt<Dio>()))
    // Phase 10 — auth Repository, registered against the ABSTRACT type so a
    // test swaps it in one line.
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        service: getIt<AuthService>(),
        secureStore: getIt<SecureStore>(),
      ),
    )
    // Phase 11 — AuthCubit — THE EXCEPTION: a lazy singleton, because the
    // router closes over it for the app's lifetime. Provide it with
    // `BlocProvider.value`, NEVER `BlocProvider(create:)`.
    ..registerLazySingleton<AuthCubit>(
      () => AuthCubit(getIt<AuthRepository>()),
      dispose: (cubit) => cubit.close(),
    );

  // Phase 12 — hydrate auth state BEFORE runApp. THIS ORDERING IS
  // LOAD-BEARING: `SecureStore.read` is async but go_router's `redirect` is
  // synchronous, so the guard can only read in-memory Cubit state. Without
  // this awaited restore, an authenticated user is bounced to /login on every
  // cold start — intermittently, and never on a warm reload, which makes it
  // painful to diagnose.
  await getIt<AuthCubit>().restoreSession();

  // Phase 13 — router last, so it closes over the already-hydrated AuthCubit.
  // One instance, so the GoRouterRefreshStream subscription is created and
  // cancelled exactly once.
  getIt.registerLazySingleton<GoRouter>(
    () => createRouter(getIt<AuthCubit>()),
    dispose: (router) => router.dispose(),
  );

  // A no-op today, because nothing uses `registerSingletonAsync`. It is here
  // so that adding an async singleton later does not silently race: the day
  // someone does, this line already waits for it.
  await getIt.allReady();
}

/// Tears down every registration, in reverse registration order.
///
/// Call this in `tearDown` so no state leaks between tests. Returning the
/// future (rather than awaiting it in a `void` callback) is what satisfies
/// `discarded_futures`:
///
/// ```dart
/// tearDown(resetDependencies);
/// ```
///
/// Three ways to override a registration in a test, in order of preference:
///
/// **(a) Full reset in `setUp` — the default.** LIFO disposal since get_it
/// 9.0.0 makes this deterministic. Note `InMemoryKeyValueStore`: it is what
/// lets a widget test skip `Hive.initFlutter()` and its `path_provider`
/// platform channel entirely.
///
/// ```dart
/// setUp(() async {
///   await resetDependencies();
///   getIt
///     ..registerSingleton<FlavorConfig>(testConfig)
///     ..registerSingleton<KeyValueStore>(InMemoryKeyValueStore())
///     ..registerLazySingleton<AuthRepository>(MockAuthRepository.new)
///     ..registerLazySingleton<AuthCubit>(
///       () => AuthCubit(getIt<AuthRepository>()),
///       dispose: (cubit) => cubit.close(),
///     );
/// });
///
/// tearDown(resetDependencies);
/// ```
///
/// **(b) `pushNewScope` / `popScope` — override a subset, keep the rest.**
/// Registrations made inside a scope hide earlier ones of the same type.
///
/// **(c) `allowReassignment = true` — last resort.** It disables the
/// duplicate-registration assert GLOBALLY, so a genuine double-registration
/// bug stops being caught for the rest of the run. Prefer (a) or (b).
///
/// For a test that must be fully independent of the app's container, use
/// `GetIt.asNewInstance()` — a separate container with no shared state, and
/// exactly the case the old `static late FlavorConfig current` could not
/// support.
Future<void> resetDependencies() => getIt.reset();

/// The default `RefreshToken` until a real refresh endpoint exists.
///
/// Returning null means "this session cannot be recovered", which makes
/// `AuthInterceptor` clear secure storage and let the original 401 through as
/// an `UnauthorizedError`. That is the correct behaviour for a scaffold: it
/// signs the user out rather than pretending a refresh succeeded.
///
/// Replace it with the auth repository's real refresh call — which must issue
/// its request through the replay client registered under
/// [kReplayClientName], for the deadlock reason in auth_interceptor.dart.
Future<String?> _sessionCannotBeRefreshed() async => null;
