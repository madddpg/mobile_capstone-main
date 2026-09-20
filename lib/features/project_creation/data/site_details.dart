/// Site details for room renovations: what a foreman measures before listing
/// materials.
///
/// The estimate used to start from one number, the floor area, and assume the
/// walls were 2.2 times that. Wall area depends on the room's shape, its
/// height and its doors and windows, so a long narrow room, a high ceiling or
/// a wall of windows each threw every wall material off. These are the
/// measurements that decide wall and floor quantities, and [SiteTakeoff] turns
/// them into the surface each material is sized from.
library;

import 'dart:math' as math;

/// The kind of room job, which decides what is measured and which finishes
/// the bill of materials has to carry.
enum RoomJob {
  /// Bathroom or laundry: tiled walls and a waterproofed floor.
  wetRoom,

  /// Kitchen: floor, backsplash along the counter, painted walls.
  kitchen,

  /// Living room, bedroom or dining room: floor and painted walls.
  dryRoom,

  /// Floor renovation: the floor and its skirting only.
  floorOnly,

  /// Interior painting or wall finishing: walls and ceiling only.
  wallsOnly,
}

extension RoomJobInfo on RoomJob {
  bool get hasFloor => this != RoomJob.wallsOnly;
  bool get hasWalls => this != RoomJob.floorOnly;
  bool get offersWallTiles => this != RoomJob.floorOnly;
  bool get hasWaterproofing => this == RoomJob.wetRoom;
  bool get hasSkirting => this == RoomJob.floorOnly || this == RoomJob.dryRoom;

  /// Typical ceiling height for the room, used as the form's starting value.
  double get typicalHeightM => this == RoomJob.wetRoom ? 2.4 : 2.7;
}

/// The room job for a renovation type, or `null` for work that is not sized
/// from a room, such as roofing, electrical and plumbing, which keep a plain
/// area.
RoomJob? roomJobFor(String renovationType) {
  final t = renovationType.replaceAll('\n', ' ').toLowerCase();
  if (t.contains('roof') ||
      t.contains('electric') ||
      t.contains('plumb') ||
      t.contains('extension')) {
    return null;
  }
  if (t.contains('bath') || t.contains('laundry') || t.contains('toilet')) {
    return RoomJob.wetRoom;
  }
  if (t.contains('kitchen')) return RoomJob.kitchen;
  if (t.contains('floor')) return RoomJob.floorOnly;
  if (t.contains('paint') || t.contains('wall')) return RoomJob.wallsOnly;
  if (t.contains('living') ||
      t.contains('bedroom') ||
      t.contains('dining') ||
      t.contains('room')) {
    return RoomJob.dryRoom;
  }
  return null;
}

/// How far up the walls the tiles go.
enum WallTileHeight { none, backsplash, wainscot, full }

extension WallTileHeightInfo on WallTileHeight {
  String get label => switch (this) {
        WallTileHeight.none => 'No wall tiles',
        WallTileHeight.backsplash => 'Backsplash',
        WallTileHeight.wainscot => 'Half wall (1.50 m)',
        WallTileHeight.full => 'Full height',
      };
}

/// Depth of a standard kitchen counter.
const double kCountertopDepthM = 0.60;

/// Height of a kitchen backsplash above the counter.
const double kBacksplashHeightM = 0.60;

/// Height of half-wall (wainscot) tiling.
const double kWainscotHeightM = 1.50;

/// How far a wet-room floor's waterproofing turns up the walls.
const double kWaterproofUpturnM = 0.30;

/// A door or window size, with how many of that size the room has.
class Opening {
  final double widthM;
  final double heightM;
  final int count;

  const Opening({required this.widthM, required this.heightM, this.count = 1});

  double get eachSqm => widthM * heightM;
  double get totalSqm => eachSqm * count;
  double get totalWidthM => widthM * count;

  /// "0.70 × 2.10 m"
  String get sizeLabel =>
      '${widthM.toStringAsFixed(2)} × ${heightM.toStringAsFixed(2)} m';

  bool sameSize(Opening other) =>
      (widthM - other.widthM).abs() < 0.001 &&
      (heightM - other.heightM).abs() < 0.001;

  Opening copyWith({double? widthM, double? heightM, int? count}) => Opening(
        widthM: widthM ?? this.widthM,
        heightM: heightM ?? this.heightM,
        count: count ?? this.count,
      );

  Map<String, dynamic> toMap() =>
      {'widthM': widthM, 'heightM': heightM, 'count': count};

