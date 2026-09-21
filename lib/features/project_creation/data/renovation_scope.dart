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

/// The kinds of work one estimate covers — one or more of cosmetic,
/// structural and functional.
///
/// A real job is often more than one: retiling a bathroom and replacing its
/// supply pipes is cosmetic and functional at once, and forcing a single choice
/// meant one half of the job had no materials. This answers the same questions
/// a single [RenovationScope] does — whether structural materials belong,
/// whether finishes are measured — for the combination.
class RenovationTypes {
  /// Always at least one, held in the enum's order so two selections of the
  /// same kinds compare equal however they were picked.
  final List<RenovationScope> values;

  RenovationTypes._(this.values);

  factory RenovationTypes(Iterable<RenovationScope> selected) {
    final set = selected.toSet();
    if (set.isEmpty) {
      throw ArgumentError('An estimate needs at least one kind of work.');
    }
    return RenovationTypes._(
      List.unmodifiable(RenovationScope.values.where(set.contains)),
    );
  }

  factory RenovationTypes.only(RenovationScope scope) =>
      RenovationTypes([scope]);

  bool contains(RenovationScope scope) => values.contains(scope);

  bool get isMultiple => values.length > 1;

  /// Whether heavy structural materials belong: any structural work does.
  bool get includesStructural => contains(RenovationScope.structural);

  /// Whether pipes or wiring are being replaced.
  bool get includesFunctional => contains(RenovationScope.functional);

  /// Whether the room's finishes are measured and fitted. True as soon as any
  /// selected kind changes them; only a purely functional job leaves them.
  bool get changesFinishes => values.any((s) => s.changesFinishes);

  /// The one kind written to `projectScope`, which the shop dashboard reads as
  /// a single label and which older estimates hold. The heaviest kind wins:
  /// structural work, then functional work that opens walls and floors, then
  /// finishes.
  RenovationScope get primary {
    for (final scope in const [
      RenovationScope.structural,
      RenovationScope.functional,
      RenovationScope.cosmetic,
    ]) {
      if (contains(scope)) return scope;
    }
    return values.first;
  }

  /// "Cosmetic + Functional"
  String get label => values.map((s) => s.label).join(' + ');

  /// Each kind's description, in order, so the AI is told every part of the
  /// job rather than only the heaviest.
  String get description => values.map((s) => s.description).join('; ');

  List<String> get names => [for (final s in values) s.name];

  /// Reads a saved selection. An estimate saved before more than one kind
  /// could be chosen has only `projectScope`, which is its single kind.
  static RenovationTypes fromStored(Object? names, String? legacyScope) {
    if (names is List) {
      final picked = [
        for (final name in names)
          ...RenovationScope.values.where((s) => s.name == '$name'),
      ];
      if (picked.isNotEmpty) return RenovationTypes(picked);
    }
    return RenovationTypes.only(RenovationScope.fromString(legacyScope));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RenovationTypes &&
          other.values.length == values.length &&
          values.every(other.values.contains));

  @override
  int get hashCode => Object.hashAll(values);

  @override
  String toString() => 'RenovationTypes($label)';
}
