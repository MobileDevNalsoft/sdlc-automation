// Fails the build if any file under lib/features/<feature>/ imports another
// feature's lib/features/<other>/ path directly. Cross-feature code must go
// through lib/core/ or lib/shared/ instead — those two are the only allowed
// shared layers, so they are exempt from this check by construction (the
// pattern below only matches imports of *other* features/<name>/ paths).
//
// Usage: dart run tools/check_boundaries.dart
import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml');
  final pkg = pubspec.existsSync()
      ? RegExp(
          r'^name:\s*(\S+)',
          multiLine: true,
        ).firstMatch(pubspec.readAsStringSync())?.group(1)
      : null;
  final featuresDir = Directory('lib/features');
  if (pkg == null || !featuresDir.existsSync()) {
    print(
      'check_boundaries: no lib/features/ (or no pubspec name) — skipping.',
    );
    return;
  }

  final crossImport = RegExp(
    "import\\s+['\"]package:$pkg/features/([^/'\"]+)/",
  );
  final violations = <String>[];

  for (final entity in featuresDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final segments = entity.path.replaceAll('\\', '/').split('/');
    final ownFeature = segments[segments.indexOf('features') + 1];
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final match = crossImport.firstMatch(lines[i]);
      if (match != null && match.group(1) != ownFeature) {
        violations.add(
          '${entity.path}:${i + 1} — imports feature "${match.group(1)}" '
          'from inside feature "$ownFeature" (route it through lib/core or '
          'lib/shared instead)',
        );
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Cross-feature boundary violations found:');
    violations.forEach(stderr.writeln);
    exit(1);
  }
  print('check_boundaries: no cross-feature violations in lib/features/.');
}
