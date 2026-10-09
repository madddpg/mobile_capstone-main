// An independent audit of every quantity the estimator can produce.
//
// Every project's work items and packages are run, as the measuring screen
// runs them, through rooms of many sizes: odd centimetre measurements, half
// jobs, wainscot and full-height tiles, ceilings painted or not, old tiles
// removed or not, counters and device counts. Each material line is then
// computed again here, by hand-computation rules written out separately from
// the app and in exact fractions, with no floating point anywhere, and
// compared with the app.
//
// The "View Formula" text of every line is checked too: it must arrive at
// the quantity on the line, and every "= X → Y" step in it must be X rounded
// up, so a panel member following the working by hand gets the same number.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/functional_counts.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/ph_renovation_rates.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';

// ── Exact arithmetic ─────────────────────────────────────────────────────

/// A rational number. Every measurement and rate is a decimal, so every
/// figure here is exact.
class Q implements Comparable<Q> {
  final BigInt n;
  final BigInt d;

  const Q._(this.n, this.d);

  factory Q(BigInt n, [BigInt? d]) {
    var den = d ?? BigInt.one;
    var num = n;
    if (den.isNegative) {
      num = -num;
      den = -den;
    }
    final g = num.gcd(den);
    return g == BigInt.zero ? Q._(BigInt.zero, BigInt.one) : Q._(num ~/ g, den ~/ g);
  }

  static Q i(int v) => Q(BigInt.from(v));

  /// "2.35" → 235/100. A double prints its shortest decimal, which is the
  /// decimal it was written as: 0.8, 0.32, 1.1.
  static Q of(Object decimal) {
    final text = decimal.toString().trim();
    final dot = text.indexOf('.');
    if (dot < 0) return Q(BigInt.parse(text));
    final digits = text.length - dot - 1;
    return Q(BigInt.parse(text.replaceFirst('.', '')), BigInt.from(10).pow(digits));
  }

  Q operator +(Q o) => Q(n * o.d + o.n * d, d * o.d);
  Q operator -(Q o) => Q(n * o.d - o.n * d, d * o.d);
  Q operator *(Q o) => Q(n * o.n, d * o.d);
  Q operator /(Q o) => Q(n * o.d, d * o.n);

  @override
  int compareTo(Q o) => (n * o.d).compareTo(o.n * d);
  bool operator >(Q o) => compareTo(o) > 0;
  bool operator <(Q o) => compareTo(o) < 0;

  Q max(Q o) => compareTo(o) >= 0 ? this : o;
  Q min(Q o) => compareTo(o) <= 0 ? this : o;

  /// Rounded up to a whole unit.
  Q ceil() {
    final whole = n ~/ d;
    return Q(n.remainder(d) == BigInt.zero || n.isNegative ? whole : whole + BigInt.one);
  }

  /// Rounded up to 0.01.
  Q ceil100() => (this * Q.i(100)).ceil() / Q.i(100);

  double toDouble() => n.toDouble() / d.toDouble();

  @override
  String toString() => '${toDouble()}';
}

final _zero = Q.i(0);
final _one = Q.i(1);
final _waste = Q.of('1.08');

// ── The room, measured by hand ───────────────────────────────────────────

/// The surfaces of a room, by the rules in docs/material-data-sources.md.
class _HandTakeoff {
  final Q floor, perimeter, net, wallTile, paint, skirting, waterproofing,
      counter;

  _HandTakeoff._(this.floor, this.perimeter, this.net, this.wallTile,
      this.paint, this.skirting, this.waterproofing, this.counter);

