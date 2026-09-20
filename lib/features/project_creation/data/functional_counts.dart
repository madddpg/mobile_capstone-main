import 'package:iconstruct/features/project_creation/data/site_details.dart';

/// How many electrical devices a functional (wiring) job installs.
///
/// Functional work used to size outlets, switches, lights, conduit and wire
/// off the room's floor area: a 39 sq.m living room and a 12 sq.m bedroom got
/// wiring proportional to their floors, whether the builder wanted three
/// outlets or ten. The floor area is not what drives a wiring job — the
/// number of devices the builder actually wants is — so functional work asks
/// for that number instead of guessing it from the room's size.
class FunctionalCounts {
  final int outlets;
  final int switches;
  final int lights;

  const FunctionalCounts({
    this.outlets = 0,
    this.switches = 0,
    this.lights = 0,
  });

  static const FunctionalCounts none = FunctionalCounts();

  /// Every device that needs its own utility box: an outlet, a switch and a
  /// light each sit in one.
  int get deviceCount => outlets + switches + lights;

  bool get isEmpty => deviceCount == 0;

  FunctionalCounts copyWith({int? outlets, int? switches, int? lights}) =>
      FunctionalCounts(
        outlets: outlets ?? this.outlets,
        switches: switches ?? this.switches,
        lights: lights ?? this.lights,
      );

  /// A starting point so the form is not blank, not a rule the builder has to
  /// keep. Typical counts for a Philippine residential room of that kind.
  factory FunctionalCounts.defaultsFor(RoomJob? job) {
    return switch (job) {
      RoomJob.kitchen => const FunctionalCounts(outlets: 4, switches: 2, lights: 2),
      RoomJob.wetRoom => const FunctionalCounts(outlets: 1, switches: 1, lights: 1),
      RoomJob.dryRoom => const FunctionalCounts(outlets: 3, switches: 1, lights: 1),
      _ => FunctionalCounts.none,
    };
  }

  Map<String, dynamic> toMap() => {
        'outlets': outlets,
        'switches': switches,
        'lights': lights,
      };

  static FunctionalCounts? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    int asInt(Object? v) =>
        v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    final counts = FunctionalCounts(
      outlets: asInt(map['outlets']),
      switches: asInt(map['switches']),
      lights: asInt(map['lights']),
    );
    return counts;
  }

  @override
  String toString() =>
      'FunctionalCounts(outlets: $outlets, switches: $switches, lights: $lights)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FunctionalCounts &&
          outlets == other.outlets &&
          switches == other.switches &&
          lights == other.lights);

  @override
  int get hashCode => Object.hash(outlets, switches, lights);
}
