# Where the materials come from

Provenance for every material and quantity iConstruct produces. Written for
review: each claim names the Philippine instrument behind it, and anything not
backed by a national instrument says so plainly.

## The short answer

The system produces three different kinds of data, and they come from three
different places. Collapsing them into one citation would be a false claim,
so the app keeps them apart and labels each one.

| Layer | Question it answers | Where it comes from |
|---|---|---|
| Material list | Which items belong in this job | Renovation templates in the app, extended by supplier catalogue records and, optionally, an AI consultation the user reviews |
| Quantity | How much of each item | Geometry from the user's area and selected size, Fajardo's coefficients, and published manufacturer coverage rates |
| Identification | How to recognise and order it | Philippine hardware trade practice, with the national standard cited for the acceptance check where one exists |

The app shows this on every material. Open any line item in the Bill of
Materials, tap its picture, and the identification card ends with a
**Where this comes from** section listing the sources for that specific item,
each tagged as a national standard, an estimating reference, or trade practice.

In code this lives in `lib/features/project_creation/data/material_sources.dart`.

## Layer 1 — which materials appear

Three origins, in order of precedence.

1. **Built-in renovation templates**, in
   `lib/features/project_creation/data/renovation_templates.dart`. Seven
   renovation types are covered: bathroom, kitchen, floor, interior painting,
   roof repair, plumbing installation, and electrical installation. Each type
   offers three style variants. The item lists were assembled from the DPWH
   work items that apply to that trade, plus the auxiliary consumables a
   foreman orders alongside them but which no specification lists, such as
   tile spacers, teflon tape, and masking tape.

2. **Supplier catalogue records** from Firestore, which carry real products
   from participating hardware stores. These are supplier-supplied data, not
   authored by the system.

3. **AI consultation**, an optional path where the user describes the job in
   their own words. Suggestions are returned to the user for review and are
   never posted for quotation without the user accepting them.

Scope filtering then removes what does not belong. A Full Renovation excludes
structural items such as gravel, hollow blocks, rebar, and formwork; an
Extension includes them. The rule is in
`lib/features/project_creation/data/material_kind.dart`.

## Layer 2 — how the quantities are computed

Two distinct authorities, and the difference is the point.

**The DPWH Standard Specifications do not publish quantity-per-square-metre
tables.** They specify what qualifies as acceptable material and workmanship.
So a DPWH item number is cited for *what the material must be*, and a separate
source is cited for *how much of it you need*. Every formula string in the app
now shows both, in the form `Material spec: ... | Quantity: ...`.

| Quantity | Coefficient | Source of the coefficient |
|---|---|---|
| Floor and wall tile pieces | Area divided by tile face area, plus 8% | Geometry from the size the user selects, waste allowance per Fajardo |
| Tile adhesive | 1 bag of 25 kg per 4.5 sq.m at 6 mm notch | Manufacturer published coverage |
| Tile grout | 0.12 to 0.30 kg per sq.m by tile size | Joint volume from tile size, manufacturer coverage |
| Mortar bedding | 25 mm Class B 1:3 | Fajardo |
| Paint | 1 primer coat plus 2 topcoats | Manufacturer spreading rate; coat count per DPWH Item 1032 |
| Skim coat | 1 bag of 20 kg per 10 sq.m | Manufacturer published coverage |
| CHB pieces | 12.5 pcs per sq.m, plus 5% | Geometry of the 400 x 200 mm block face |
| CHB mortar and plaster | 0.90 bags per sq.m at 4 in, 1.40 at 6 in | Fajardo, Class B 1:3 mortar plus 16 mm two-face plaster |
| Structural concrete | 9.0 bags cement, 0.50 cu.m sand, 1.00 cu.m gravel per cu.m | Fajardo, Class A 1:2:4 mix |
| Rebar mass | W = D squared divided by 162.2 kg per metre | Nominal mass formula; bar sizes to PNS 49:2020 |
| Rebar spacing | 4.28 linear metres per sq.m of wall, plus 5% | NSCP detailing for CHB wall reinforcement |
| Roofing | 10% side and end lap allowance | Trade practice for rib-type sheets |

Rates live in `lib/features/project_creation/data/ph_renovation_rates.dart`.

## Layer 3 — the identification content

This is the material pictures, the counter phrasing, the lookalike warnings,
and the delivery checks added so a user can confirm they are buying the right
item. **Its provenance is different and weaker, and the app says so.**

- **Commercial packaging and counter terminology** are Philippine hardware
  trade practice: 40 kg cement bags, 6 m bar lengths, 4 L paint gallons,
  4 ft by 8 ft plywood, gauge numbers for roofing sheets. These are widely and
  consistently observed in Philippine hardware retail but are not codified in
  any national instrument. In the app they carry an amber
  **PH hardware trade practice** tag.

- **Acceptance checks** are tied to a national standard wherever one exists.
  The rebar check, that a 6 m bar sold as 10 mm should weigh about 3.7 kg,
  follows directly from the nominal mass formula and PNS 49:2020. The hollow
  block thickness check follows from PNS ASTM C90:2019. The Ga.26 roofing
  check is the thing DPWH Item 1014 governs.