  factory _HandTakeoff(_Room room, SiteDetails d) {
    final job = d.job;
    final h = job.hasWalls ? Q.of(room.height) : Q.of(job.typicalHeightM);
    // A room that is not a rectangle is walked wall by wall, and its floor is
    // the area worked out on site.
    final floor = room.floor != null
        ? Q.of(room.floor!)
        : Q.of(room.length) * Q.of(room.width);
    final perimeter = room.walls.isNotEmpty
        ? room.walls.fold(_zero, (sum, run) => sum + Q.of(run))
        : Q.i(2) * (Q.of(room.length) + Q.of(room.width));

    Q openings(List<Opening> list, Q cap) => list.fold(
        _zero,
        (sum, o) =>
            sum + Q.of(o.widthM) * Q.of(o.heightM).min(cap) * Q.i(o.count));

    final gross = job.hasWalls ? perimeter * h : _zero;
    final holes =
        job.hasWalls ? openings(d.doors, h) + openings(d.windows, h) : _zero;
    final net = (gross - holes).max(_zero);

    var tile = _zero;
    if (job.offersWallTiles) {
      tile = switch (d.wallTileHeight) {
        WallTileHeight.none => _zero,
        WallTileHeight.backsplash => Q.of(d.counterLengthM) * Q.of('0.60'),
        WallTileHeight.wainscot => (perimeter * Q.of('1.50').min(h) -
                openings(d.doors, Q.of('1.50').min(h)))
            .max(_zero),
        WallTileHeight.full => net,
      };
      tile = tile.min(net);
    }
    final paintWall = job.hasWalls ? (net - tile).max(_zero) : _zero;
    final ceiling = job.hasWalls && d.paintCeiling ? floor : _zero;
    final doorways =
        d.doors.fold(_zero, (sum, o) => sum + Q.of(o.widthM) * Q.i(o.count));
    final skirting = job.hasFloor ? (perimeter - doorways).max(_zero) : _zero;
    final wp = job.hasWaterproofing ? floor + perimeter * Q.of('0.30') : _zero;
    final counter = Q.of(d.counterLengthM) * Q.of('0.60');

    final half = d.half ? Q.of('0.5') : _one;
    return _HandTakeoff._(floor * half, perimeter * half, net * half,
        tile * half, (paintWall + ceiling) * half, skirting * half, wp * half,
        counter * half);
  }
}

// ── The hand rules ───────────────────────────────────────────────────────

class _Ctx {
  final Q area;
  final _HandTakeoff? t;
  final FunctionalCounts? counts;
  final List<RenovationTemplateItem> bom;

  _Ctx(this.area, this.t, this.counts, this.bom);

  Q get roof => area * Q.of('1.15');

  /// Ridge from a square plan, √area × 1.10, in whole metres. The square root
  /// is the one irrational step, so it alone is taken in floating point.
  Q get ridge => Q.i(
      (((math.sqrt(area.toDouble()) * 1.10) * 1e6).roundToDouble() / 1e6)
          .ceil());

  /// New wall for CHB: the measured net wall, else 2.2 × floor.
  Q get wall => t != null && t!.net > _zero ? t!.net : area * Q.of('2.2');

  /// Floor and wall tile, each with the grout its face takes.
  ({Q floor, Q wall, Q groutKg})? get tiled {
    final floorLine = bom
        .where((i) => classifyMaterial(i) == MaterialKind.floorTile)
        .firstOrNull;
    final wallLines =
        bom.where((i) => classifyMaterial(i) == MaterialKind.wallTile).toList();
    if (floorLine == null && wallLines.isEmpty) return null;
    var wallSqm = _zero;
    var kg = _zero;
    if (t != null) {
      if (wallLines.isNotEmpty) {
        wallSqm = t!.wallTile;
        kg = kg + wallSqm * _groutPerSqm(wallLines.first.size);
      }
    } else {
      for (final line in wallLines) {
        final sqm = _unmeasuredWallTile(line);
        wallSqm = wallSqm + sqm;
        kg = kg + sqm * _groutPerSqm(line.size);
      }
    }
    final floorSqm = floorLine == null ? _zero : area;
    if (floorLine != null) kg = kg + floorSqm * _groutPerSqm(floorLine.size);
    if (floorLine == null && wallSqm.compareTo(_zero) == 0) return null;
    return (floor: floorSqm, wall: wallSqm, groutKg: kg);
  }

  Q _unmeasuredWallTile(RenovationTemplateItem line) {
    final rate = line.qtyPerSqm;
    return area * (rate != null && rate > 0 ? Q.of(rate) : Q.of('2.2'));
  }
}