  factory Opening.fromMap(Map<String, dynamic> map) => Opening(
        widthM: _asDouble(map['widthM']),
        heightM: _asDouble(map['heightM']),
        count: _asDouble(map['count']).round(),
      );
}

/// Door sizes sold ready-made in Philippine hardware stores.
const List<Opening> kDoorSizes = [
  Opening(widthM: 0.70, heightM: 2.10), // CR / bathroom
  Opening(widthM: 0.80, heightM: 2.10), // bedroom, kitchen
  Opening(widthM: 0.90, heightM: 2.10), // main door
];

/// Common aluminium window sizes.
const List<Opening> kWindowSizes = [
  Opening(widthM: 0.60, heightM: 0.60), // CR vent window
  Opening(widthM: 0.60, heightM: 0.90),
  Opening(widthM: 1.20, heightM: 1.20),
  Opening(widthM: 1.50, heightM: 1.20),
];

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

/// A job that covers one part of a bigger space: what the part is called, and
/// how big the whole space is.
///
/// The measured length and width describe the *part*, because the part is what
/// the materials have to cover. The whole is carried so the part can be checked
/// against it and so a shop can see the context — retiling 2 sq.m of a 12 sq.m
/// bathroom is a different job from retiling a 2 sq.m bathroom.
class PartialArea {
  /// What the builder calls the part: "shower area", "accent wall".
  final String label;

  final double totalLengthM;
  final double totalWidthM;

  const PartialArea({
    required this.label,
    required this.totalLengthM,
    required this.totalWidthM,
  });

  double get totalFloorSqm => totalLengthM * totalWidthM;

  Map<String, dynamic> toMap() => {
        'label': label,
        'totalLengthM': totalLengthM,
        'totalWidthM': totalWidthM,
      };

  static PartialArea? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final length = _asDouble(map['totalLengthM']);
    final width = _asDouble(map['totalWidthM']);
    if (length <= 0 || width <= 0) return null;
    return PartialArea(
      label: (map['label'] ?? '').toString().trim(),
      totalLengthM: length,
      totalWidthM: width,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartialArea &&
          label == other.label &&
          totalLengthM == other.totalLengthM &&
          totalWidthM == other.totalWidthM);

  @override
  int get hashCode => Object.hash(label, totalLengthM, totalWidthM);
}

/// The measurements a builder enters for one room.
class SiteDetails {
  final RoomJob job;
  final double lengthM;
  final double widthM;

  /// Floor to ceiling. Ignored for a floor-only job.
  final double heightM;

  final List<Opening> doors;
  final List<Opening> windows;
  final WallTileHeight wallTileHeight;

  /// Counter length the backsplash runs along. Kitchens only.
  final double counterLengthM;

  /// Old floor tiles are hacked off, so the floor needs a new screed.
  final bool removeOldTiles;

  final bool paintCeiling;

  /// Set when the job covers one part of a bigger space. The measurements
  /// above describe the part; this says what the part is and how big the whole
  /// space is. Null for a job that covers the whole space.
  final PartialArea? partial;

  const SiteDetails({
    required this.job,
    required this.lengthM,
    required this.widthM,
    required this.heightM,
    this.doors = const [],
    this.windows = const [],
    this.wallTileHeight = WallTileHeight.none,
    this.counterLengthM = 0,
    this.removeOldTiles = false,
    this.partial,
    this.paintCeiling = false,
  });

  /// Starting values for the form. Length and width stay empty on purpose:
  /// a pre-filled room size is too easy to accept without measuring.
  factory SiteDetails.defaultsFor(RoomJob job) {
    return switch (job) {
      RoomJob.wetRoom => SiteDetails(
          job: job,
          lengthM: 0,
          widthM: 0,
          heightM: job.typicalHeightM,
          doors: [kDoorSizes[0]],
          windows: [kWindowSizes[0]],
          wallTileHeight: WallTileHeight.full,
          paintCeiling: true,
        ),
      RoomJob.kitchen => SiteDetails(
          job: job,
          lengthM: 0,
          widthM: 0,
          heightM: job.typicalHeightM,
          doors: [kDoorSizes[1]],
          windows: [kWindowSizes[1]],
          wallTileHeight: WallTileHeight.backsplash,
          paintCeiling: true,
        ),
      RoomJob.dryRoom || RoomJob.wallsOnly => SiteDetails(
          job: job,
          lengthM: 0,
          widthM: 0,
          heightM: job.typicalHeightM,
          doors: [kDoorSizes[1]],
          windows: [kWindowSizes[2]],
          paintCeiling: true,
        ),
      RoomJob.floorOnly => SiteDetails(
          job: job,
          lengthM: 0,
          widthM: 0,
          heightM: job.typicalHeightM,
          doors: [kDoorSizes[1]],
        ),
    };
  }

