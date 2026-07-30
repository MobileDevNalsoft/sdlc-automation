// Coverage ratchet for lib/**/bloc/** and lib/**/services/** only — never the
// whole repo (a flat `--min-coverage 100` requirement on a codebase with ~0
// existing tests was explicitly rejected; see flutter-verify's SKILL.md cut
// list). Reads a genhtml/lcov-format `coverage/lcov.info` (produced by
// `flutter test --coverage`), sums hit/found lines restricted to that scope,
// and compares the ratio against a stored baseline. Exits 1 if the ratio
// dropped since the last recorded baseline; on a pass, rewrites the baseline
// to the new (never-lower) value so the next run ratchets forward from there.
//
// Usage:
//   dart run tools/coverage_ratchet.dart [lcov_path] [baseline_path]
// Defaults: coverage/lcov.info, coverage/.coverage_ratchet_baseline.json
//
// First run ever (no baseline file yet) always passes and just records the
// starting point — a ratchet has nothing to compare against on run 1.

import 'dart:convert';
import 'dart:io';

const _scopedDirs = ['/bloc/', '/services/'];

void main(List<String> args) {
  final lcovPath = args.isNotEmpty ? args[0] : 'coverage/lcov.info';
  final baselinePath = args.length > 1
      ? args[1]
      : 'coverage/.coverage_ratchet_baseline.json';

  final lcovFile = File(lcovPath);
  if (!lcovFile.existsSync()) {
    stderr.writeln(
      'coverage_ratchet: $lcovPath not found — run `flutter test --coverage` '
      'first.',
    );
    exit(1);
  }

  final totals = _scopedTotals(lcovFile.readAsLinesSync());
  if (totals.found == 0) {
    print(
      'coverage_ratchet: no lib/**/bloc/** or lib/**/services/** files found '
      'in $lcovPath — nothing scoped to check, treating as pass.',
    );
    return;
  }
  final ratio = totals.hit / totals.found;

  final baselineFile = File(baselinePath);
  if (!baselineFile.existsSync()) {
    _writeBaseline(baselineFile, ratio, totals);
    print(
      'coverage_ratchet: no baseline yet — recorded ${_pct(ratio)} as the '
      'starting point (${totals.hit}/${totals.found} lines in '
      'bloc/+services/).',
    );
    return;
  }

  final previous =
      jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>;
  final previousRatio = (previous['ratio'] as num).toDouble();

  if (ratio + 1e-9 < previousRatio) {
    stderr.writeln(
      'coverage_ratchet: FAIL — bloc/+services/ coverage dropped from '
      '${_pct(previousRatio)} to ${_pct(ratio)} '
      '(${totals.hit}/${totals.found} lines).',
    );
    exit(1);
  }

  _writeBaseline(baselineFile, ratio, totals);
  print(
    'coverage_ratchet: PASS — ${_pct(ratio)} '
    '(was ${_pct(previousRatio)}; ${totals.hit}/${totals.found} lines).',
  );
}

class _Totals {
  const _Totals(this.hit, this.found);

  final int hit;
  final int found;
}

_Totals _scopedTotals(List<String> lines) {
  var inScope = false;
  var hit = 0;
  var found = 0;
  for (final line in lines) {
    if (line.startsWith('SF:')) {
      final path = line.substring(3).replaceAll('\\', '/');
      inScope = _scopedDirs.any(path.contains);
    } else if (inScope && line.startsWith('LH:')) {
      hit += int.parse(line.substring(3));
    } else if (inScope && line.startsWith('LF:')) {
      found += int.parse(line.substring(3));
    } else if (line == 'end_of_record') {
      inScope = false;
    }
  }
  return _Totals(hit, found);
}

void _writeBaseline(File file, double ratio, _Totals totals) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'ratio': ratio,
      'linesHit': totals.hit,
      'linesFound': totals.found,
      'updatedUtc': DateTime.now().toUtc().toIso8601String(),
    }),
  );
}

String _pct(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';