Q _groutPerSqm(String? size) => switch ((size ?? '').trim()) {
      '75x300' => Q.of('0.30'),
      '300x300' || '200x200' => Q.of('0.25'),
      '600x1200' => Q.of('0.12'),
      _ => Q.of('0.18'),
    };

/// Tile face in sq.m from "600x600" (millimetres).
Q _face(String? size, String fallback) {
  final m = RegExp(r'(\d+)\s*[x×X]\s*(\d+)').firstMatch(size ?? '') ??
      RegExp(r'(\d+)\s*[x×X]\s*(\d+)').firstMatch(fallback)!;
  return Q.i(int.parse(m.group(1)!)) /
      Q.i(1000) *
      (Q.i(int.parse(m.group(2)!)) / Q.i(1000));
}

Q _slabThickness(String? size) => switch ((size ?? '').trim()) {
      '125mm' => Q.of('0.125'),
      '150mm' => Q.of('0.15'),
      _ => Q.of('0.10'),
    };

bool _roofWork(RenovationTemplateItem i) =>
    '${i.name} ${i.category}'.toLowerCase().contains('roof');

/// The quantity a hand computation gives for [item].
Q _expected(RenovationTemplateItem item, _Ctx c) {
  final name = item.name.toLowerCase();
  final rate = item.qtyPerSqm;
  final t = c.t;
  final tiled = c.tiled;
  final paintArea = _roofWork(item) ? c.roof : (t?.paint ?? c.area);

  Q generic() {
    if (rate != null && rate > 0) {
      return (c.area * Q.of(rate) * _waste).ceil().max(_one);
    }
    return item.defaultQuantity <= 0 ? _one : Q.of(item.defaultQuantity);
  }

  switch (classifyMaterial(item)) {
    case MaterialKind.floorTile:
      return (c.area / _face(item.size, '600x600') * _waste).ceil();
    case MaterialKind.wallTile:
      final wallSqm = t != null ? t.wallTile : c._unmeasuredWallTile(item);
      return (wallSqm / _face(item.size, '300x600') * _waste).ceil();
    case MaterialKind.tileAdhesive:
      final sqm = tiled == null ? c.area : tiled.floor + tiled.wall;
      return (sqm / Q.of('4.5')).ceil().max(_one);
    case MaterialKind.tileGrout:
      final kg = tiled == null
          ? c.area * _groutPerSqm(item.size)
          : tiled.groutKg;
      return (kg / Q.i(2)).ceil().max(_one);
    case MaterialKind.paintPrimer:
      return (paintArea * Q.of('0.04')).ceil().max(_one);
    case MaterialKind.paintTopcoat:
      return (paintArea * Q.of('0.06')).ceil().max(_one);
    case MaterialKind.skimCoat:
      return (paintArea / Q.i(10)).ceil().max(_one);
    case MaterialKind.waterproofing
        when t != null && t.waterproofing > _zero && (rate ?? 0) > 0:
      return (t.waterproofing * Q.of(rate!) * _waste).ceil().max(_one);
    case MaterialKind.areaGoods
        when t != null &&
            (name.contains('countertop') || name.contains('counter top')) &&
            t.counter > _zero:
      return (t.counter * _waste).ceil().max(_one);
    case MaterialKind.genericConsumable
        when t != null && name.contains('skirting') && t.skirting > _zero:
      return (t.skirting * Q.of('1.05')).ceil().max(_one);
    case MaterialKind.genericConsumable
        when name.contains('tekscrew') || name.contains('tek screw'):
      return (c.roof * Q.i(8)).ceil();
    case MaterialKind.structuralCement:
      return (c.area * _slabThickness(item.size) * Q.i(9)).ceil().max(_one);
    case MaterialKind.roofingSheet:
      final linear = {'ln.m', 'lm', 'l.m', 'm', 'linear m'}
          .contains(item.unit.toLowerCase().trim());
      if (name.contains('ridge')) {
        if (name.contains('tile')) return (c.ridge * Q.i(3)).ceil();
        if (linear) return c.ridge;
        return generic();
      }
      if (name.contains('roof tile') || name.contains('roofing tile')) {
        return (c.roof * Q.of('10.5') * Q.of('1.05')).ceil();
      }
      return linear ? (c.roof * Q.of('1.10')).ceil() : generic();
    case MaterialKind.roofSealant:
      return (c.roof / Q.i(15)).ceil().max(_one);
    case MaterialKind.cementBedding when name.contains('ridge'):
      return (c.ridge / Q.i(6)).ceil().max(_one);
    case MaterialKind.cementBedding:
      return (c.area * Q.of('0.025') * Q.i(12)).ceil().max(_one);
    case MaterialKind.chbMortar:
      final six = (item.size ?? '').contains('6');
      return (c.wall * Q.of(six ? '1.40' : '0.90')).ceil().max(_one);
    case MaterialKind.washedSand:
      final text = '${item.name} ${item.category}'.toLowerCase();
      if (text.contains('slab') || text.contains('concrete')) {
        return (c.area * _slabThickness(item.size) * Q.of('0.50')).ceil100();
      }
      if (text.contains('plaster') ||
          text.contains('mortar') ||
          text.contains('chb')) {
        final six = (item.size ?? '').contains('6');
        return (c.wall * Q.of(six ? '0.116' : '0.076')).ceil100();
      }
      return (c.area * Q.of('0.025')).ceil100();
    case MaterialKind.gravel:
      return (c.area * _slabThickness(item.size)).ceil100();
    case MaterialKind.chbBlock:
      return (c.wall * Q.of('12.5') * Q.of('1.05')).ceil();
    case MaterialKind.rebar:
      return (c.wall * Q.of('4.28') * Q.of('1.05') / Q.i(6)).ceil().max(_one);
    case MaterialKind.tieWire:
      return (c.wall * Q.of('0.025')).ceil100();
    case MaterialKind.electrical when c.counts != null:
      final k = c.counts!;
      final outletRun = Q.i(k.outlets) * Q.of('3.0');
      final lightingRun = Q.i(k.switches + k.lights) * Q.of('2.5');
      if (name.contains('convenience outlet')) return Q.i(k.outlets);
      if (item.category.toLowerCase().contains('wiring devices') &&
          name.contains('switch')) {
        return Q.i(k.switches);
      }
      if (item.category.toLowerCase() == 'lighting' && name.contains('light')) {
        return Q.i(k.lights);
      }
      if (name.contains('utility box')) return Q.i(k.deviceCount);
      if (name.contains('3.5 mm')) return (outletRun * _waste).ceil();
      if (name.contains('2.0 mm')) return (lightingRun * _waste).ceil();
      if (name.contains('5.5 mm')) return (Q.of('8.0') * _waste).ceil();
      if (name.contains('conduit') || name.contains('coupling')) {
        return ((outletRun + lightingRun) / Q.i(3)).ceil();
      }
      return generic();
    default:
      if (_roofWork(item) &&
          item.category.toLowerCase().contains('drainage')) {
        final gutter = c.ridge * Q.i(2);
        final downspouts = (gutter / Q.i(9)).ceil().max(Q.i(2));
        if (name.contains('bracket')) return (gutter / Q.of('0.60')).ceil();
        if (name.contains('gutter')) return (gutter / Q.i(3)).ceil();
        if (name.contains('downspout')) {
          return name.contains('elbow') ? downspouts * Q.i(2) : downspouts;
        }
      }
      if (name.contains('spacer') && tiled != null) {
        final perSqm = (rate ?? 0) > 0 ? Q.of(rate!) : Q.of('0.10');
        return ((tiled.floor + tiled.wall) * perSqm * _waste).ceil().max(_one);
      }
      return generic();
  }
}

