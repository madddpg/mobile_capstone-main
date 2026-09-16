# Adding photographs manually

How to drop in material photographs by hand. One folder, one naming rule, and
one line of code to register each file. Renovation templates have no
photographs.

Nothing here needs a rebuild of the estimating logic. A photo that is named
correctly and registered will replace the drawn placeholder for that material
the next time the app runs.

## Rules for every photograph

- **Real photographs only.** No drawings, no 3D product renders, no
  AI-generated images. A render looks convincing on a white background and is
  the easiest thing to grab by mistake; if the lighting is perfectly even and
  the background is a flawless gradient, it is probably a render.
- **The product, not the room.** A photo of a bathroom that happens to contain
  wall tile does not help someone identify wall tile at a counter. Fill the
  frame with the goods.
- **Readable at 44 pixels.** The swatch on a Bill of Materials row is small.
  Shoot close, and check it still reads when shrunk.
- **Rights.** Your own photographs are the safest and are the only ones with no
  attribution burden. If you use someone else's, it must carry a licence that
  permits reuse, and the credit goes in `docs/photo-credits.md`.
- **Region.** The project is scoped to Region IV-A (CALABARZON). A 40 kg cement
  sack photographed in a Calamba hardware beats a European 25 kg bag, even
  though both are cement.

Taking them yourself at a hardware store solves the rights question, the
regional question, and the framing question at once. It is the recommended
route.

## Material photographs

**Folder:** `assets/images/materials/`
**Format:** `.jpg`
**Name:** the material's key, exactly as listed below, plus `.jpg`
**Size:** roughly square, about 800 by 800 pixels. Larger is wasted; the app
never displays them above about 200 pixels.

### Step 1 — add the file

Save the photo as `assets/images/materials/<key>.jpg`. For example a photo of
floor tiles becomes `assets/images/materials/floor_tile.jpg`.

### Step 2 — register the key

Open `lib/features/project_creation/data/material_visual.dart` and add the key
to `kBundledMaterialPhotos`, keeping the list alphabetical:

```dart
const Set<String> kBundledMaterialPhotos = {
  'cement_bedding',
  'chb',
  'floor_tile',        // <- the line you add
  'mortar_cement',
  ...
};
```

That is the whole change. `MaterialSwatch` checks this set, shows the
photograph when the key is present, and falls back to the drawing when it is
not.

### Step 3 — check it

```bash
flutter test test/material_swatch_golden_test.dart
```

This fails if a key is registered without its file, which would otherwise
silently fall back to the drawing and look like nothing happened.

### Keys that already have a photograph

These nine are done. Replacing them with CALABARZON photographs is still an
improvement, since the current ones are European and American stock.

`cement_bedding`, `chb`, `mortar_cement`, `pvc_pipe`, `roller_set`,
`sandpaper`, `silicone`, `structural_cement`, `washed_sand`

### Keys still needing a photograph

Thirty-two remain. The key is on the left; what to photograph is on the right.

| File name | What to shoot |
|---|---|
| `floor_tile.jpg` | Stack of ceramic floor tiles, matte face visible |
| `wall_tile.jpg` | Glazed wall tiles, glossy face |
| `tile_adhesive.jpg` | 25 kg tile adhesive sack, label readable |
| `tile_grout.jpg` | 2 kg grout pouch |
| `tile_spacer.jpg` | Handful of plastic cross spacers |
| `cutting_disc.jpg` | 4 inch diamond cutting disc |
| `primer.jpg` | 4 L concrete primer can |
| `topcoat.jpg` | 4 L latex paint can |
| `skim_coat.jpg` | 20 kg skim coat sack |
| `masonry_putty.jpg` | Masonry putty tub or can |
| `masking_tape.jpg` | Roll of painter's masking tape |
| `paint_brush.jpg` | Paint brush, bristles visible |
| `waterproofing.jpg` | Cementitious waterproofing pail |
| `gravel.jpg` | Crushed 3/4 inch gravel, close up on the stone |
| `rebar.jpg` | Bundle of deformed bars, ribs visible |
| `tie_wire.jpg` | Coil of number 16 GI tie wire |
| `roofing_sheet.jpg` | Pre-painted rib-type GI sheet, ribs visible |
| `purlin.jpg` | C-purlin end on, channel visible |
| `vulcaseal.jpg` | Roof sealant can |
| `marine_plywood.jpg` | Marine plywood sheet, plies visible at the edge |
| `coco_lumber.jpg` | Stack of coco lumber |
| `cwn.jpg` | Loose common wire nails |
| `fasteners.jpg` | Tekscrews with rubber washers |
| `water_closet.jpg` | Water closet, whole unit |
| `lavatory.jpg` | Lavatory basin |
| `shower_set.jpg` | Shower head and arm |
| `faucet.jpg` | Faucet, threaded inlet visible |
| `teflon_tape.jpg` | Roll of teflon threadseal tape |
| `solvent_cement.jpg` | Tin of PVC solvent cement |
| `electrical.jpg` | Roll of THHN wire, size printed on insulation |
| `area_goods.jpg` | Vinyl plank flooring |
| `generic.jpg` | Generic boxed hardware item, used as a last-resort fallback |

## Templates have no photographs

Renovation templates no longer show pictures. They are chosen by name, style
and material list. The photos only ever covered two of seven renovation types
and added about 13 MB to the app, so they were removed along with the
`assets/images/templates/` folder. Do not add template photos back; material
photos are the ones that help a builder at the counter.

## Where the app declares the folder

The materials folder is declared in `pubspec.yaml`:

```yaml
assets:
  - assets/images/materials/
```

Folder declarations pick up new files automatically, so adding a photograph
needs no pubspec change. It does need a full restart rather than a hot reload,
because the asset manifest is read at startup.

## After adding a batch

```bash
flutter analyze
flutter test
```

If a photograph does not appear, the usual causes are a name that does not
match the key exactly, a `.png` where the code expects `.jpg`, the key not
added to the registry set, or a hot reload instead of a restart.
