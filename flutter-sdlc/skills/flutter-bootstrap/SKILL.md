---
name: flutter-bootstrap
description: Scaffolds a production-grade Flutter application with flutter_bloc (Cubit), GoRouter, Freezed sealed states, centralized design tokens, 5-state UI widgets, boundary verification script, and full 10-document context generation via docs-scaffold.
---

# flutter-bootstrap

**Verb: scaffold.**

## 1. Architectural Invariants

Every Flutter application scaffolded by this skill must uphold five non-negotiable architectural invariants:

1. **Strict Feature Folder Boundaries**: Features reside exclusively under `lib/features/<feature>/`. Zero imports between sibling features. Enforced by `tools/check_boundaries.dart`; violations fail CI.
2. **Centralized Design Tokens**: `lib/core/theme/` defines all visual tokens (`AppColors`, `AppTypography`, `AppTheme`). Feature widgets are strictly forbidden from hardcoding raw `Color(0x...)` or ad-hoc `TextStyle` literals.
3. **5-State UI Completeness**: Every screen must explicitly handle all 5 states: Loading (`AppLoader` / skeleton), Empty (`AppEmptyState`), Error (`AppErrorView` with retry), Gated (`AppGateState`), and Loaded.
4. **Resilient HTTP Client**: Centralized Dio client (`lib/core/network/api_client.dart`) with auth bearer token injection, exponential backoff retries on idempotent requests, and RFC 9457 error mapping.
5. **Context Before Code**: Dispatches `docs-architect:docs-scaffold` on Day 0 to emit the 10-document context suite into `docs/` and root `AGENTS.md`.

---

## 2. Directory Structure Contract

```
<project-root>/
├── docs/                             # Emitted by docs-scaffold
│   ├── PRD.md
│   ├── UX_FLOWS.md
│   ├── DESIGN_SYSTEM.md
│   ├── ARCHITECTURE.md
│   ├── DATABASE.md
│   ├── API.md
│   ├── SECURITY.md
│   ├── CODE_STYLE.md
│   └── TESTING.md
├── lib/
│   ├── app/                          # App root & bootstrap
│   ├── core/
│   │   ├── di/                       # get_it service locator
│   │   ├── error/                    # app_error.dart (sealed hierarchy)
│   │   ├── network/                  # Dio api_client.dart & interceptors
│   │   ├── router/                   # GoRouter configuration & guards
│   │   └── theme/                    # app_theme.dart & design tokens
│   ├── features/                     # Isolated vertical slices
│   │   └── <feature>/
│   │       ├── data/                 # DTOs, services, repositories
│   │       ├── domain/               # Pure entity models
│   │       └── presentation/         # Cubit, Freezed states, screens
│   └── shared/
│       └── widgets/                  # 5-state UI widgets (Button, Loader, Empty, Error, Gate)
├── tools/
│   └── check_boundaries.dart         # Dart script checking 0 cross-feature imports
├── test/
├── AGENTS.md                         # Operational instructions for AI coding assistants
├── analysis_options.yaml             # very_good_analysis ruleset
└── pubspec.yaml
```

---

## 3. Scaffolding Procedure

1. **Initialize Project Substrate**:
   ```bash
   flutter create --org com.nalsoft <project-name>
   ```
2. **Configure Pinned Dependencies (`pubspec.yaml`)**:
   - State & Architecture: `flutter_bloc: ^8.1.0`, `freezed_annotation: ^2.4.0`, `get_it: ^7.7.0`, `go_router: ^14.0.0`.
   - Networking & Storage: `dio: ^5.7.0`, `hive_ce_flutter: ^2.2.0`.
   - Development & CodeGen: `build_runner: ^2.4.0`, `freezed: ^2.5.0`, `very_good_analysis: ^6.0.0`.
3. **Emit 10-Document Context Suite**:
   Invoke `docs-architect:docs-scaffold` targeting `flutter` profile. Emits `docs/` and root `AGENTS.md`.
4. **Overlay Architecture & Shared Widgets**:
   - Copy `lib/core/` (theme, DI, network, router, error models).
   - Copy `lib/shared/widgets/` (AppButton, AppLoader, AppEmptyState, AppErrorView, AppGateState).
   - Copy `tools/check_boundaries.dart`.
5. **Configure Boundary Rules in `analysis_options.yaml`**:
   Apply `very_good_analysis` baseline.
6. **Establish 3-Tier Agent Context**:
   Invoke `docs-architect:docs-context` to parse Dart AST classes and imports via `code-review-graph`.
7. **Run Verification Gates**:
   - `flutter analyze --fatal-infos`
   - `dart run tools/check_boundaries.dart`
   - `flutter test`
