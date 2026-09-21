/// How much of the space a job covers, which is a different question from what
/// kind of work it is.
///
/// Deliberately not called "scope". `projectScope` already carries the
/// renovation type — Cosmetic, Structural or Functional — in Firestore, and
/// [RenovationScope.fromString] already reads the words "Full Renovation" and
/// "Extension" as types, because those were that field's values before an
/// earlier rename. Writing coverage into `projectScope` would make every
/// estimate saved under the old spelling ambiguous, on a database a second
/// application also reads. Coverage is its own field and never touches that
/// one.
library;

enum RenovationCoverage {
  full(
    'Full',
    'The whole space, wall to wall',
  ),
  partial(
    'Partial',
    'One part of the space: a shower area, one wall, a section of floor',
  ),
  extension(
    'Extension',
    'New floor area added to the existing space',
  );

  final String label;
  final String description;

  const RenovationCoverage(this.label, this.description);

  /// Whether the builder is asked which part of the space the work covers.
  /// Only a partial job has a portion to describe.
  bool get hasPortion => this == RenovationCoverage.partial;

  /// Whether the measurements describe new floor area rather than existing.
  bool get isNewArea => this == RenovationCoverage.extension;

  /// Reads a saved value. An estimate saved before coverage existed covered
  /// the whole space, because that was the only thing the app could describe.
  static RenovationCoverage fromString(String? value) {
    final lower = (value ?? '').toLowerCase().trim();
    if (lower.isEmpty) return RenovationCoverage.full;
    for (final coverage in RenovationCoverage.values) {
      if (lower == coverage.name || lower == coverage.label.toLowerCase()) {
        return coverage;
      }
    }
    if (lower.contains('partial') || lower.contains('portion')) {
      return RenovationCoverage.partial;
    }
    if (lower.contains('extension') || lower.contains('addition')) {
      return RenovationCoverage.extension;
    }
    return RenovationCoverage.full;
  }
}
