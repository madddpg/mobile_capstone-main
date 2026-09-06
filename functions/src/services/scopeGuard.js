"use strict";

/**
 * Deterministic scope guard for the iConstruct AI Material Consultant.
 *
 * The system prompt already tells the model to stay on construction materials,
 * but a prompt is a request, not a control. Three things were unenforced:
 *
 *   1. `inScope` was whatever the model said, and the caller defaulted a
 *      missing flag to true. A model that ignored the instruction, or was
 *      talked out of it, answered anything.
 *   2. Every off-topic message still cost a model call.
 *   3. Suggestions were never checked to be construction materials at all.
 *
 * This module answers those in plain code, before and after the model runs.
 * It is intentionally conservative: it blocks only what is unambiguously out
 * of scope, and defers anything uncertain to the model rather than guessing.
 */

// ── Out of scope: other domains entirely ───────────────────────────────────
const OFF_DOMAIN = [
  // programming / homework / general assistant use
  "javascript", "python", "html", "css", "sql", "algorithm", "source code",
  "write code", "debug", "compile", "regex", "essay", "homework", "assignment",
  "thesis", "reviewer", "quiz", "exam",
  // personal advice the app must not give
  "medical", "diagnos", "prescription", "symptom", "lawyer", "lawsuit",
  "legal advice", "invest", "stock market", "crypto", "loan", "insurance",
  // chit-chat / identity probing
  "who are you", "what model", "your prompt", "ignore previous",
  "ignore all previous", "system prompt", "jailbreak", "pretend you are",
  "act as", "tell me a joke", "sing", "poem",
];

// ── Out of scope: adjacent construction topics that belong to another phase ──
// These are construction-related, so they need their own redirect message
// rather than the generic one.
const WRONG_PHASE = [
  { keys: ["how much does", "how much is", "how much will", "magkano", "price", "presyo", "cost of", "budget", "cheapest", "discount", "peso", "php ", "₱"], phase: "pricing" },
  { keys: ["who should i hire", "hire a", "contractor", "mason", "carpenter", "labor cost", "labor rate", "day rate", "wage", "crew size", "how many workers"], phase: "labor" },
  { keys: ["how long will", "how many days", "timeline", "schedule", "gantt", "deadline", "when will it finish"], phase: "schedule" },
  { keys: ["building permit", "barangay clearance", "occupancy permit", "how do i apply for a permit"], phase: "permits" },
  { keys: ["load bearing capacity", "beam size", "column size", "structural design", "seismic", "wind load", "footing depth"], phase: "engineering" },
  { keys: ["step by step", "how do i install", "how to install", "how do i lay", "how to lay", "how do i pour", "how to pour", "tutorial", "paano mag"], phase: "installation" },
];

// ── In scope: construction material vocabulary ─────────────────────────────
const MATERIAL_TERMS = [
  "tile", "tiles", "grout", "adhesive", "thinset", "spacer",
  "cement", "portland", "mortar", "plaster", "skim coat", "putty", "screed",
  "sand", "gravel", "aggregate", "concrete", "slab",
  "chb", "hollow block", "block", "masonry",
  "rebar", "steel bar", "deformed bar", "tie wire", "reinforc",
  "paint", "primer", "topcoat", "latex", "enamel", "sealer", "neutralizer",
  "waterproof", "plexibond", "membrane",
  "roof", "roofing", "gi sheet", "purlin", "tekscrew", "vulcaseal", "ridge",
  "plywood", "lumber", "coco lumber", "formwork", "nail", "cwn",
  "pipe", "pvc", "ppr", "fitting", "elbow", "faucet", "lavatory", "shower",
  "water closet", "toilet", "bidet", "sink", "teflon", "silicone", "sealant",
  "wire", "outlet", "switch", "breaker", "conduit", "electrical",
  "vinyl", "laminate", "plank", "flooring", "ceiling", "drywall", "gypsum",
  "sandpaper", "roller", "brush", "trowel",
  "material", "materials", "bom", "bill of materials", "canvass", "hardware",
  "renovation", "extension", "bathroom", "kitchen", "sqm", "square meter",
];

// ── Region IV-A (CALABARZON) place names ───────────────────────────────────
//
// The tool is scoped to CALABARZON, so a builder naming their town is on
// topic: "what tiles are easy to find in Lipa" is a material availability
// question, not chit-chat. Without this the message could read as off-domain.
const REGION_PLACES = [
  "calabarzon", "region iv-a", "region 4a", "region 4-a",
  "cavite", "laguna", "batangas", "rizal", "quezon province",
  "calamba", "santa rosa", "sta rosa", "binan", "binan", "cabuyao",
  "san pablo", "san pedro", "los banos", "bay", "calauan",
  "dasmarinas", "bacoor", "imus", "general trias", "gen trias", "tagaytay",
  "silang", "trece martires", "kawit", "noveleta", "rosario",
  "lipa", "tanauan", "batangas city", "sto tomas", "santo tomas", "malvar",
  "antipolo", "cainta", "taytay", "binangonan", "angono", "rodriguez",
  "lucena", "tayabas", "candelaria", "sariaya", "infanta",
];

