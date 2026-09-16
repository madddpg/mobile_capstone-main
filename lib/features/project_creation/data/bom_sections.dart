import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

/// The group a line sits under on a room renovation's bill of materials.
///
/// A room renovation is floors and walls first, then what goes on or in them,
/// so the list reads the way a foreman walks the job.
enum BomSection { floor, walls, tileSetting, structure, fixtures, others }

extension BomSectionLabel on BomSection {
  String get label => switch (this) {
        BomSection.floor => 'Floor',
        BomSection.walls => 'Walls & ceiling',
        BomSection.tileSetting => 'Tile setting',
        BomSection.structure => 'Structure',
        BomSection.fixtures => 'Fixtures & fittings',
        BomSection.others => 'Other supplies',
      };
}

BomSection bomSectionOf(RenovationTemplateItem item) {
  final name = item.name.toLowerCase();
  final text = '$name ${item.category.toLowerCase()}';

  switch (classifyMaterial(item)) {
    case MaterialKind.floorTile:
    case MaterialKind.waterproofing:
      return BomSection.floor;
    case MaterialKind.areaGoods:
      return isFloorFinishGoods(item) || name.contains('underlayment')
          ? BomSection.floor
          : BomSection.fixtures;
    case MaterialKind.cementBedding:
      return BomSection.floor;
    case MaterialKind.washedSand:
      final structural = text.contains('slab') ||
          text.contains('concrete') ||
          text.contains('plaster') ||
          text.contains('mortar') ||
          text.contains('chb');
      return structural ? BomSection.structure : BomSection.floor;
    case MaterialKind.wallTile:
    case MaterialKind.paintPrimer:
    case MaterialKind.paintTopcoat:
    case MaterialKind.skimCoat:
      return BomSection.walls;
    case MaterialKind.tileAdhesive:
    case MaterialKind.tileGrout:
    case MaterialKind.tileSpacer:
      return BomSection.tileSetting;
    case MaterialKind.structuralCement:
    case MaterialKind.gravel:
    case MaterialKind.chbBlock:
    case MaterialKind.chbMortar:
    case MaterialKind.rebar:
    case MaterialKind.tieWire:
    case MaterialKind.formworkPlywood:
    case MaterialKind.formworkLumber:
    case MaterialKind.formworkNails:
    case MaterialKind.roofingSheet:
    case MaterialKind.roofPurlin:
    case MaterialKind.roofSealant:
      return BomSection.structure;
    case MaterialKind.plumbingFixture:
    case MaterialKind.plumbingConsumable:
    case MaterialKind.electrical:
      return BomSection.fixtures;
    case MaterialKind.genericConsumable:
      if (name.contains('skirting')) return BomSection.floor;
      if (text.contains('cabinet') || text.contains('shelf')) {
        return BomSection.fixtures;
      }
      return BomSection.others;
    case MaterialKind.unknown:
      return BomSection.others;
  }
}

/// [items] reordered by section, keeping each section's own order.
List<RenovationTemplateItem> sortBySection(List<RenovationTemplateItem> items) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final bySection =
        bomSectionOf(a.$2).index.compareTo(bomSectionOf(b.$2).index);
    return bySection != 0 ? bySection : a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}