  SiteDetails copyWith({
    double? lengthM,
    double? widthM,
    double? heightM,
    List<Opening>? doors,
    List<Opening>? windows,
    WallTileHeight? wallTileHeight,
    double? counterLengthM,
    bool? removeOldTiles,
    bool? paintCeiling,
    PartialArea? partial,
  }) {
    return SiteDetails(
      job: job,
      lengthM: lengthM ?? this.lengthM,
      widthM: widthM ?? this.widthM,
      heightM: heightM ?? this.heightM,
      doors: doors ?? this.doors,
      windows: windows ?? this.windows,
      wallTileHeight: wallTileHeight ?? this.wallTileHeight,
      counterLengthM: counterLengthM ?? this.counterLengthM,
      removeOldTiles: removeOldTiles ?? this.removeOldTiles,
      paintCeiling: paintCeiling ?? this.paintCeiling,
      partial: partial ?? this.partial,
    );
  }

  /// How much of the whole space this job covers, as a fraction, or `null`
  /// when it covers all of it.
  ///
  /// Shown to the builder as context only. No quantity is ever a percentage of
  /// another: every material is sized from the surface it actually covers,
  /// which for a partial job is the part that was measured.
  double? get portionOfSpace {
    final whole = partial;
    if (whole == null || whole.totalFloorSqm <= 0) return null;
    return (lengthM * widthM) / whole.totalFloorSqm;
  }

  /// Problems that stop an estimate. Empty when the details can be used.
  List<String> problems() {
    final out = <String>[];
    if (lengthM < 0.5 || lengthM > 30) {
      out.add('Enter a room length between 0.5 and 30 m.');
    }
    if (widthM < 0.5 || widthM > 30) {
      out.add('Enter a room width between 0.5 and 30 m.');
    }
    if (job.hasWalls && (heightM < 2.0 || heightM > 6.0)) {
      out.add('Enter a ceiling height between 2.0 and 6.0 m.');
    }
    final whole = partial;
    if (whole != null) {
      if (whole.label.trim().isEmpty) {
        out.add('Name the part being worked on, such as "shower area".');
      }
      if (whole.totalLengthM < 0.5 || whole.totalLengthM > 30) {
        out.add('Enter a total length between 0.5 and 30 m for the whole space.');
      }
      if (whole.totalWidthM < 0.5 || whole.totalWidthM > 30) {
        out.add('Enter a total width between 0.5 and 30 m for the whole space.');
      }
      // A part bigger than the space it sits in means one of the two was
      // mistyped, and the quantities would be sized from the wrong one.
      if (out.isEmpty && lengthM * widthM > whole.totalFloorSqm + 0.01) {
        out.add(
          'The part (${(lengthM * widthM).toStringAsFixed(2)} sq.m) cannot be '
          'bigger than the whole space '
          '(${whole.totalFloorSqm.toStringAsFixed(2)} sq.m).',
        );
      }
    }
    if (out.isNotEmpty) return out;

    final takeoff = SiteTakeoff.from(this);
    if (job.hasWalls && takeoff.openingsSqm >= takeoff.grossWallSqm) {
      out.add('The doors and windows are larger than the walls. Check their sizes and counts.');
    }
    if (job == RoomJob.kitchen &&
        wallTileHeight == WallTileHeight.backsplash &&
        (counterLengthM <= 0 || counterLengthM > takeoff.perimeterM)) {
      out.add('Enter a counter length between 0 and ${takeoff.perimeterM.toStringAsFixed(1)} m for the backsplash.');
    }
    return out;
  }

  /// Unusual but possible values the builder should double-check.
  List<String> warnings() {
    final out = <String>[];
    final floor = lengthM * widthM;
    if (job == RoomJob.wetRoom && floor > 15) {
      out.add('${floor.toStringAsFixed(1)} sq.m is large for a bathroom or laundry.');
    }
    if (job.hasWalls && doors.every((d) => d.count <= 0)) {
      out.add('No door entered. Most rooms have at least one.');
    }
    return out;
  }

  Map<String, dynamic> toMap() => {
        'job': job.name,
        'lengthM': lengthM,
        'widthM': widthM,
        'heightM': heightM,
        'doors': doors.map((d) => d.toMap()).toList(),
        'windows': windows.map((w) => w.toMap()).toList(),
        'wallTileHeight': wallTileHeight.name,
        'counterLengthM': counterLengthM,
        'removeOldTiles': removeOldTiles,
        'paintCeiling': paintCeiling,
        if (partial != null) 'partial': partial!.toMap(),
      };