// ── The rooms and the jobs ───────────────────────────────────────────────

class _Room {
  final String length, width, height;

  /// An irregular room's measured floor and its walls, walked in turn.
  final String? floor;
  final List<String> walls;

  const _Room(this.length, this.width, this.height)
      : floor = null,
        walls = const [];

  const _Room.irregular(String this.floor, this.walls, this.height)
      : length = '0',
        width = '0';

  @override
  String toString() => floor == null
      ? '$length × $width × $height m'
      : '$floor sq.m irregular, walls ${walls.join('+')} m, $height m high';
}

const _lengths = ['1.0', '1.5', '2.0', '2.35', '3.0', '3.6', '4.25', '5.0'];
const _widths = ['1.0', '1.5', '1.85', '2.5', '3.0', '4.0'];
const _heights = ['2.4', '2.7', '3.0'];

final _rooms = [
  for (final l in _lengths)
    for (final w in _widths)
      for (final h in _heights) _Room(l, w, h),
  // L-shaped and odd rooms, entered wall by wall.
  const _Room.irregular(
      '14.5', ['4.0', '3.0', '1.5', '1.2', '2.5', '1.8'], '2.7'),
  const _Room.irregular(
      '9.75', ['3.5', '2.0', '1.25', '1.5', '2.25', '3.5'], '2.4'),
  const _Room.irregular(
      '22.08', ['5.2', '4.6', '2.0', '1.3', '3.2', '3.3'], '3.0'),
  const _Room.irregular('6.3', ['2.8', '2.25', '2.8', '2.25'], '2.4'),
];

