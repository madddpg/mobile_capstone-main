/// The type of renovation, chosen right after the project.
///
/// It decides which template a builder gets, what the AI may recommend, and
/// whether structural materials such as CHB, rebar and gravel belong in the
/// estimate at all.
enum RenovationScope {
  cosmetic(
    'Cosmetic',
    'Repainting walls, replacing tiles and other finishes',
  ),
  structural(
    'Structural',
    'Changing the layout, making a room bigger, or foundation repair and underpinning',
  ),
  functional(
    'Functional',
    'Upgrading plumbing or replacing electrical wiring',
  );

  final String label;
  final String description;

  const RenovationScope(this.label, this.description);

  /// Whether heavy structural materials (gravel, CHB, rebar, formwork) belong.
  bool get includesStructural => this == structural;

  /// Whether the job changes finishes, so the room's floor, wall tile and
  /// paint are measured and fitted. Functional work leaves finishes alone.
  bool get changesFinishes => this != functional;

  /// Reads a saved label. Estimates saved before the three types existed say
  /// "Full Renovation" or "Extension", which map to cosmetic and structural.
  static RenovationScope fromString(String? value) {
    if (value == null) return RenovationScope.cosmetic;
    final lower = value.toLowerCase().trim();
    if (lower.contains('structural') ||
        lower.contains('extension') ||
        lower.contains('addition') ||
        lower.contains('new build')) {
      return RenovationScope.structural;
    }
    if (lower.contains('functional') ||
        lower.contains('plumbing') ||
        lower.contains('electrical')) {
      return RenovationScope.functional;
    }
    return RenovationScope.cosmetic;
  }
}