  static SiteDetails? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final job = RoomJob.values.where((j) => j.name == map['job']).firstOrNull;
    if (job == null) return null;
    List<Opening> openings(Object? raw) => raw is List
        ? raw
            .whereType<Map>()
            .map((e) => Opening.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : const [];
    return SiteDetails(
      job: job,
      lengthM: _asDouble(map['lengthM']),
      widthM: _asDouble(map['widthM']),
      heightM: _asDouble(map['heightM']),
      doors: openings(map['doors']),
      windows: openings(map['windows']),
      wallTileHeight: WallTileHeight.values
              .where((h) => h.name == map['wallTileHeight'])
              .firstOrNull ??
          WallTileHeight.none,
      counterLengthM: _asDouble(map['counterLengthM']),
      removeOldTiles: map['removeOldTiles'] == true,
      paintCeiling: map['paintCeiling'] == true,
      partial: PartialArea.fromMap(
        map['partial'] is Map
            ? Map<String, dynamic>.from(map['partial'] as Map)
            : null,
      ),
    );
  }
}

/// The surfaces a room's materials are sized from, worked out from its
/// [SiteDetails].
///
/// Every figure keeps the arithmetic that produced it, so the formula on each
/// material can show the builder exactly where a quantity came from.
class SiteTakeoff {
  final SiteDetails details;
  final double floorSqm;
  final double perimeterM;
  final double grossWallSqm;
  final double openingsSqm;
  final double netWallSqm;
  final double wallTileSqm;
  final double paintWallSqm;
  final double ceilingSqm;
  final double skirtingM;
  final double waterproofingSqm;

  const SiteTakeoff._({
    required this.details,
    required this.floorSqm,
    required this.perimeterM,
    required this.grossWallSqm,
    required this.openingsSqm,
    required this.netWallSqm,
    required this.wallTileSqm,
    required this.paintWallSqm,
    required this.ceilingSqm,
    required this.skirtingM,
    required this.waterproofingSqm,
  });

  RoomJob get job => details.job;
  double get paintSqm => _r(paintWallSqm + ceilingSqm);

  /// Counter top: the counter's length at a standard 0.60 m depth.
  double get countertopSqm =>
      _r(math.max(0.0, details.counterLengthM) * kCountertopDepthM);

  /// The rules, in one place:
  /// - walls are the room's perimeter times its height, less every door and
  ///   window;
  /// - half-wall tiling assumes windows start above the tile line, which is
  ///   where bathroom and laundry windows sit, so only doorways are taken out
  ///   of it;
  /// - paint covers the walls the tiles do not, plus the ceiling if chosen;
  /// - skirting runs round the room except across doorways;
  /// - a wet room's waterproofing covers the floor and turns 0.30 m up the
  ///   walls.
  factory SiteTakeoff.from(SiteDetails d) {
    final length = math.max(0.0, d.lengthM);
    final width = math.max(0.0, d.widthM);
    final height = math.max(0.0, d.heightM);
    final job = d.job;

    final floor = length * width;
    final perimeter = 2 * (length + width);

    double openingArea(List<Opening> list) => list.fold(
          0.0,
          (sum, o) =>
              sum + o.widthM * math.min(o.heightM, height) * math.max(0, o.count),
        );
    double doorwayWidth() => d.doors.fold(
          0.0,
          (sum, o) => sum + o.widthM * math.max(0, o.count),
        );

    final gross = job.hasWalls ? perimeter * height : 0.0;
    final openings =
        job.hasWalls ? openingArea(d.doors) + openingArea(d.windows) : 0.0;
    final net = math.max(0.0, gross - openings);

    var wallTile = 0.0;
    if (job.offersWallTiles) {
      switch (d.wallTileHeight) {
        case WallTileHeight.none:
          wallTile = 0;
        case WallTileHeight.backsplash:
          wallTile = math.max(0.0, d.counterLengthM) * kBacksplashHeightM;
        case WallTileHeight.wainscot:
          final tileLine = math.min(kWainscotHeightM, height);
          final doorways = d.doors.fold(
            0.0,
            (sum, o) =>
                sum + o.widthM * math.min(o.heightM, tileLine) * math.max(0, o.count),
          );
          wallTile = math.max(0.0, perimeter * tileLine - doorways);
        case WallTileHeight.full:
          wallTile = net;
      }
      wallTile = math.min(wallTile, net);
    }

    final paintWall = job.hasWalls ? math.max(0.0, net - wallTile) : 0.0;
    final ceiling = job.hasWalls && d.paintCeiling ? floor : 0.0;
    // Measured for every floor, so a skirting line on any template is sized
    // from the room. The summary mentions it only where skirting is usual.
    final skirting =
        job.hasFloor ? math.max(0.0, perimeter - doorwayWidth()) : 0.0;
    final waterproofing =
        job.hasWaterproofing ? floor + perimeter * kWaterproofUpturnM : 0.0;

    return SiteTakeoff._(
      details: d,
      floorSqm: _r(floor),
      perimeterM: _r(perimeter),
      grossWallSqm: _r(gross),
      openingsSqm: _r(openings),
      netWallSqm: _r(net),
      wallTileSqm: _r(wallTile),
      paintWallSqm: _r(paintWall),
      ceilingSqm: _r(ceiling),
      skirtingM: _r(skirting),
      waterproofingSqm: _r(waterproofing),
    );
  }

