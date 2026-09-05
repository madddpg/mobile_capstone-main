import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/core/firebase/firestore_coerce.dart';

void main() {
  group('asInt / asDouble tolerate the wrong scalar type', () {
    test('a web-written double is read as an int', () {
      expect(asInt(5.0), 5);
      expect(asInt(5.6), 6);
    });

    test('a numeric string is parsed', () {
      expect(asInt('7'), 7);
      expect(asDouble('20'), 20.0);
      expect(asDouble('20.5'), 20.5);
    });

    test('garbage / null fall back without throwing', () {
      expect(asInt(null), 0);
      expect(asInt('abc'), 0);
      expect(asDouble(null, fallback: 1.0), 1.0);
      expect(asDouble({'x': 1}), 0.0);
    });
  });

  group('asStringOrNull', () {
    test('maps empty and the literal "null" to null', () {
      expect(asStringOrNull(''), isNull);
      expect(asStringOrNull('  '), isNull);
      expect(asStringOrNull('null'), isNull);
      expect(asStringOrNull('abc'), 'abc');
    });
  });

  group('asDate', () {
    test('parses millis, seconds, and ISO strings', () {
      final ms = DateTime.utc(2026, 1, 2, 3, 4, 5);
      expect(asDate(ms.millisecondsSinceEpoch)!.toUtc(), ms);
      expect(
        asDate(ms.millisecondsSinceEpoch ~/ 1000)!.toUtc(),
        ms,
      );
      expect(asDate('2026-01-02T03:04:05Z')!.toUtc(), ms);
      expect(asDate(null), isNull);
      expect(asDate('not a date'), isNull);
    });
  });

  group('firstOf', () {
    test('returns the first present non-empty aliased key', () {
      final data = <String, dynamic>{
        'costLevel': '',
        'budget': 'low',
      };
      expect(firstOf(data, ['costLevel', 'budget']), 'low');
      expect(firstOf(data, ['missing', 'alsoMissing']), isNull);
    });
  });

  group('asList / asMapList', () {
    test('wraps a scalar, passes a list, skips non-map rows', () {
      expect(asList(null), isEmpty);
      expect(asList('x'), ['x']);
      expect(asList([1, 2]), [1, 2]);
      expect(
        asMapList([
          {'name': 'a'},
          'skip me',
          {'name': 'b'},
        ]).map((m) => m['name']).toList(),
        ['a', 'b'],
      );
    });
  });
}
