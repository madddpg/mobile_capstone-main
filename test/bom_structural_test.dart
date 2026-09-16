import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';

const _area = 20.0;

bool _kind(RenovationTemplateItem item, MaterialKind kind) =>
    classifyMaterial(item) == kind;

bool _structuralOnly(RenovationTemplateItem item) =>
    kStructuralOnlyKinds.contains(classifyMaterial(item));

/// A washed sand line whose name or category names the job, e.g. 'slab'.
bool _sandFor(RenovationTemplateItem item, String job) =>
    _kind(item, MaterialKind.washedSand) &&
    '${item.name} ${item.category}'.toLowerCase().contains(job);

RenovationTemplate _structural(String type) =>
    RenovationTemplatesCatalog.forProject(type, RenovationScope.structural);

List<RenovationTemplateItem> _bom(RenovationTemplate template) =>
    BomQuantityEstimator.scaleTemplate(
      template: template,
      areaSqm: _area,
      scope: template.scope,
    );

void main() {
  test('a structural bathroom carries new walls, a slab and their forms', () {
    final items = _bom(_structural('Bathroom Renovation'));
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

    // Forms: 0.2 sheets per sq.m × 20 × 1.08 = 4.3 -> 5 sheets.
    expect(qty((i) => _kind(i, MaterialKind.formworkPlywood)), 5);
  });

  test('no structural BOM orders the same structural material twice', () {
    for (final template in RenovationTemplatesCatalog.allTemplates
        .where((t) => t.scope.includesStructural)) {
      final items = _bom(template);
      for (final kind in kStructuralOnlyKinds) {
        expect(items.where((i) => _kind(i, kind)).length,
            lessThanOrEqualTo(1),
            reason: '${template.id} ${kind.name}');
      }
    }
  });

  test('each structural job carries only the structure it needs', () {
    // A floor slab repair pours a slab and builds no walls.
    final floor = _bom(_structural('Floor Renovation'));
    expect(floor.any((i) => _kind(i, MaterialKind.structuralCement)), isTrue);
    expect(floor.any((i) => _kind(i, MaterialKind.chbBlock)), isFalse);

    // A rebuilt wall needs no slab.
    final wall = _bom(_structural('Wall Finishing'));
    expect(wall.any((i) => _kind(i, MaterialKind.chbBlock)), isTrue);
    expect(wall.any((i) => _kind(i, MaterialKind.gravel)), isFalse);

    // A roof replacement gets neither, only its framing.
    final roof = _bom(_structural('Roof Repair'));
    expect(roof.any((i) => _kind(i, MaterialKind.roofPurlin)), isTrue);
    expect(
      roof.any((i) =>
          _kind(i, MaterialKind.chbBlock) ||
          _kind(i, MaterialKind.structuralCement)),
      isFalse,
    );
  });

  test('cosmetic and functional BOMs carry no structural lines', () {
    for (final template in RenovationTemplatesCatalog.allTemplates
        .where((t) => !t.scope.includesStructural)) {
      final items = _bom(template);
      expect(items.where(_structuralOnly), isEmpty, reason: template.id);
      expect(
        items.where((i) => _sandFor(i, 'slab') || _sandFor(i, 'plaster')),
        isEmpty,
        reason: template.id,
      );
    }
  });

  test('a cosmetic scope drops structural lines from any template', () {
    final items = BomQuantityEstimator.scaleTemplate(
      template: _structural('Bathroom Renovation'),
      areaSqm: _area,
      scope: RenovationScope.cosmetic,
    );
    expect(items.where(_structuralOnly), isEmpty);
  });

  test('a tile bedding sand line keeps its own small rate', () {
    // Screed sand, not wall plaster sand: 20 sq.m x 0.025 = 0.5 cu.m.
    final items = BomQuantityEstimator.scaleTemplate(
      template: const RenovationTemplate(
        id: 'bedding',
        renovationType: 'Living Room Renovation',
        name: 'Bedding',
        description: '',
        items: [
          RenovationTemplateItem(
            name: 'Washed Sand',
            category: 'Floor Preparation',
            unit: 'cu.m',
            defaultQuantity: 1,
          ),
        ],
      ),
      areaSqm: _area,
    );
    expect(items.where((i) => i.name == 'Washed Sand').single.defaultQuantity,
        0.5);
  });

  test('the AI consultation BOM adds no structural lines of its own', () {
    final template = BomQuantityEstimator.buildConsultationTemplate(
      projectType: 'Bedroom Renovation',
      areaSqm: _area,
      materialNames: const ['Ceramic floor tiles'],
      scope: RenovationScope.structural,
    );
    expect(template.items.where(_structuralOnly), isEmpty);
  });

  test('structural formulas state what they were sized from', () {
    final items = _bom(_structural('Bathroom Renovation'));
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

  test('structural work sends footings and underpinning to the engineer', () {
    expect(RenovationScope.structural.description.toLowerCase(),
        contains('underpinning'));
    expect(BomQuantityEstimator.structuralNote, contains('underpinning'));
    expect(BomQuantityEstimator.structuralNote, contains('engineer'));
  });
}