function normalize(text) {
  return String(text || "").toLowerCase().replace(/\s+/g, " ").trim();
}

function hitsAny(haystack, needles) {
  return needles.some((n) => haystack.includes(n));
}

const WORD_RE = new Map();

/**
 * Word-boundary match, used for the material vocabulary.
 *
 * Plain substring matching is wrong here: "lumber" is inside "plumber", so
 * "hire a licensed plumber" read as a material question and a labour
 * suggestion survived the filter. Phrases in the material list ("hollow
 * block", "skim coat") still match, because the boundary is only applied at
 * the two ends.
 */
function hitsAnyWord(haystack, needles) {
  return needles.some((n) => {
    let re = WORD_RE.get(n);
    if (!re) {
      re = new RegExp("\\b" + n + "\\b", "i");
      WORD_RE.set(n, re);
    }
    return re.test(haystack);
  });
}

const REDIRECTS = {
  pricing:
    "I plan materials, not prices. Post your Bill of Materials and hardware " +
    "shops will quote it for you. Tell me what the job needs instead.",
  labor:
    "I only cover materials for your estimate, not hiring or labor rates. " +
    "What materials does the job need?",
  schedule:
    "I only cover materials, not schedules or timelines. Tell me about the " +
    "work and I will list what to buy.",
  permits:
    "Permits are outside what I handle. I can help list the materials for " +
    "your renovation estimate.",
  engineering:
    "Structural design needs a licensed engineer, not me. I can list the " +
    "materials once the design is settled.",
  installation:
    "I plan what to buy, not how to install it. Tell me the room and the " +
    "work and I will list the materials.",
  offDomain:
    "I can only help plan and list construction materials for your " +
    "iConstruct estimate. Describe the room, the work, or the area in sqm.",
};

/**
 * Runs before any model call.
 *
 * Returns `{ allow: true }` to proceed, or `{ allow: false, reply, reason }`
 * to answer directly without spending a call. Anything not clearly off-topic
 * is allowed through: the model, with the system prompt, is better than a
 * keyword list at the genuinely ambiguous cases.
 */
function preScreen(userMessage) {
  const msg = normalize(userMessage);
  if (!msg) return { allow: true };

  const mentionsMaterial =
    hitsAnyWord(msg, MATERIAL_TERMS) || hitsAny(msg, REGION_PLACES);

  // Another domain entirely. Blocked even if a material word appears, since
  // that is the shape a prompt-injection attempt takes.
  if (hitsAny(msg, OFF_DOMAIN)) {
    return { allow: false, reason: "off-domain", reply: REDIRECTS.offDomain };
  }

  // Construction, but a phase this tool does not cover. A message that also
  // names materials is let through, because "what tiles and how much do they
  // cost" is still worth answering for the material half.
  for (const rule of WRONG_PHASE) {
    if (hitsAny(msg, rule.keys) && !mentionsMaterial) {
      return { allow: false, reason: rule.phase, reply: REDIRECTS[rule.phase] };
    }
  }

  return { allow: true };
}

/** Peso amounts and price talk that should never appear in a reply. */
const PRICE_DRIFT = [/₱\s?\d/, /\bphp\s?\d/i, /\bpesos?\b/i, /\bper piece costs?\b/i];

/**
 * Runs after the model call. Catches a reply that drifted out of scope even
 * though the model reported `inScope: true`, and drops suggestions that are
 * not construction materials.
 */
function validateResult({ inScope, reply, suggestions }) {
  const text = String(reply || "");

  if (inScope && PRICE_DRIFT.some((re) => re.test(text))) {
    return {
      inScope: false,
      reply: REDIRECTS.pricing,
      suggestions: [],
      adjusted: "price-drift",
    };
  }

  // A suggestion has to read like a material. This is the same idea as the
  // app's own material classifier, kept deliberately loose so an unusual but
  // real product name is not thrown away.
  const kept = (Array.isArray(suggestions) ? suggestions : []).filter((s) => {
    const v = normalize(s);
    if (!v || v.length > 80) return false;
    return hitsAnyWord(v, MATERIAL_TERMS);
  });

  return {
    inScope,
    reply: text,
    suggestions: inScope ? kept : [],
    adjusted: kept.length !== (suggestions || []).length ? "filtered-suggestions" : null,
  };
}

module.exports = {
  preScreen,
  validateResult,
  REDIRECTS,
  // exported for tests
  MATERIAL_TERMS,
  REGION_PLACES,
  OFF_DOMAIN,
  WRONG_PHASE,
};
