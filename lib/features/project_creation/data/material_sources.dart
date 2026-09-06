import 'package:iconstruct/features/project_creation/data/material_kind.dart';

/// The region this estimating tool is scoped to.
const String kEstimateRegion = 'Region IV-A (CALABARZON)';

/// Provinces covered by the region, each with its own DPWH district
/// engineering office.
const List<String> kRegionProvinces = <String>[
  'Cavite',
  'Laguna',
  'Batangas',
  'Rizal',
  'Quezon',
];

/// Provenance for every material the system estimates.
///
/// Answers the question an adviser, an engineer, or a supplier will ask:
/// *where did this come from?* Each material can name the Philippine authority
/// that defines what the material must be, and separately the reference that
/// supplies the quantity coefficient. Those are not the same document and the
/// distinction matters:
///
///   * The **DPWH Standard Specifications** say what qualifies as acceptable
///     material and workmanship. They do not publish quantity-per-square-metre
///     tables, so citing DPWH for a coefficient would be a false citation.
///   * The **quantity coefficients** come from Max Fajardo's *Simplified
///     Construction Estimate*, from plain geometry, or from published
///     manufacturer coverage rates for proprietary goods.
///   * **Commercial packaging and counter practice** are neither. They are
///     CALABARZON hardware trade practice, and they are labelled as such
///     rather than dressed up as a standard.
///
/// Note on volumes: a house renovation or extension is a *building*, so the
/// governing items are DPWH Volume III (Buildings). Volume II items 404 and
/// 405 cover highways and bridges and are the wrong citation here.
///
/// Geographic scope: this system serves **Region IV-A (CALABARZON)**. Getting
/// the regional boundary right matters, because the three tiers are not
/// regional in the same way:
///
///   * The **DPWH Standard Specifications and the PNS are national**. They
///     apply identically in Cavite, Laguna, Batangas, Rizal and Quezon as
///     anywhere else in the country. Relabelling a national item as a Region
///     IV-A item would be a false citation, so the app does not do it. What is
///     regional is which office applies and enforces them, namely DPWH
///     Regional Office IV-A and the district engineering offices for the five
///     provinces.
///   * **Quantity coefficients** from Fajardo are likewise national.
///   * **Commercial packaging, counter terminology and supplier availability
///     are genuinely regional**, and that tier is scoped to CALABARZON
///     hardware retail rather than claimed for the whole country.
///
/// Full provenance table, including edition dates and links, lives in
/// `docs/material-data-sources.md`.
enum SourceTier {
  /// A Philippine national instrument: a DPWH item, a PNS, or the NSCP.
  nationalStandard,

  /// A published estimating reference or a manufacturer's stated coverage.
  referenceText,

  /// Hardware trade practice observed in Region IV-A (CALABARZON). Real and
  /// widely followed, but not codified in any national document, and flagged
  /// so it is never mistaken for one. This is the one tier that is genuinely
  /// regional; the standards above it are national instruments.
  tradePractice,
}

class MaterialSource {
  final SourceTier tier;

  /// Who publishes it, e.g. 'DPWH', 'DTI-BPS', 'ASEP'.
  final String authority;

  /// The document and clause, e.g. 'Vol. III Item 1046 — Masonry Works'.
  final String reference;

  /// What this source actually backs, in plain words. Keeps a citation from
  /// being stretched to cover something it does not say.
  final String covers;

  const MaterialSource({
    required this.tier,
    required this.authority,
    required this.reference,
    required this.covers,
  });

  String get tierLabel => switch (tier) {
        SourceTier.nationalStandard => 'Philippine national standard',
        SourceTier.referenceText => 'Estimating reference',
        SourceTier.tradePractice => 'CALABARZON hardware trade practice',
      };
}

// ── Philippine national standards ──────────────────────────────────────────

const _dpwh1018 = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DPWH',
  reference: 'Standard Specifications Vol. III, Item 1018 — Ceramic/Granite Tiles',
  covers: 'Tile quality, setting bed, and workmanship for floor and wall tile.',
);

