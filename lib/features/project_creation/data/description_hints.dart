import 'package:iconstruct/features/project_creation/data/site_details.dart';

/// What a builder's own description says about the room's finishes.
///
/// The describe screen used to be a dead end on the template path: a builder
/// typing "no wall tiles, repaint the ceiling" got the standard template and
/// no sign the app had read a word of it. These are the few decisions the
/// measuring step already asks for, so they can be set from the description
/// and shown back as "set from what you wrote" — still editable, because a
/// keyword is a guess and the builder is not.
class SiteHints {
  /// How far tiles go up the wall, when the description says.
  final WallTileHeight? wallTileHeight;

  /// Whether the old floor tiles are coming off.
  final bool? removeOldTiles;

  /// Whether the ceiling is being painted.
  final bool? paintCeiling;

  /// What was picked up, in the builder's terms, for showing back to them.
  final List<String> applied;

  const SiteHints({
    this.wallTileHeight,
    this.removeOldTiles,
    this.paintCeiling,
    this.applied = const [],
  });

  static const SiteHints none = SiteHints();

  bool get isEmpty => applied.isEmpty;
}

bool _has(String text, List<String> phrases) =>
    phrases.any((phrase) => text.contains(phrase));

/// Reads the finishes a description asks for.
///
/// Deliberately literal: it matches phrases a builder would actually type, in
/// English and the Taglish that shows up in the field, and stays silent when
/// it is not sure. A wrong guess costs more than no guess, because the builder
/// has to notice it and undo it.
SiteHints parseSiteHints(String description) {
  final text = description.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (text.trim().isEmpty) return SiteHints.none;

  WallTileHeight? tiles;
  bool? removeOldTiles;
  bool? paintCeiling;
  final applied = <String>[];

  // Negations first: "no wall tiles" contains "wall tiles".
  if (_has(text, [
    'no wall tile',
    'without wall tile',
    'no tiles on the wall',
    'walang wall tile',
    'walang tiles sa dingding',
    'no wall tiling',
  ])) {
    tiles = WallTileHeight.none;
    applied.add('no wall tiles');
  } else if (_has(text, [
    'backsplash',
    'splashback',
    'tiles above the counter',
  ])) {
    tiles = WallTileHeight.backsplash;
    applied.add('backsplash only');
  } else if (_has(text, [
    'half wall',
    'half-wall',
    'wainscot',
    'half height',
    'half-height',
    'kalahating dingding',
  ])) {
    tiles = WallTileHeight.wainscot;
    applied.add('half-wall tiles');
  } else if (_has(text, [
    'full height tile',
    'full-height tile',
    'floor to ceiling',
    'up to the ceiling',
    'hanggang kisame',
    'tiles all the way up',
  ])) {
    tiles = WallTileHeight.full;
    applied.add('full-height wall tiles');
  }

  if (_has(text, [
    'keep the old tile',
    'keep existing tile',
    'tile over',
    'over the old tile',
  ])) {
    removeOldTiles = false;
    applied.add('keeping the old floor tiles');
  } else if (_has(text, [
    'remove the old tile',
    'remove old tile',
    'replace the old tile',
    'replace old tile',
    'hack the tile',
    'hacking',
    'tanggalin ang tile',
    'palitan ang tile',
    'strip the floor',
  ])) {
    removeOldTiles = true;
    applied.add('old floor tiles removed');
  }

  if (_has(text, [
    'no ceiling paint',
    "don't paint the ceiling",
    'do not paint the ceiling',
    'huwag pinturahan ang kisame',
  ])) {
    paintCeiling = false;
    applied.add('ceiling left unpainted');
  } else if (_has(text, [
    'paint the ceiling',
    'repaint the ceiling',
    'ceiling paint',
    'ceiling repaint',
    'pinturahan ang kisame',
    'kisame',
  ])) {
    paintCeiling = true;
    applied.add('ceiling painted');
  }

  return SiteHints(
    wallTileHeight: tiles,
    removeOldTiles: removeOldTiles,
    paintCeiling: paintCeiling,
    applied: applied,
  );
}