  static double _r(double v) => (v * 100).round() / 100;
  static String _m(double v) => v.toStringAsFixed(2);
  static String _sq(double v) => v.toStringAsFixed(1);

  String get floorLine =>
      'Floor: ${_m(details.lengthM)} × ${_m(details.widthM)} m = ${_sq(floorSqm)} sq.m'
      '$_partialSuffix';

  /// Names the part a partial job covers, so a measured 2 sq.m is never read
  /// as the whole room.
  String get _partialSuffix {
    final whole = details.partial;
    if (whole == null) return '';
    final name = whole.label.trim().isEmpty ? 'this part' : whole.label.trim();
    return ' ($name, within ${_m(whole.totalLengthM)} × '
        '${_m(whole.totalWidthM)} m = ${_sq(whole.totalFloorSqm)} sq.m)';
  }

  String get wallLine =>
      'Walls: ${_m(perimeterM)} m around × ${_m(details.heightM)} m = ${_sq(grossWallSqm)} sq.m, '
      'less ${_sq(openingsSqm)} sq.m of doors and windows = ${_sq(netWallSqm)} sq.m';

  String get wallTileLine => switch (details.wallTileHeight) {
        WallTileHeight.none => 'Wall tiles: none',
        WallTileHeight.backsplash =>
          'Backsplash: ${_m(details.counterLengthM)} m of counter × ${_m(kBacksplashHeightM)} m = ${_sq(wallTileSqm)} sq.m',
        WallTileHeight.wainscot =>
          'Half-wall tiles: ${_m(perimeterM)} m around × ${_m(kWainscotHeightM)} m, less doorways = ${_sq(wallTileSqm)} sq.m',
        WallTileHeight.full => 'Full-height tiles: $wallLine',
      };

  String get paintLine {
    final parts = <String>['${_sq(paintWallSqm)} sq.m of wall'];
    if (ceilingSqm > 0) parts.add('${_sq(ceilingSqm)} sq.m of ceiling');
    return 'Paint: ${parts.join(' + ')} = ${_sq(paintSqm)} sq.m';
  }

  String get skirtingLine {
    final doorways = _r(perimeterM - skirtingM);
    return 'Skirting: ${_m(perimeterM)} m around, less ${_m(doorways)} m of doorways = ${_m(skirtingM)} m';
  }

  String get countertopLine =>
      'Countertop: ${_m(details.counterLengthM)} m of counter × ${_m(kCountertopDepthM)} m deep = ${_sq(countertopSqm)} sq.m';

  String get waterproofingLine =>
      'Waterproofing: ${_sq(floorSqm)} sq.m floor + ${_m(perimeterM)} m × ${_m(kWaterproofUpturnM)} m upturn = ${_sq(waterproofingSqm)} sq.m';

  /// One line for the top of the materials list.
  String get summary {
    final parts = <String>[];
    if (job.hasFloor) parts.add('floor ${_sq(floorSqm)} sq.m');
    if (job.hasWalls) parts.add('walls ${_sq(netWallSqm)} sq.m');
    if (wallTileSqm > 0) parts.add('wall tiles ${_sq(wallTileSqm)} sq.m');
    if (paintSqm > 0) parts.add('paint ${_sq(paintSqm)} sq.m');
    if (job.hasSkirting && skirtingM > 0) {
      parts.add('skirting ${_m(skirtingM)} m');
    }
    final text = parts.join(' · ');
    return text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
  }
}
