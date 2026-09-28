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
  half(
    'Half',
    'Half of the space. Measure the whole room and every surface is sized at '
        'half',
  ),
  partial(
    'Partial',
    'One part of the space: a shower area, one wall, a section of floor',
  );

  final String label;
  final String description;

  const RenovationCoverage(this.label, this.description);

  /// Whether the builder is asked which part of the space the work covers.
  /// Only a partial job has a portion to describe.
  bool get hasPortion => this == RenovationCoverage.partial;

  /// Whether the whole room is measured and every surface sized at half of
  /// it. A partial job is the opposite: the part itself is measured.
  bool get isHalf => this == RenovationCoverage.half;

  /// Reads a saved value. An estimate saved before coverage existed covered
  /// the whole space, because that was the only thing the app could describe.
  ///
  /// "Extension" was an option until it was replaced by Half. An extension
  /// was measured whole and sized from everything measured, which is what
  /// Full does, so an estimate saved as one reads as Full.
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
    if (lower.contains('half')) return RenovationCoverage.half;
    return RenovationCoverage.full;
  }
}
