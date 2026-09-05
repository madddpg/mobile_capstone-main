/// Renovation scope options for iConstruct canvassing and planning.
enum RenovationScope {
  fullRenovation(
    'Full Renovation',
    'Redo finishes — tiles, paint, fixtures & tile bedding screed',
  ),
  extension(
    'Extension',
    'New space — includes structural concrete, CHB masonry, rebar & roof',
  );

  final String label;
  final String description;

  const RenovationScope(this.label, this.description);

  /// Whether this scope includes heavy structural materials (gravel, CHB, rebar, roofing).
  bool get includesStructural => this == extension;

  static RenovationScope fromString(String? value) {
    if (value == null) return RenovationScope.fullRenovation;
    final lower = value.toLowerCase().trim();
    if (lower.contains('extension') || lower.contains('addition') || lower.contains('new build')) {
      return RenovationScope.extension;
    }
    return RenovationScope.fullRenovation;
  }
}