- **The pictures** are vector drawings authored for this project, not
  photographs. Nothing is reproduced from a manufacturer or retailer. They
  are drawn from the physical form of the goods and respond to the spec the
  user selects, so a 6 in block draws deeper than a 4 in and a 16 mm bar
  draws thicker than a 10 mm.

**This layer should be validated by a practising foreman or the adviser before
defence.** It is the one part of the system not traceable to a published
document, and it is the part a practitioner can most usefully correct.

## Citations, verified against primary sources

Checked during this audit rather than carried over from the original plan.

**DPWH Standard Specifications for Public Works Structures, Volume III
(Buildings)**

| Item | Official title |
|---|---|
| 900 | Reinforced Concrete |
| 902 | Reinforcing Steel |
| 1003 | Carpentry and Joinery Works |
| 1013 | Corrugated Metal Roofing |
| 1014 | Prepainted Metal Sheets, amended by DO 003 s.2018 |
| 1018 | Ceramic/Granite Tiles |
| 1027 | Cement Plaster Finish |
| 1032 | Painting, Varnishing and Other Related Works |
| 1046 | Masonry Works, amended by DO 080 s.2018 |
| 1047 | Metal Structures |

**Philippine National Standards, DTI Bureau of Philippine Standards**

- PNS 49:2020, Steel bars for concrete reinforcement. Supersedes PNS 49:2019.
- PNS ASTM C90:2019, loadbearing concrete masonry units, and PNS ASTM
  C129:2019, non-loadbearing. Both adopted in 2019, cancelling and replacing
  PNS 16:1984.

**Structural design**

- National Structural Code of the Philippines, published by the Association of
  Structural Engineers of the Philippines. This is a separate instrument from
  the National Building Code, Presidential Decree 1096, which is not a
  structural code.

**Estimating reference**

- Max B. Fajardo Jr., *Simplified Construction Estimate*.

## Corrections made during this audit

Four citation errors were found in the original implementation and fixed.

1. **Structural concrete cited DPWH Item 405.** Item 405 is a Volume II
   highways and bridges item. A house extension is a building, so the correct
   citation is Volume III Item 900, Reinforced Concrete.

2. **Reinforcing steel cited DPWH Item 404**, likewise a highways item.
   Corrected to Volume III Item 902, Reinforcing Steel.

3. **Item titles were paraphrased rather than quoted.** Item 1018 was cited as
   "Floor Tile Works" and "Glazed Wall Tile Works"; its actual title is
   "Ceramic/Granite Tiles". Item 1032 was cited as "Concrete Masonry Painting";
   its actual title is "Painting, Varnishing and Other Related Works". Item
   1046 was cited as "Concrete Hollow Block Masonry"; its actual title is
   "Masonry Works".

4. **Plastering was folded into Item 1046.** Cement plaster finish is its own
   item, 1027, and is now cited alongside 1046 for the CHB wall calculation.

Two further accuracy fixes:

- **The NSCP was labelled "NSCP (PD 1096)"**, conflating the structural code
  with the National Building Code. They are different documents with different
  publishers.

- **Quantity coefficients were attributed to DPWH item numbers**, which do not
  publish them. Every formula string now separates the material specification
  from the source of the coefficient.

One classification bug was also found and fixed: the material classifier
matched the substring "paint" inside "pre-painted", so a pre-painted GI roofing
sheet was being classified as paint and estimated in gallons. Covered by tests
in `test/material_kind_test.dart`.

## Limits worth stating at defence

- Coefficients drawn from manufacturer coverage rates vary by brand. The app
  labels these so a user knows to check the bag.
- The trade practice layer reflects general Philippine hardware retail and may
  differ by region and by store.
- The system estimates materials for canvassing and quotation. It does not
  perform structural design, and it does not replace a licensed engineer where
  the NSCP requires one.

## Sources

- [DPWH Standard Specification for Item 1046, Masonry Works, DO 080 s.2018](https://www.dpwh.gov.ph/dpwh/sites/default/files/issuances/DO_080_s2018.pdf)
- [DPWH amendment to Item 1014, Prepainted Metal Sheets, DO 003 s.2018](https://www.studocu.com/ph/document/university-of-science-and-technology-of-southern-philippines/bs-in-civil-engineering/do-003-s2018-standard-specifications/60437585)
- [DPWH Standard Specifications Volume 3, item list and titles](https://pdfcoffee.com/dpwh-standard-specifications-volume-3-summary-pdf-free.html)
- [DTI-BPS approves standard on steel bars, PNS 49:2020](https://bps.dti.gov.ph/press-releases/24-2020/196-dti-bps-approves-standard-on-steel-bars)
- [DTI-BPS adopts international standards on masonry units, PNS ASTM C90 and C129](https://bps.dti.gov.ph/press-releases/23-2019/183-dti-bps-adopts-international-standards-on-masonry-units)
- [GPPB list of Philippine National Standards, construction materials](https://www.gppb.gov.ph/wp-content/uploads/2023/06/Annex-12-List-of-Philippine-National-Standards.pdf)
