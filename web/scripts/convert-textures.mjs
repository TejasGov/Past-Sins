// Converts the Godot project's JPG texture sets into WebP under public/textures.
// Run: npm run textures            (every set)
//      npm run textures -- metal   (only the named sets)
import { existsSync, mkdirSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import sharp from "sharp";

const source = resolve(import.meta.dirname, "../../textures");
const target = resolve(import.meta.dirname, "../public/textures");
const sets = ["concrete", "plaster", "metal", "steel", "iron", "asphalt", "road", "gravel", "grass",
  "court_concrete", "tiles", "tile_shower", "gym_rubber", "wood_furniture", "fence", "gunmetal"];

// Box props tint their albedo with a vertex colour, so each albedo needs a mid-grey mean.
// The painted-metal source averages ~30/255 and turned every locker, shelf and door black.
const ALBEDO_GAIN = { painted_metal_albedo: 4.8 };

const only = process.argv.slice(2);
mkdirSync(target, { recursive: true });
for (const set of sets) {
  if (only.length && !only.includes(set)) continue;
  const dir = join(source, set);
  if (!existsSync(dir)) continue;
  for (const file of readdirSync(dir)) {
    if (!file.endsWith(".jpg")) continue;
    const name = file.replace(".jpg", "");
    const isData = /normal|roughness|metalness|opacity/.test(file);
    const out = join(target, file.replace(/^painted_metal/, "metal").replace(".jpg", ".webp"));
    let img = sharp(join(dir, file)).resize({ width: 1024, withoutEnlargement: true });
    if (ALBEDO_GAIN[name]) img = img.linear(ALBEDO_GAIN[name], 0);
    await img.webp({ quality: isData ? 92 : 84 }).toFile(out);
    console.log("wrote", out);
  }
}