/// Every selection a builder can reach: each piece of work alone, each
/// package, and everything ticked at once.
List<Set<String>> _selections(WorkCatalogue catalogue) => [
      for (final item in catalogue.items) {item.id},
      for (final package in catalogue.packages) package.itemIds.toSet(),
      {for (final item in catalogue.items) item.id},
    ];

/// The SiteDetails the measuring screen sends for this job.
SiteDetails _detailsFor({
  required RoomJob job,
  required RenovationTemplate template,
  required RenovationTypes types,
  required _Room room,
  required WallTileHeight tileHeight,
  required bool paintCeiling,
  required bool removeOldTiles,
  required String counter,
  required bool half,
}) {
  final defaults = SiteDetails.defaultsFor(job);
  bool asks(bool Function(RenovationTemplateItem) test) =>
      !template.isFromWorkItems || template.items.any(test);
  final asksWallTiles =
      asks((i) => classifyMaterial(i) == MaterialKind.wallTile);
  final asksFloor = asks((i) =>
      classifyMaterial(i) == MaterialKind.floorTile || isFloorFinishGoods(i));
  final asksPaint = asks((i) => kPaintKinds.contains(classifyMaterial(i)));
  final asksOpenings = asksWallTiles ||
      asksPaint ||
      asks((i) =>
          classifyMaterial(i) == MaterialKind.chbBlock ||
          i.name.toLowerCase().contains('skirting'));
  final finishes = types.changesFinishes;

  return SiteDetails(
    job: job,
    irregular: room.floor == null
        ? null
        : IrregularRoom(
            wallRunsM: [for (final run in room.walls) double.parse(run)],
            floorSqm: double.parse(room.floor!),
          ),
    lengthM: double.parse(room.length),
    widthM: double.parse(room.width),
    heightM: job.hasWalls ? double.parse(room.height) : job.typicalHeightM,
    doors: finishes && asksOpenings ? defaults.doors : const [],
    windows: finishes && asksOpenings && job.hasWalls
        ? defaults.windows
        : const [],
    wallTileHeight: finishes && job.offersWallTiles && asksWallTiles
        ? tileHeight
        : WallTileHeight.none,
    counterLengthM:
        finishes && job == RoomJob.kitchen ? double.parse(counter) : 0,
    removeOldTiles: finishes && job.hasFloor && asksFloor && removeOldTiles,
    paintCeiling: finishes && job.hasWalls && asksPaint && paintCeiling,
    half: half,
  );
}

// ── The checks on one line ───────────────────────────────────────────────

final _roundingStep = RegExp(r'= (\d+(?:\.\d+)?) → (\d+(?:\.\d+)?) ');

