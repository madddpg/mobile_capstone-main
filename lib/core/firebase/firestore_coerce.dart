/// Defensive scalar coercion for Firestore document data.
///
/// The web shop dashboard and the mobile app share one Firestore project and are
/// developed independently. A field the app expects as an `int` can arrive from
/// the web as a JS number that Firestore stores as a `double` (`5.0`), an area
/// can arrive as a `"20"` string, a timestamp as millis or an ISO string. Raw
/// casts (`data['x'] as int`, `(data['x'] ?? 0).toDouble()`) then throw on read
/// and crash whole list screens. These helpers never throw.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

num? asNum(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v.trim());
  if (v is bool) return v ? 1 : 0;
  return null;
}

int asInt(Object? v, {int fallback = 0}) => asNum(v)?.round() ?? fallback;

double asDouble(Object? v, {double fallback = 0.0}) =>
    asNum(v)?.toDouble() ?? fallback;

String asString(Object? v, {String fallback = ''}) {
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

/// Like [asString] but maps empty / the literal string `"null"` to `null`.
String? asStringOrNull(Object? v) {
  if (v == null) return null;
  final s = v is String ? v : v.toString();
  final t = s.trim();
  if (t.isEmpty || t.toLowerCase() == 'null') return null;
  return s;
}

bool asBool(Object? v, {bool fallback = false}) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final t = v.trim().toLowerCase();
    if (t == 'true' || t == '1' || t == 'yes') return true;
    if (t == 'false' || t == '0' || t == 'no') return false;
  }
  return fallback;
}

/// Accepts Firestore [Timestamp], `DateTime`, epoch millis (int/num/String), or
/// an ISO-8601 string. Returns `null` when nothing usable is present.
DateTime? asDate(Object? v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is num) {
    // Heuristic: > 10^11 is almost certainly millis, otherwise seconds.
    final n = v.toInt();
    return DateTime.fromMillisecondsSinceEpoch(n.abs() > 100000000000 ? n : n * 1000);
  }
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty) return null;
    final parsed = DateTime.tryParse(t);
    if (parsed != null) return parsed;
    final millis = int.tryParse(t);
    if (millis != null) {
      return DateTime.fromMillisecondsSinceEpoch(
          millis.abs() > 100000000000 ? millis : millis * 1000);
    }
  }
  return null;
}

/// Coerces a value into a `List<dynamic>` — tolerates `null`, a single scalar
/// (wrapped), or an already-list value.
List<dynamic> asList(Object? v) {
  if (v == null) return const [];
  if (v is List) return v;
  if (v is Iterable) return v.toList();
  return [v];
}

/// Coerces a list of maps (e.g. structured `materials`), skipping non-map rows.
List<Map<String, dynamic>> asMapList(Object? v) {
  final out = <Map<String, dynamic>>[];
  for (final row in asList(v)) {
    if (row is Map<String, dynamic>) {
      out.add(row);
    } else if (row is Map) {
      out.add(Map<String, dynamic>.from(row));
    }
  }
  return out;
}

/// Reads the first present, non-empty value among [keys] — used where the web
/// and app disagree on a field name (`costLevel`/`budget`,
/// `projectNotes`/`remarks`, `materials`/`selectedMaterials`, …).
Object? firstOf(Map<String, dynamic> data, List<String> keys) {
  for (final k in keys) {
    final v = data[k];
    if (v == null) continue;
    if (v is String && v.trim().isEmpty) continue;
    return v;
  }
  return null;
}
