import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

const _area = 20.0;

const _structuralKinds = [
  MaterialKind.structuralCement,
  MaterialKind.gravel,
  MaterialKind.chbBlock,
  MaterialKind.chbMortar,
  MaterialKind.rebar,
  MaterialKind.tieWire,
];

bool _kind(RenovationTemplateItem item, MaterialKind kind) =>
    classifyMaterial(item) == kind;

/// A washed sand line whose name or category names the job, e.g. 'slab'.
bool _sandFor(RenovationTemplateItem item, String job) =>
    _kind(item, MaterialKind.washedSand) &&
    '${item.name} ${item.category}'.toLowerCase().contains(job);

Iterable<String> _types() => {
      ...RenovationTemplatesCatalog.allTemplates.map((t) => t.renovationType),
      'Living Room Renovation',
    };

List<RenovationTemplateItem> _bom(
  RenovationTemplate template,
  RenovationScope scope,
) =>
    BomQuantityEstimator.scaleTemplate(
      template: template,
      areaSqm: _area,
      scope: scope,
    );

RenovationTemplate _template(String type, String style) =>
    RenovationTemplatesCatalog.threeForType(type)
        .firstWhere((t) => t.style == style);

void main() {
  test('an extension BOM carries the slab and CHB wall package', () {
    final items = _bom(
        _template('Bathroom Renovation', 'modern'), RenovationScope.extension);
    double qty(bool Function(RenovationTemplateItem) match) =>
        items.where(match).single.defaultQuantity;

    // 100 mm slab over 20 sq.m = 2.0 m3 of Class A 1:2:4 concrete.
    expect(qty((i) => _kind(i, MaterialKind.structuralCement)), 18);
    expect(qty((i) => _sandFor(i, 'slab')), 1.0);
    expect(qty((i) => _kind(i, MaterialKind.gravel)), 2.0);

    // Walls at 2.2 x 20 = 44 sq.m of 4" CHB, mortared and plastered both faces.
    expect(qty((i) => _kind(i, MaterialKind.chbBlock)), 578);
    expect(qty((i) => _kind(i, MaterialKind.chbMortar)), 40);
    expect(qty((i) => _sandFor(i, 'plaster')), 3.34);
    expect(qty((i) => _kind(i, MaterialKind.rebar)), 33);
    expect(qty((i) => _kind(i, MaterialKind.tieWire)), 1.1);

    expect(items.where((i) => _kind(i, MaterialKind.formworkPlywood)),
        hasLength(1));
  });

  test('every extension BOM has exactly one of each structural line', () {
    for (final type in _types()) {
      for (final template in RenovationTemplatesCatalog.threeForType(type)) {
        final items = _bom(template, RenovationScope.extension);
        final reason = template.id;
        for (final kind in _structuralKinds) {
          expect(items.where((i) => _kind(i, kind)), hasLength(1),
              reason: '$reason ${kind.name}');
        }
        expect(items.where((i) => _sandFor(i, 'slab')), hasLength(1),
            reason: '$reason slab sand');
        expect(items.where((i) => _sandFor(i, 'plaster')), hasLength(1),
            reason: '$reason masonry sand');
      }
    }
  });

  test('a full renovation carries no structural lines', () {
    for (final type in _types()) {
      for (final template in RenovationTemplatesCatalog.threeForType(type)) {
        final items = _bom(template, RenovationScope.fullRenovation);
        expect(
          items.where((i) => kStructuralOnlyKinds.contains(classifyMaterial(i))),
          isEmpty,
          reason: template.id,
        );
        expect(
          items.where((i) => _sandFor(i, 'slab') || _sandFor(i, 'plaster')),
          isEmpty,
          reason: template.id,
        );
      }
    }
  });

  test('a tile bedding sand line keeps its own small rate', () {
    // The fallback template's "Washed Sand" (Masonry) is screed sand, not wall
    // plaster sand: 20 sq.m x 0.025 = 0.5 cu.m.
    final items = _bom(_template('Living Room Renovation', 'modern'),
        RenovationScope.fullRenovation);
    expect(
      items.where((i) => i.name == 'Washed Sand').single.defaultQuantity,
      0.5,
    );
  });

  test('the AI consultation BOM adds no structural lines of its own', () {
    final template = BomQuantityEstimator.buildConsultationTemplate(
      projectType: 'Bedroom Renovation',
      style: 'modern',
      areaSqm: _area,
      materialNames: const ['Ceramic floor tiles'],
      scope: RenovationScope.extension,
    );
    expect(
      template.items
          .where((i) => kStructuralOnlyKinds.contains(classifyMaterial(i))),
      isEmpty,
    );
  });

  test('structural formulas state what they were sized from', () {
    final items = _bom(
        _template('Bathroom Renovation', 'modern'), RenovationScope.extension);
    String formula(bool Function(RenovationTemplateItem) match) {
      final item = items.firstWhere(match);
      return BomQuantityEstimator.getFormulaString(
        item: item,
        areaSqm: _area,
        currentQty: item.defaultQuantity,
        bom: items,
      );
    }

    expect(formula((i) => _sandFor(i, 'slab')), contains('Item 900'));
    expect(formula((i) => _sandFor(i, 'plaster')), contains('44.0 sq.m wall'));
    expect(formula((i) => _kind(i, MaterialKind.gravel)), contains('2.00 m³'));
    expect(formula((i) => _kind(i, MaterialKind.tieWire)),
        contains('44.0 sq.m wall'));
  });

  test('the extension scope no longer promises a roof', () {
    expect(RenovationScope.extension.description.toLowerCase(),
        isNot(contains('roof')));
    expect(BomQuantityEstimator.extensionCoverageNote.toLowerCase(),
        contains('roof'));
  });
}