const _dpwh1027 = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DPWH',
  reference: 'Standard Specifications Vol. III, Item 1027 — Cement Plaster Finish',
  covers: 'Plaster mix and thickness on masonry faces.',
);

const _dpwh1032 = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DPWH',
  reference:
      'Standard Specifications Vol. III, Item 1032 — Painting, Varnishing and Other Related Works',
  covers: 'Surface preparation and the primer-plus-two-topcoat system.',
);

const _dpwh1046 = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DPWH',
  reference:
      'Standard Specifications Vol. III, Item 1046 — Masonry Works (amended by DO 080 s.2018)',
  covers: 'Concrete hollow block laying, mortar, and wall reinforcement.',
);

const _dpwh900 = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DPWH',
  reference: 'Standard Specifications Vol. III, Item 900 — Reinforced Concrete',
  covers:
      'Structural concrete for buildings. This is the building item; Vol. II '
      'Item 405 covers highways and does not apply to a house extension.',
);

const _dpwh902 = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DPWH',
  reference: 'Standard Specifications Vol. III, Item 902 — Reinforcing Steel',
  covers: 'Placing, splicing and bending of reinforcing bars in buildings.',
);

const _dpwh1013 = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DPWH',
  reference: 'Standard Specifications Vol. III, Item 1013 — Corrugated Metal Roofing',
  covers: 'Roofing sheet laps, fastening, and accessories.',
);

const _dpwh1014 = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DPWH',
  reference:
      'Standard Specifications Vol. III, Item 1014 — Prepainted Metal Sheets (amended by DO 003 s.2018)',
  covers:
      'Base metal thickness, coating mass and paint film for pre-painted '
      'roofing. This is the clause a Ga.26 claim is checked against.',
);

const _dpwh1003 = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DPWH',
  reference: 'Standard Specifications Vol. III, Item 1003 — Carpentry and Joinery Works',
  covers: 'Lumber and plywood grading for forms and carpentry.',
);

const _dpwh1047 = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DPWH',
  reference: 'Standard Specifications Vol. III, Item 1047 — Metal Structures',
  covers: 'Steel framing sections including roof purlins.',
);

const _pns49 = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DTI-BPS',
  reference: 'PNS 49:2020 — Steel bars for concrete reinforcement',
  covers:
      'Nominal mass, dimensions and grade of deformed bars. This is what an '
      'undersized "commercial grade" bar fails.',
);

const _pnsCmu = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DTI-BPS',
  reference: 'PNS ASTM C90:2019 (loadbearing) / PNS ASTM C129:2019 (non-loadbearing)',
  covers:
      'Concrete masonry unit dimensions and compressive strength. These '
      'replaced the withdrawn PNS 16:1984 in 2019.',
);

const _nscp = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'ASEP',
  reference: 'National Structural Code of the Philippines (NSCP)',
  covers:
      'Reinforcement spacing, cover and detailing. Separate from the National '
      'Building Code (PD 1096), which is not a structural code.',
);

// ── Quantity coefficients ──────────────────────────────────────────────────

const _fajardo = MaterialSource(
  tier: SourceTier.referenceText,
  authority: 'Max B. Fajardo Jr.',
  reference: 'Simplified Construction Estimate',
  covers:
      'Materials-per-unit coefficients: cement and sand per cubic metre of '
      'mortar and concrete, plaster rates, and waste allowances.',
);

const _geometry = MaterialSource(
  tier: SourceTier.referenceText,
  authority: 'Derived',
  reference: 'Area divided by unit face area, plus a stated waste factor',
  covers:
      'Tile and block piece counts. Arithmetic from the size you selected, not '
      'a published table, so it stays correct for any size.',
);

const _manufacturer = MaterialSource(
  tier: SourceTier.referenceText,
  authority: 'Manufacturer',
  reference: 'Published coverage rate on the product packaging',
  covers:
      'Proprietary goods with no national coefficient: adhesive, grout, skim '
      'coat, paint spreading rate, sealants. Verify against the brand you buy.',
);