void _checkLine(
  RenovationTemplateItem item,
  _Ctx ctx,
  String formula,
  String where,
) {
  final expected = _expected(item, ctx);
  final qty = item.defaultQuantity;
  expect(qty, closeTo(expected.toDouble(), 1e-9),
      reason: '$where: ${item.name} ($qty ${item.unit}) should be $expected');

  // Whole units except sand, gravel and tie wire, which go to 0.01.
  final hundredths = ['cu.m', 'kg'].contains(item.unit) &&
      (classifyMaterial(item) == MaterialKind.washedSand ||
          classifyMaterial(item) == MaterialKind.gravel ||
          classifyMaterial(item) == MaterialKind.tieWire);
  final scaled = hundredths ? qty * 100 : qty;
  expect((scaled - scaled.roundToDouble()).abs(), lessThan(1e-9),
      reason: '$where: ${item.name} = $qty is not a whole order unit');
  expect(qty, greaterThan(0), reason: '$where: ${item.name}');

  // The working arrives at the quantity on the line...
  final shown = PhRenovationRates.numText(qty);
  expect(
    RegExp('(=|→|:) ${RegExp.escape(shown)} ').hasMatch('$formula '),
    isTrue,
    reason: '$where: ${item.name} = $shown, formula:\n$formula',
  );
  expect(formula, isNot(contains('standard rate')), reason: where);
  expect(formula, isNot(contains('You changed this line')), reason: where);

  // ...and every rounding step in it is a true round-up.
  for (final step in _roundingStep.allMatches(formula)) {
    final raw = Q.of(step.group(1)!);
    final rounded = Q.of(step.group(2)!);
    final up = step.group(2)!.contains('.') ? raw.ceil100() : raw.ceil();
    final atLeast = rounded.compareTo(up) == 0 ||
        // "→ 1": a quantity of at least one whole unit.
        (rounded.compareTo(_one) == 0 && up.compareTo(_one) < 0) ||
        formula.contains('raised to the minimum');
    expect(atLeast, isTrue,
        reason: '$where: ${item.name}: "${step.group(0)}" is not a round-up');
  }
}

// ── The audit ────────────────────────────────────────────────────────────

const _roomProjects = [
  'Bathroom Renovation',
  'Laundry Renovation',
  'Kitchen Renovation',
  'Living Room Renovation',
  'Bedroom Renovation',
  'Dining Room Renovation',
  'Floor Renovation',
  'Interior Painting',
  'Wall Finishing',
];

const _deviceCounts = [
  FunctionalCounts(outlets: 3, switches: 1, lights: 1),
  FunctionalCounts(outlets: 4, switches: 1, lights: 1),
  FunctionalCounts(outlets: 0, switches: 2, lights: 3),
  FunctionalCounts(outlets: 7, switches: 3, lights: 4),
];

