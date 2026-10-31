// Downloads the 1K glTF of every prop in props.config.mjs from Poly Haven into
// .cache/polyhaven/<id>/ (git-ignored). Re-runs skip files already present.
import { mkdir, stat, writeFile } from "node:fs/promises";
import { dirname, join, normalize, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { PROPS } from "./props.config.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", ".cache", "polyhaven");
const headers = { "User-Agent": "PastSins-asset-pipeline/0.1" };

async function exists(p) {
  try {
    await stat(p);
    return true;
  } catch {
    return false;
  }
}

async function download(url, to) {
  if (await exists(to)) return false;
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`${res.status} ${url}`);
  await mkdir(dirname(to), { recursive: true });
  await writeFile(to, Buffer.from(await res.arrayBuffer()));
  return true;
}

for (const { id } of PROPS) {
  const files = await (await fetch(`https://api.polyhaven.com/files/${id}`, { headers })).json();
  const gltf = files.gltf?.["1k"]?.gltf;
  if (!gltf) throw new Error(`${id}: no 1k glTF on Poly Haven`);
  const dir = join(root, id);
  let fetched = 0;
  if (await download(gltf.url, join(dir, `${id}.gltf`))) fetched++;
  for (const [rel, file] of Object.entries(gltf.include ?? {})) {
    const target = normalize(join(dir, rel));
    if (!target.startsWith(dir + sep)) throw new Error(`${id}: refusing path outside its folder: ${rel}`);
    if (await download(file.url, target)) fetched++;
  }
  console.log(`${id}: ${fetched ? `${fetched} files downloaded` : "cached"}`);
}
