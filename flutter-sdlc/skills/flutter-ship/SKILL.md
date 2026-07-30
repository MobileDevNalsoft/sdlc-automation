---
name: flutter-ship
description: Use to build and release a Flutter Android app — flavored builds, key.properties signing, --dart-define-from-file config injection, obfuscation with symbol upload, and a versionCode strategy. Dispatched by sdlc-developer by name (flutter-sdlc:flutter-ship). iOS is a documented stub only, not an implemented path. Read the honesty notice below before trusting any version number in this file.
---

# flutter-ship

**Verb: release.**

## Honesty notice — read this first

This is deliberately the thinnest skill in this marketplace, and it is the one you should trust least without checking.

Unlike `react-sdlc`'s ship skill (which was written against a real `deploy.sh`/`Dockerfile` read off disk), **nothing here was validated against a live Flutter project or a live CI run in the session that authored it.** No reference Flutter repo was accessible; no GitHub Actions workflow was executed; no `flutter build appbundle` was run. Every CI version, runner label, and toolchain pin below carries an inline `ASSUMPTION:` marker at the point it's stated, per `sdlc-core:evidence-contract`.

Treat this skill as a structured starting point that a human confirms once, not as a verified pipeline. The first real release run **is** the verification step.

## Preconditions

Before invoking this skill:

1. `flutter-sdlc:flutter-verify` returned `GATE-PASS` (blocking checks green). Shipping an app that failed `flutter analyze --fatal-infos` or `flutter test` is out of the question.
2. `android/key.properties` exists locally, is filled in from `templates/key.properties.example`, and is **listed in `.gitignore`**. Confirm the gitignore entry by reading it — do not assume.
3. `sdlc-core:secret-scan` has run over the diff. A keystore path is fine in `key.properties`; a keystore *password* anywhere in a tracked file is a blocking finding.

## Signing — the one rule with no recovery path

`android/key.properties` and the `.jks` keystore are never committed. flutter/website's own guidance, verbatim: *"Keep the `key.properties` file private; don't check it into public source control."*

The reason this is severity-one rather than routine hygiene: a leaked **upload** key can be reset by contacting Google Play Console support, but the **Play App Signing** key — the one that signs what users actually download — has no self-service reset. There is no rotation story. See `templates/key.properties.example` for the full property shape and the Windows double-backslash `storeFile` caveat.

## Procedure (Android)

1. Determine the flavor (`dev` / `staging` / `prod`) and its matching entrypoint from `flutter-bootstrap`'s emitted `main_<flavor>.dart`.
2. Compute the `versionCode`. **ASSUMPTION:** a monotonic build counter (CI run number, or a `YYMMDDNN` stamp) is used — the correct strategy for this org was never confirmed, and Play rejects any upload whose `versionCode` is not strictly greater than the last one accepted, so getting this wrong costs a release cycle. Pick one, write it down, and never let two builds share a number.
3. Inject flavor config with `--dart-define-from-file=config/<flavor>.json` rather than committing per-flavor Dart constants. Keep the config files free of secrets — `--dart-define` values land in the built binary and are recoverable from it.
4. Build with obfuscation and split debug symbols:
   ```
   flutter build appbundle \
     --flavor <flavor> \
     --dart-define-from-file=config/<flavor>.json \
     --obfuscate --split-debug-info=build/symbols/<flavor>/<versionCode>
   ```
5. **Upload the symbols to Sentry** (`sentry_flutter` 9.25.0 is a required dependency per `flutter-bootstrap`). Obfuscation without symbol upload converts every field crash into unreadable noise — these two steps are one step, never separated. Retain the symbol directory keyed by `versionCode`; a crash report from an old build is undebuggable once its symbols are gone.
6. Verify the artifact is signed with the intended key before upload (`jarsigner -verify -verbose` or `bundletool`), rather than trusting that Gradle picked up `key.properties`.
7. Record the shipped `versionCode`, git SHA, and symbol path together, so a rollback or a crash triage six weeks later can find all three.

## iOS — documented stub, not implemented

Local iOS builds are impossible on this win32 machine, and no macOS CI runner exists for this org yet. This skill does not implement an iOS path.

What it would need: a macOS runner (**ASSUMPTION:** `macos-14` is the commonly-used GitHub Actions label — not confirmed against a current runner-image list this session), an Apple Developer account with provisioning profiles and a distribution certificate in the CI keychain, and `flutter build ipa` + `xcrun altool`/`notarytool` for upload. Treat all of that as an unstarted work item, not a partially-working path.

## CI — every version below is unverified

**ASSUMPTION:** Java 17 for the Android toolchain. This is a guess. Recent Android Gradle Plugin versions may require Java 21, and flutter/website's `deployment/android.md` contains no flavors-or-JDK content that would settle it. Confirm against the AGP version in `android/build.gradle` before trusting it.

**ASSUMPTION:** every GitHub Actions action version (`actions/checkout`, `actions/setup-java`, `subosito/flutter-action`) — none were fetched. Pin them to current SHAs at the time you first wire up CI, and record the date.

Wire `osv-scanner` (dependency CVEs) and `gitleaks` (secret scanning) into the same workflow — both were adopted by `flutter-bootstrap` and this is where they run.

## STOP CONDITIONS

Return control rather than proceeding when:

- `flutter-verify` did not return `GATE-PASS`.
- `android/key.properties` is missing, or **is not gitignored** — the second case is a blocking security finding, not a setup nuisance.
- The `versionCode` strategy is undecided, or the computed value is not strictly greater than the last shipped one.
- Symbol upload failed while obfuscation succeeded — do not ship a build whose crashes will be unreadable.
- The task is an iOS release. That path does not exist here; say so plainly rather than improvising one.