void main() {
  for (final project in _roomProjects) {
    test('$project: every line in every room matches the hand computation',
        () {
      final catalogue = RenovationTemplatesCatalog.workCatalogueFor(project);
      final job = roomJobFor(project)!;
      var lines = 0;
      var variant = 0;

      for (final selection in _selections(catalogue)) {
        final template = catalogue.templateFor(selection);
        final types = catalogue.typesOf(selection);
        final wantsCounts = types.includesFunctional &&
            template.items
                .any((i) => classifyMaterial(i) == MaterialKind.electrical);

        for (final room in _rooms) {
          // Spread the options over the rooms so every combination of size
          // and option is reached without multiplying the run time.
          variant++;
          final tileHeight = job == RoomJob.kitchen
              ? (variant.isEven
                  ? WallTileHeight.backsplash
                  : WallTileHeight.full)
              : (variant % 3 == 0
                  ? WallTileHeight.wainscot
                  : WallTileHeight.full);
          final details = _detailsFor(
            job: job,
            template: template,
            types: types,
            room: room,
            tileHeight: tileHeight,
            paintCeiling: variant % 2 == 0,
            removeOldTiles: variant % 4 == 1,
            counter: const ['1.2', '2.4', '3.05'][variant % 3],
            half: variant % 5 == 0,
          );
          final takeoff = SiteTakeoff.from(details);
          if (takeoff.floorSqm <= 0) continue;
          final counts =
              wantsCounts ? _deviceCounts[variant % _deviceCounts.length] : null;

          final items = BomQuantityEstimator.scaleTemplate(
            template: template,
            areaSqm: takeoff.floorSqm,
            scope: types.primary,
            types: types,
            takeoff: takeoff,
            counts: counts,
          );
          final hand = _HandTakeoff(room, details);
          final ctx = _Ctx(hand.floor, hand, counts, items);
          final where = '$project ${selection.join('+')} in $room'
              '${details.half ? ' (half)' : ''}';

          // The app's own room figures agree with the hand takeoff.
          expect(takeoff.floorSqm, closeTo(hand.floor.toDouble(), 1e-9),
              reason: where);
          expect(takeoff.wallTileSqm, closeTo(hand.wallTile.toDouble(), 1e-9),
              reason: where);
          expect(takeoff.paintSqm, closeTo(hand.paint.toDouble(), 1e-9),
              reason: where);

          for (final item in items) {
            final formula = BomQuantityEstimator.getFormulaString(
              item: item,
              areaSqm: takeoff.floorSqm,
              currentQty: item.defaultQuantity,
              bom: items,
              takeoff: takeoff,
              counts: counts,
            );
            _checkLine(item, ctx, formula, where);
            lines++;
          }
        }
      }
      // ignore: avoid_print
      print('$project: $lines lines checked');
      expect(lines, greaterThan(1000));
    });
  }

  test('Roof Repair: every line at every area matches the hand computation',
      () {
    final catalogue = RenovationTemplatesCatalog.workCatalogueFor('Roof Repair');
    var lines = 0;
    for (final selection in _selections(catalogue)) {
      final template = catalogue.templateFor(selection);
      final types = catalogue.typesOf(selection);
      for (final entered in const [
        '1', '7.5', '12', '20', '23.75', '36', '48.6', '64', '81.25', '120',
        '150.5', '200', '350',
      ]) {
        for (final half in const [false, true]) {
          // The area screen halves the entered area for a half job.
          final area = Q.of(entered) * (half ? Q.of('0.5') : _one);
          final items = BomQuantityEstimator.scaleTemplate(
            template: template,
            areaSqm: area.toDouble(),
            scope: types.primary,
            types: types,
          );
          final ctx = _Ctx(area, null, null, items);
          final where = 'Roof ${selection.join('+')} at $area sq.m';
          for (final item in items) {
            final formula = BomQuantityEstimator.getFormulaString(
              item: item,
              areaSqm: area.toDouble(),
              currentQty: item.defaultQuantity,
              bom: items,
            );
            _checkLine(item, ctx, formula, where);
            lines++;
          }
        }
      }
    }
    // ignore: avoid_print
    print('Roof Repair: $lines lines checked');
    expect(lines, greaterThan(500));
  });

  group('the exact arithmetic itself', () {
    test('fractions round up as a hand computation does', () {
      expect((Q.of('3.0') / Q.of('0.36') * _waste).ceil().toDouble(), 9);
      expect((Q.of('14.97') / Q.of('0.18') * _waste).ceil().toDouble(), 90);
      expect(Q.of('0.075').ceil100().toDouble(), 0.08);
      expect(Q.of('0.07').ceil100().toDouble(), 0.07);
    });

    test('the app rounds the same way at the boundaries', () {
      // Whole on paper, a hair above it in floating point.
      expect(PhRenovationRates.calculateFloorTilePieces(3.0, '600x600'), 9);
      expect(PhRenovationRates.calculateFloorTilePieces(3.0, '300x300'), 36);
      expect(PhRenovationRates.roundUpHundredths(0.07), 0.07);
      expect(PhRenovationRates.roundUpHundredths(0.075), 0.08);
      expect(PhRenovationRates.roundUpHundredths(3.344), 3.35);
    });
  });
}
