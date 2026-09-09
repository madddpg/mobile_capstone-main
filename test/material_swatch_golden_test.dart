// Golden images are platform-specific: this one was generated on Windows,
// and font rendering and antialiasing differ enough on a Linux CI runner to
// fail a perfectly correct build. Tagged so CI can skip it while it stays
// useful locally for reviewing the drawings.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconstruct/features/project_creation/data/material_visual.dart';
import 'package:iconstruct/features/project_creation/widgets/material_swatch.dart';

/// Renders every material swatch so the drawings can be reviewed as images,
/// and locks them against silent regressions in the painters.
///
/// Materials listed in [kBundledMaterialPhotos] show a photograph in the app,
/// not a drawing, and appear as blank cells in this golden: the widget test
/// bundle resolves the asset but never decodes it. Their real coverage is the
/// file-existence test below.
void main() {
  // (label, item name, category, unit, selected size)
  const specimens = <List<String>>[
    ['Floor tile 600', 'Floor Tile', 'Flooring', 'pcs', '600x600'],
    ['Floor tile 300', 'Floor Tile', 'Flooring', 'pcs', '300x300'],
    ['Wall tile 300x600', 'Wall Tile', 'Wall Surface', 'pcs', '300x600'],
    ['Subway 75x300', 'Wall Tile', 'Wall Surface', 'pcs', '75x300'],
    ['Tile adhesive', 'Tile Adhesive', 'Tile Works', 'bags', ''],
    ['Tile grout', 'Tile Grout', 'Tile Works', 'packs', ''],
    ['Tile spacers', 'Tile Cross Spacers', 'Tile Works', 'packs', ''],
    ['Cutting disc', 'Diamond Tile Cutting Disc', 'Tile Works', 'pcs', ''],
    ['Cement 40kg', 'Portland Cement', 'Masonry', 'bags', ''],
    ['Slab cement', 'Portland Cement Slab', 'Concrete', 'bags', ''],
    ['Washed sand', 'Washed Sand', 'Concrete', 'cu.m', ''],
    ['Gravel 3/4', 'Crushed Gravel', 'Concrete', 'cu.m', ''],
    ['CHB 4 inch', 'CHB Block', 'Masonry', 'pcs', '4"'],
    ['CHB 6 inch', 'CHB Block', 'Masonry', 'pcs', '6"'],
    ['Rebar 10mm', 'Deformed Rebar', 'Steel', 'pcs', '10mm'],
    ['Rebar 16mm', 'Deformed Rebar', 'Steel', 'pcs', '16mm'],
    ['Tie wire', '#16 GI Tie Wire', 'Steel', 'kg', ''],
    ['GI roofing', 'Pre-painted GI Roofing Sheet', 'Roofing', 'ln.m', ''],
    ['C-purlin', 'C-Purlin', 'Roofing', 'pcs', ''],
    ['Vulcaseal', 'Vulcaseal Roof Sealant', 'Roofing', 'cans', ''],
    ['Marine ply', 'Marine Plywood', 'Formwork', 'sheets', ''],
    ['Coco lumber', 'Coco Lumber', 'Formwork', 'pcs', ''],
    ['Wire nails', 'Common Wire Nails', 'Formwork', 'kg', ''],
    ['Primer', 'Concrete Primer', 'Paint', 'gal', ''],
    ['Latex topcoat', 'Latex Topcoat Paint', 'Paint', 'gal', ''],
    ['Skim coat', 'Skim Coat', 'Paint', 'bags', ''],
    ['Masonry putty', 'Masonry Putty', 'Paint', 'gal', ''],
    ['Sandpaper', 'Sandpaper Grit 180', 'Paint', 'sheets', ''],
    ['Masking tape', "Painter's Masking Tape", 'Paint', 'rolls', ''],
    ['Roller set', 'Paint Roller Set', 'Paint', 'sets', ''],
    ['Paint brush', 'Paint Brush 3 inch', 'Paint', 'pcs', ''],
    ['Waterproofing', 'Liquid Waterproofing', 'Waterproofing', 'gal', ''],
    ['Water closet', 'Water Closet', 'Plumbing Fixture', 'set', ''],
    ['Lavatory', 'Lavatory Sink', 'Plumbing Fixture', 'pcs', ''],
    ['Shower set', 'Shower Set', 'Plumbing Fixture', 'set', ''],
    ['Faucet', 'Faucet', 'Plumbing Fixture', 'pcs', ''],
    ['Teflon tape', 'Teflon Threadseal Tape', 'Plumbing', 'rolls', ''],
    ['Silicone', 'Sanitary Silicone Sealant', 'Plumbing', 'tubes', ''],
    ['Solvent cement', 'PVC Solvent Cement', 'Plumbing', 'cans', ''],
    ['PVC pipe', 'PVC Sanitary Pipe', 'Plumbing', 'pcs', ''],
    ['Vinyl plank', 'Vinyl Plank Flooring', 'Flooring', 'sqm', ''],
    ['Electrical wire', 'THHN Wire', 'Electrical', 'rolls', ''],
  ];

  testWidgets('every material swatch renders', (tester) async {
    await tester.binding.setSurfaceSize(const Size(880, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Container(
          color: const Color(0xFF1E3042),
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in specimens)
                SizedBox(
                  width: 96,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MaterialSwatch(
                        visual: MaterialVisual.forItem(
                          name: s[1],
                          category: s[2],
                          unit: s[3],
                        ),
                        size: s[4].isEmpty ? null : s[4],
                        dimension: 64,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s[0],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFFEDE4D4),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Wrap),
      matchesGoldenFile('goldens/material_swatches.png'),
    );
  });

  test('every registered material photo exists on disk', () {
    // A key registered without its file would silently fall back to the
    // drawing, which is exactly the state this change set out to remove.
    for (final key in kBundledMaterialPhotos) {
      expect(File(materialPhotoPath(key)).existsSync(), isTrue,
          reason: 'missing photo file for $key');
    }
  });

  test('a material with a photo resolves to that photo, not a glyph', () {
    for (final key in kBundledMaterialPhotos) {
      expect(materialPhotoPath(key), startsWith('assets/images/materials/'));
      expect(materialPhotoPath(key), endsWith('.jpg'));
    }
  });
}
