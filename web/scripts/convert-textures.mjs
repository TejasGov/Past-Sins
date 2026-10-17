// Converts the Godot project's JPG texture sets into WebP under public/textures.
// Requires `cwebp` on PATH (brew install webp). Run: npm run textures
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";

const source = resolve(import.meta.dirname, "../../textures");
const target = resolve(import.meta.dirname, "../public/textures");
const sets = ["concrete", "plaster", "metal", "steel", "iron", "asphalt", "road", "gravel", "grass",
  "court_concrete", "tiles", "tile_shower", "gym_rubber", "wood_furniture", "fence", "gunmetal"];

mkdirSync(target, { recursive: true });
for (const set of sets) {
  const dir = join(source, set);
  if (!existsSync(dir)) continue;
  for (const file of readdirSync(dir)) {
    if (!file.endsWith(".jpg")) continue;
    const isData = /normal|roughness|metalness|opacity/.test(file);
    const out = join(target, file.replace(/^painted_metal/, "metal").replace(".jpg", ".webp"));
    execFileSync("cwebp", ["-quiet", "-q", isData ? "92" : "84", "-resize", "1024", "0", join(dir, file), "-o", out]);
    console.log("wrote", out);
  }
}
