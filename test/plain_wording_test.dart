// Builders read these screens in plain words: "select" or "choose", never
// "tick", which testers did not recognise. Every string in lib/ is scanned,
// so the word cannot come back on a screen nobody re-reads.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/auth/presentation/screens/saved_projects.dart';

final _identifierChar = RegExp(r'[A-Za-z0-9_$]');

/// The string literals in Dart [source], with comments left out. Interpolated
/// code is left out too, so a variable named `ticked` is not a word on screen.
List<String> stringLiterals(String source) {
  final literals = <String>[];
  final n = source.length;
  var i = 0;
  while (i < n) {
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end == -1 ? n : end + 1;
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      i = end == -1 ? n : end + 2;
      continue;
    }
    final c = source[i];
    if (c != "'" && c != '"') {
      i++;
      continue;
    }
    final raw = i > 0 &&
        source[i - 1] == 'r' &&
        (i < 2 || !_identifierChar.hasMatch(source[i - 2]));
    final quote = source.startsWith(c * 3, i) ? c * 3 : c;
    i += quote.length;
    final text = StringBuffer();
    while (i < n && !source.startsWith(quote, i)) {
      if (!raw && source[i] == r'\') {
        text.write(' ');
        i += 2;
      } else if (!raw && source.startsWith(r'${', i)) {
        var depth = 0;
        while (i < n) {
          final ch = source[i++];
          if (ch == '{') depth++;
          if (ch == '}' && --depth == 0) break;
        }
        text.write(' ');
      } else if (!raw && source[i] == r'$') {
        i++;
        while (i < n && _identifierChar.hasMatch(source[i]) && source[i] != r'$') {
          i++;
        }
        text.write(' ');
      } else {
        text.write(source[i++]);
      }
    }
    i += quote.length;
    literals.add(text.toString());
  }
  return literals;
}

void main() {
  test('no text in the app asks the builder to "tick" anything', () {
    final tick = RegExp(r'\b(un)?tick(s|ed|ing)?\b', caseSensitive: false);
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final literal in stringLiterals(entity.readAsStringSync())) {
        if (tick.hasMatch(literal)) offenders.add('${entity.path}: $literal');
      }
    }
    expect(offenders, isEmpty);
  });

  test('My Projects says when an estimate changed in proper English', () {
    // It said "Updated 1 hours ago" and "Updated 0 mins ago".
    final now = DateTime(2026, 10, 10, 12);
    String ago(Duration d) =>
        ProjectCard.formatTimeAgo(now.subtract(d), now: now);
    expect(ago(const Duration(seconds: 20)), 'Updated just now');
    expect(ago(const Duration(minutes: 1)), 'Updated 1 minute ago');
    expect(ago(const Duration(minutes: 5)), 'Updated 5 minutes ago');
    expect(ago(const Duration(hours: 1)), 'Updated 1 hour ago');
    expect(ago(const Duration(hours: 3)), 'Updated 3 hours ago');
    expect(ago(const Duration(days: 1)), 'Updated 1 day ago');
    expect(ago(const Duration(days: 4)), 'Updated 4 days ago');
  });

  test('a saved estimate is summed up in proper English', () {
    // It read "10 Materials • 7.50 sq.m • 🟡 medium Cost": the level is the
    // budget preference, and the app prices nothing.
    expect(ProjectCard.summaryLine(10, 7.5, 'medium'),
        '10 materials • 7.50 sq.m • 🟡 Medium budget');
    expect(ProjectCard.summaryLine(1, 3, 'High'),
        '1 material • 3.00 sq.m • 🔴 High budget');
    expect(ProjectCard.summaryLine(4, 12, 'low'),
        '4 materials • 12.00 sq.m • 🟢 Low budget');
    // No preference on record: nothing is made up.
    expect(ProjectCard.summaryLine(4, 12, 'Unknown'), '4 materials • 12.00 sq.m');
  });

  group('stringLiterals', () {
    test('reads strings, not comments', () {
      expect(
        stringLiterals("// tick the box\nfinal a = 'Select all'; /* tick */"),
        ['Select all'],
      );
    });

    test('leaves out interpolated names', () {
      expect(
        stringLiterals(r"'${ticked.map((i) => i.label).join('; ')}.'"),
        [' .'],
      );
      expect(stringLiterals(r"'$ticked items'"), ['  items']);
    });

    test('reads raw, escaped and triple-quoted strings', () {
      expect(stringLiterals(r"r'C:\' + 'it\'s'"), [r'C:\', 'it s']);
      expect(stringLiterals("'''Tick\nall'''"), ['Tick\nall']);
    });

    test('catches the old label', () {
      expect(
        stringLiterals("Text('KIND OF WORK · TICK ALL THAT APPLY')")
            .single,
        contains('TICK'),
      );
    });
  });
}
