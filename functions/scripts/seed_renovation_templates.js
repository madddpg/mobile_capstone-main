"use strict";

/**
 * Seed Firestore `renovation_templates` with 3 style templates per
 * renovation type (Modern / Minimalist / Traditional).
 *
 * Usage:
 *   set GOOGLE_APPLICATION_CREDENTIALS=path\\to\\serviceAccount.json
 *   node functions/scripts/seed_renovation_templates.js --project <firebase-project-id>
 *
 * Optional:
 *   --dry-run
 */

const admin = require("firebase-admin");

function parseArgs(argv) {
  const args = { projectId: null, dryRun: false };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === "--project") args.projectId = argv[i + 1] || null;
    if (a === "--dry-run") args.dryRun = true;
  }
  return args;
}

function item(name, category, unit, defaultQuantity, size) {
  const row = { name, category, unit, defaultQuantity };
  if (size) row.size = size;
  return row;
}

function template(id, renovationType, style, name, description, order, items) {
  return {
    id,
    renovationType,
    style,
    name,
    name_lower: name.toLowerCase(),
    description,
    isActive: true,
    order,
    items,
  };
}

const templates = [
  template(
    "kitchen_modern",
    "Kitchen Renovation",
    "modern",
    "Modern Kitchen",
    "Sleek finishes, durable surfaces, and contemporary fixtures.",
    1,
    [
      item("Quartz Countertop", "Countertops", "sqm", 6),
      item("Base Cabinets", "Cabinetry", "set", 8),
      item("Wall Cabinets", "Cabinetry", "set", 6),
      item("Ceramic Floor Tiles", "Flooring", "sqm", 20, "600x600"),
      item("Subway Wall Tiles", "Wall Finishing", "sqm", 12, "75x300"),
      item("Kitchen Sink", "Plumbing Fixtures", "pcs", 1),
      item("Faucet Mixer", "Plumbing Fixtures", "pcs", 1),
      item("LED Under-cabinet Lights", "Electrical", "pcs", 4),
      item("Paint (Interior)", "Finishing", "gal", 2),
      item("Silicone Sealant", "Installation", "pcs", 4),
    ]
  ),
  template(
    "kitchen_minimalist",
    "Kitchen Renovation",
    "minimalist",
    "Minimalist Kitchen",
    "Clean lines, fewer materials, efficient essentials only.",
    2,
    [
      item("Laminate Countertop", "Countertops", "sqm", 5),
      item("Handleless Base Cabinets", "Cabinetry", "set", 6),
      item("Open Wall Shelves", "Cabinetry", "pcs", 4),
      item("Vinyl Flooring", "Flooring", "sqm", 18),
      item("Matte Wall Paint", "Wall Finishing", "gal", 2),
      item("Single Bowl Sink", "Plumbing Fixtures", "pcs", 1),
      item("Minimalist Faucet", "Plumbing Fixtures", "pcs", 1),
      item("Recessed Ceiling Lights", "Electrical", "pcs", 6),
      item("Tile Adhesive", "Installation", "bags", 5),
    ]
  ),
  template(
    "kitchen_traditional",
    "Kitchen Renovation",
    "traditional",
    "Traditional Kitchen",
    "Classic cabinetry, warmer finishes, and standard fixtures.",
    3,
    [
      item("Granite Countertop", "Countertops", "sqm", 6),
      item("Shaker Base Cabinets", "Cabinetry", "set", 8),
      item("Shaker Wall Cabinets", "Cabinetry", "set", 7),
      item("Ceramic Floor Tiles", "Flooring", "sqm", 22, "400x400"),
      item("Decorative Wall Tiles", "Wall Finishing", "sqm", 10),
      item("Double Bowl Sink", "Plumbing Fixtures", "pcs", 1),
      item("Classic Bridge Faucet", "Plumbing Fixtures", "pcs", 1),
      item("Pendant Lights", "Electrical", "pcs", 3),
      item("Wood Stain / Varnish", "Finishing", "L", 3),
      item("Grout", "Installation", "bags", 4),
    ]
  ),
  template(
    "bathroom_modern",
    "Bathroom Renovation",
    "modern",
    "Modern Bathroom",
    "Clean wet-area materials with contemporary fixtures.",
    1,
    [
      item("Porcelain Floor Tiles", "Floor Surface", "sqm", 8, "600x600"),
      item("Ceramic Wall Tiles", "Wall Surface", "sqm", 18),
      item("Tile Adhesive", "Floor Installation", "bags", 4),
      item("Waterproofing Membrane", "Floor Installation", "L", 10),
      item("Wall-Hung Toilet", "Fixtures", "pcs", 1),
      item("Vessel Sink", "Fixtures", "pcs", 1),
      item("Rain Shower Set", "Fixtures", "set", 1),
      item("LED Mirror Light", "Electrical", "pcs", 1),
      item("Silicone Sealant", "Finishing", "pcs", 3),
    ]
  ),
  template(
    "bathroom_minimalist",
    "Bathroom Renovation",
    "minimalist",
    "Minimalist Bathroom",
    "Essential wet-area package with simple finishes.",
    2,
    [
      item("Non-Slip Floor Tiles", "Floor Surface", "sqm", 7),
      item("Large-format Wall Tiles", "Wall Surface", "sqm", 16),
      item("Tile Adhesive", "Floor Installation", "bags", 3),
      item("Grout", "Wall Finishing", "bags", 3),
      item("Close-Coupled Toilet", "Fixtures", "pcs", 1),
      item("Pedestal Sink", "Fixtures", "pcs", 1),
      item("Handheld Shower", "Fixtures", "set", 1),
      item("Exhaust Fan", "Electrical", "pcs", 1),
    ]
  ),
  template(
    "bathroom_traditional",
    "Bathroom Renovation",
    "traditional",
    "Traditional Bathroom",
    "Classic fixtures and standard tiling package.",
    3,
    [
      item("Ceramic Floor Tiles", "Floor Surface", "sqm", 8, "300x300"),
      item("Ceramic Wall Tiles", "Wall Surface", "sqm", 20),
      item("Tile Adhesive", "Floor Installation", "bags", 5),
      item("Tile Spacers", "Floor Installation", "packs", 2),
      item("Standard Toilet", "Fixtures", "pcs", 1),
      item("Cabinet Lavatory", "Fixtures", "pcs", 1),
      item("Shower Valve Set", "Fixtures", "set", 1),
      item("Ceiling Light", "Electrical", "pcs", 2),
      item("Paint (Ceiling)", "Finishing", "gal", 1),
    ]
  ),
];

async function main() {
  const { projectId, dryRun } = parseArgs(process.argv.slice(2));
  admin.initializeApp(projectId ? { projectId } : undefined);
  const db = admin.firestore();

  console.log(`Seeding ${templates.length} renovation templates...`);
  if (dryRun) {
    for (const t of templates) {
      console.log(`  [dry-run] ${t.id} → ${t.name} (${t.items.length} items)`);
    }
    return;
  }

  const batch = db.batch();
  for (const t of templates) {
    const { id, ...data } = t;
    batch.set(db.collection("renovation_templates").doc(id), data, {
      merge: true,
    });
    console.log(`  queued ${id}`);
  }
  await batch.commit();
  console.log("Done. Collection: renovation_templates");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