// ── Trade practice ─────────────────────────────────────────────────────────

const _trade = MaterialSource(
  tier: SourceTier.tradePractice,
  authority: 'CALABARZON hardware trade practice',
  reference:
      'Commercial packaging and counter terminology in Cavite, Laguna, '
      'Batangas, Rizal and Quezon',
  covers:
      'How the item is packed and asked for: 40 kg cement bags, 6 m bar '
      'lengths, 4 L paint gallons, 4 ft by 8 ft plywood, gauge numbers for '
      'roofing. Observed across CALABARZON hardware retail, from the chains '
      'in Calamba, Santa Rosa, Dasmarinas, Antipolo and Lipa down to barangay '
      'hardware. Not codified anywhere. Confirm with your own supplier.',
);

/// The office that applies the national specifications inside this region, and
/// the source of regional unit-price references used at the canvassing stage.
const _dpwhRegion4a = MaterialSource(
  tier: SourceTier.nationalStandard,
  authority: 'DPWH Regional Office IV-A (CALABARZON)',
  reference:
      'Regional and district engineering offices for Cavite, Laguna, '
      'Batangas, Rizal and Quezon',
  covers:
      'Applies and enforces the national specifications within this region, '
      'and publishes the regional unit-price and quantity references used for '
      'programs of work here. The specification itself is national; the office '
      'and its price data are what is regional.',
);

/// Sources backing a material, most authoritative first.
class MaterialSources {
  MaterialSources._();

  static List<MaterialSource> forKind(MaterialKind kind) => switch (kind) {
        MaterialKind.floorTile ||
        MaterialKind.wallTile =>
          const [_dpwh1018, _geometry, _trade],

        MaterialKind.tileAdhesive ||
        MaterialKind.tileGrout =>
          const [_dpwh1018, _manufacturer, _trade],

        MaterialKind.tileSpacer => const [_trade],

        MaterialKind.paintPrimer ||
        MaterialKind.paintTopcoat ||
        MaterialKind.skimCoat =>
          const [_dpwh1032, _manufacturer, _trade],

        MaterialKind.cementBedding => const [_dpwh1018, _fajardo, _trade],

        MaterialKind.structuralCement ||
        MaterialKind.gravel =>
          const [_dpwh900, _fajardo, _dpwhRegion4a, _trade],

        MaterialKind.washedSand => const [_dpwh900, _fajardo, _trade],

        MaterialKind.chbBlock =>
          const [_dpwh1046, _pnsCmu, _geometry, _dpwhRegion4a, _trade],
        MaterialKind.chbMortar => const [_dpwh1046, _dpwh1027, _fajardo, _trade],

        MaterialKind.rebar => const [_pns49, _dpwh902, _nscp, _trade],
        MaterialKind.tieWire => const [_dpwh902, _trade],

        MaterialKind.roofingSheet => const [_dpwh1014, _dpwh1013, _trade],
        MaterialKind.roofPurlin => const [_dpwh1047, _trade],
        MaterialKind.roofSealant => const [_dpwh1013, _manufacturer, _trade],

        MaterialKind.formworkPlywood ||
        MaterialKind.formworkLumber ||
        MaterialKind.formworkNails =>
          const [_dpwh1003, _fajardo, _trade],

        MaterialKind.waterproofing => const [_manufacturer, _trade],

        MaterialKind.plumbingFixture ||
        MaterialKind.plumbingConsumable ||
        MaterialKind.electrical ||
        MaterialKind.areaGoods ||
        MaterialKind.genericConsumable ||
        MaterialKind.unknown =>
          const [_trade],
      };

  static List<MaterialSource> forItem({
    required String name,
    String category = '',
    String unit = '',
  }) =>
      forKind(classifyMaterialParts(name: name, category: category, unit: unit));
}
