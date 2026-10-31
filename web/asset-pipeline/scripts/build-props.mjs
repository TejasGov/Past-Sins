// Builds web/public/assets/props/<id>.glb + manifest.json from the Poly Haven
// glTFs fetched by fetch-polyhaven.mjs: merged and welded meshes, simplified
// to each prop's triangle budget, origin at floor contact (bottom centre),
// WebP textures and meshopt compression.
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { NodeIO } from "@gltf-transform/core";
import { ALL_EXTENSIONS, EXTMeshoptCompression } from "@gltf-transform/extensions";
import { center, dedup, flatten, getBounds, join, prune, quantize, simplify, textureCompress, weld } from "@gltf-transform/functions";
import { MeshoptDecoder, MeshoptEncoder, MeshoptSimplifier } from "meshoptimizer";
import sharp from "sharp";
import { PROPS, SMALL_PROP_METRES, SMALL_TEXTURE_SIZE, TEXTURE_SIZE } from "./props.config.mjs";

const PKG = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SOURCE = path.join(PKG, ".cache", "polyhaven");
const OUT = path.resolve(PKG, "..", "public", "assets", "props");

await MeshoptSimplifier.ready;
await MeshoptEncoder.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ "meshopt.encoder": MeshoptEncoder, "meshopt.decoder": MeshoptDecoder });

function triangles(doc) {
  let n = 0;
  for (const mesh of doc.getRoot().listMeshes())
    for (const prim of mesh.listPrimitives()) n += (prim.getIndices()?.getCount() ?? prim.getAttribute("POSITION").getCount()) / 3;
  return Math.round(n);
}

await fs.mkdir(OUT, { recursive: true });
const manifest = { source: "Poly Haven (CC0)", props: {} };
let totalBytes = 0;

const only = process.argv.slice(2);
for (const { id, tris: budget, nodes: keep } of PROPS) {
  if (only.length && !only.includes(id)) continue;
  const doc = await io.read(path.join(SOURCE, id, `${id}.gltf`));
  if (keep) {
    const root = doc.getRoot();
    const sceneNodes = (root.getDefaultScene() ?? root.listScenes()[0]).listChildren();
    const missing = keep.filter((name) => !sceneNodes.some((n) => n.getName() === name));
    if (missing.length) throw new Error(`${id}: no root node named ${missing.join(", ")}`);
    for (const n of sceneNodes) {
      if (keep.includes(n.getName())) n.setTranslation([0, 0, 0]);
      else n.dispose();
    }
    await doc.transform(prune());
  }
  const before = triangles(doc);
  await doc.transform(dedup(), flatten(), join(), weld());
  const welded = triangles(doc);
  if (welded > budget) await doc.transform(simplify({ simplifier: MeshoptSimplifier, ratio: budget / welded, error: 0.06 }));
  await doc.transform(center({ pivot: "below" }));
  const scene = doc.getRoot().getDefaultScene() ?? doc.getRoot().listScenes()[0];
  const { min, max } = getBounds(scene);
  const size = max.map((v, i) => +(v - min[i]).toFixed(3));
  const longest = Math.max(...size);
  const res = longest < SMALL_PROP_METRES ? SMALL_TEXTURE_SIZE : TEXTURE_SIZE;
  await doc.transform(
    textureCompress({ encoder: sharp, targetFormat: "webp", resize: [res, res], quality: 82 }),
    prune(),
    quantize(),
  );
  doc.createExtension(EXTMeshoptCompression).setRequired(true).setEncoderOptions({ method: EXTMeshoptCompression.EncoderMethod.FILTER });
  const file = `${id}.glb`;
  await io.write(path.join(OUT, file), doc);
  const bytes = (await fs.stat(path.join(OUT, file))).size;
  totalBytes += bytes;
  const after = triangles(doc);
  const emissive = doc.getRoot().listMaterials().some((m) => m.getEmissiveTexture() || m.getEmissiveFactor().some((c) => c > 0));
  manifest.props[id] = { file, size, tris: after, emissive };
  console.log(`${id.padEnd(30)} ${String(before).padStart(6)} → ${String(after).padStart(5)} tris  ${size.join("×")} m  ${(bytes / 1024).toFixed(0)} KB${emissive ? "  emissive" : ""}`);
}

if (only.length) {
  const prev = JSON.parse(await fs.readFile(path.join(OUT, "manifest.json"), "utf8"));
  manifest.props = { ...prev.props, ...manifest.props };
}
await fs.writeFile(path.join(OUT, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
console.log(`\n${PROPS.length} props, ${(totalBytes / 1048576).toFixed(1)} MB → ${path.relative(process.cwd(), OUT)}`);
