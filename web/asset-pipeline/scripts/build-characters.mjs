#!/usr/bin/env node
// Builds web/public/assets/characters/guard.glb + manifest.json from the Mixamo
// FBX files in assets/characters/models_mixamo. Run: npm run build:characters
//
// 1. FBX2glTF (bundled macOS binary) converts every FBX to a temporary GLB.
//    FBX2glTF already converts Mixamo centimetres to metres and keeps Y-up.
// 2. The character GLB keeps its mesh + skin; its own bind-pose take is dropped.
// 3. Each animation GLB is merged onto the character skeleton by bone name
//    (the "mixamorig:" prefix variants are ignored when matching).
// 4. Hips X/Z root motion is removed (Y kept), see clips.config.mjs.
// 5. Materials are rebuilt for metal/rough from the original spec/gloss maps,
//    textures resized to webp, then dedup/prune/resample + meshopt compression.

import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import { existsSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS, EXTMeshoptCompression, EXTTextureWebP, KHRMeshQuantization } from '@gltf-transform/extensions';
import { dedup, getBounds, prune, quantize, reorder, resample } from '@gltf-transform/functions';
import { MeshoptDecoder, MeshoptEncoder } from 'meshoptimizer';
import sharp from 'sharp';
import validator from 'gltf-validator';

import { CHARACTER, CLIP_TABLE, OUTPUT_DIR, SOURCE_DIR, TEXTURES, defaultClipEntry } from './clips.config.mjs';

const PKG_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
// CHARACTERS_SRC / CHARACTERS_OUT override the folders (e.g. to test a new clip without touching the game copy).
const SRC = path.resolve(PKG_DIR, process.env.CHARACTERS_SRC ?? SOURCE_DIR);
const OUT = path.resolve(PKG_DIR, process.env.CHARACTERS_OUT ?? OUTPUT_DIR);
const CACHE = path.join(PKG_DIR, '.cache');
const REPORT = path.join(process.env.CHARACTERS_OUT ? OUT : path.join(PKG_DIR, 'out'), 'build-report.json');
const FBX2GLTF = path.join(PKG_DIR, 'node_modules', 'fbx2gltf', 'bin', os.type(), os.type() === 'Windows_NT' ? 'FBX2glTF.exe' : 'FBX2glTF');

const HIPS = 'Hips';
const EPS = 1e-4;

const stripRig = (name) => name.replace(/^mixamorig\d*[:_]/i, '');
const log = (...a) => console.log('[characters]', ...a);

// ---------------------------------------------------------------- FBX2glTF

function runFbx2gltf(input, outputNoExt, tempDir) {
  return new Promise((resolve, reject) => {
    const args = ['--binary', '--anim-framerate', 'bake30', '--fbx-temp-dir', tempDir, '--input', input, '--output', outputNoExt];
    const child = spawn(FBX2GLTF, args);
    let output = '';
    child.stdout.on('data', (d) => (output += d));
    child.stderr.on('data', (d) => (output += d));
    child.on('error', reject);
    child.on('close', (code) => {
      if (code !== 0 || !existsSync(outputNoExt + '.glb')) reject(new Error(`FBX2glTF failed on ${input}:\n${output}`));
      else resolve({ glb: outputNoExt + '.glb', log: output });
    });
  });
}

async function convertAll(files) {
  await fs.rm(CACHE, { recursive: true, force: true });
  await fs.mkdir(path.join(CACHE, 'fbx-temp'), { recursive: true });
  const results = new Map();
  const queue = [...files];
  const workers = Array.from({ length: Math.min(4, os.cpus().length) }, async () => {
    while (queue.length) {
      const file = queue.shift();
      const base = path.basename(file, path.extname(file));
      const tempDir = path.join(CACHE, 'fbx-temp', base.replace(/\W+/g, '_'));
      await fs.mkdir(tempDir, { recursive: true });
      const res = await runFbx2gltf(path.join(SRC, file), path.join(CACHE, base.replace(/\W+/g, '_')), tempDir);
      results.set(file, { ...res, tempDir });
    }
  });
  await Promise.all(workers);
  return results;
}

async function findInTemp(dir, filename) {
  for (const entry of await fs.readdir(dir, { withFileTypes: true, recursive: true })) {
    if (entry.isFile() && entry.name === filename) return path.join(entry.parentPath ?? entry.path, entry.name);
  }
  return null;
}

// ---------------------------------------------------------------- clips

function pickAnimation(doc) {
  const anims = doc.getRoot().listAnimations().filter((a) => a.listChannels().length > 0);
  anims.sort((a, b) => b.listChannels().length - a.listChannels().length);
  return anims[0] ?? null;
}

function vecDiff(a, b) {
  return Math.max(...a.map((v, i) => Math.abs(v - b[i])));
}

function quatDiff(a, b) {
  // q and -q are the same rotation
  const dot = Math.abs(a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]);
  return 1 - Math.min(1, dot);
}

function stripRootMotion(times, values, mode) {
  const n = times.length;
  const t0 = times[0];
  const span = times[n - 1] - t0 || 1;
  const first = [values[0], values[2]];
  const last = [values[(n - 1) * 3], values[(n - 1) * 3 + 2]];
  const drift = [last[0] - first[0], last[1] - first[1]];
  let maxResidual = 0;
  for (let i = 0; i < n; i++) {
    if (mode === 'linear') {
      const k = (times[i] - t0) / span;
      values[i * 3] -= drift[0] * k;
      values[i * 3 + 2] -= drift[1] * k;
    } else {
      values[i * 3] = first[0];
      values[i * 3 + 2] = first[1];
    }
    maxResidual = Math.max(maxResidual, Math.hypot(values[i * 3] - first[0], values[i * 3 + 2] - first[1]));
  }
  return { drift, maxResidual };
}

function mergeClip(charDoc, joints, animDoc, clip, report) {
  const src = pickAnimation(animDoc);
  if (!src) throw new Error(`${clip.file}: no animation with channels`);

  const buffer = charDoc.getRoot().listBuffers()[0];
  const animNodes = new Map(animDoc.getRoot().listNodes().map((n) => [stripRig(n.getName()), n]));
  const anim = charDoc.createAnimation(clip.name);
  const accessorCopies = new Map();
  let tMin = Infinity;
  let tMax = -Infinity;
  for (const ch of src.listChannels()) {
    const input = ch.getSampler().getInput().getArray();
    tMin = Math.min(tMin, input[0]);
    tMax = Math.max(tMax, input[input.length - 1]);
  }

  const copyAccessor = (acc, isInput) => {
    if (accessorCopies.has(acc)) return accessorCopies.get(acc);
    let array = acc.getArray().slice();
    if (isInput) array = array.map((t) => t - tMin);
    const copy = charDoc.createAccessor().setType(acc.getType()).setArray(array).setBuffer(buffer);
    accessorCopies.set(acc, copy);
    return copy;
  };

  const keyed = new Set();
  const unmatched = new Set();
  const clipReport = { file: clip.file, sourceTake: src.getName(), loop: clip.loop };

  for (const ch of src.listChannels()) {
    const animNode = ch.getTargetNode();
    const bone = stripRig(animNode.getName());
    const target = joints.get(bone);
    const pathName = ch.getTargetPath();
    if (!target) {
      unmatched.add(animNode.getName());
      continue;
    }
    // Keep the character's own bone lengths: only the hips may translate.
    if (pathName === 'translation' && bone !== HIPS) continue;
    if (pathName === 'scale') {
      const out = ch.getSampler().getOutput().getArray();
      if (out.every((v) => Math.abs(v - 1) < EPS)) continue;
    }

    const sampler = ch.getSampler();
    const input = copyAccessor(sampler.getInput(), true);
    const output = charDoc.createAccessor()
      .setType(sampler.getOutput().getType())
      .setArray(sampler.getOutput().getArray().slice())
      .setBuffer(buffer);

    if (bone === HIPS && pathName === 'translation') {
      const restY = animNode.getTranslation()[1];
      const charY = target.getTranslation()[1];
      const scale = Math.abs(restY / charY - 1) > 0.02 ? charY / restY : 1;
      const values = output.getArray();
      if (scale !== 1) for (let i = 0; i < values.length; i++) values[i] *= scale;
      const times = input.getArray();
      const { drift, maxResidual } = stripRootMotion(times, values, clip.root);
      const duration = times[times.length - 1];
      clipReport.hipsScale = +scale.toFixed(4);
      clipReport.rootMode = clip.root;
      clipReport.rootTravelRemoved = drift.map((v) => +v.toFixed(3));
      clipReport.rootSpeed = clip.root === 'linear' && duration > 0 ? +(Math.hypot(...drift) / duration).toFixed(3) : 0;
      clipReport.hipsMaxXZExcursionAfterStrip = +maxResidual.toFixed(3);
      const ys = [];
      for (let i = 1; i < values.length; i += 3) ys.push(values[i]);
      clipReport.hipsY = [+Math.min(...ys).toFixed(3), +Math.max(...ys).toFixed(3)];
      output.setArray(values);
    }

    const newSampler = charDoc.createAnimationSampler().setInput(input).setOutput(output).setInterpolation(sampler.getInterpolation());
    anim.addSampler(newSampler).addChannel(
      charDoc.createAnimationChannel().setTargetNode(target).setTargetPath(pathName).setSampler(newSampler),
    );
    keyed.add(`${bone}/${pathName}`);
  }

  // Bones FBX2glTF left unkeyed (held at the clip file's rest pose) get a
  // constant rotation key when that pose differs from the character's rest.
  let constantKeys = 0;
  const time0 = charDoc.createAccessor().setType('SCALAR').setArray(new Float32Array([0])).setBuffer(buffer);
  for (const [bone, target] of joints) {
    if (keyed.has(`${bone}/rotation`)) continue;
    const animNode = animNodes.get(bone);
    if (!animNode) continue;
    const r = animNode.getRotation();
    if (quatDiff(r, target.getRotation()) < 1e-6) continue;
    const out = charDoc.createAccessor().setType('VEC4').setArray(new Float32Array(r)).setBuffer(buffer);
    const s = charDoc.createAnimationSampler().setInput(time0).setOutput(out).setInterpolation('STEP');
    anim.addSampler(s).addChannel(charDoc.createAnimationChannel().setTargetNode(target).setTargetPath('rotation').setSampler(s));
    constantKeys++;
  }
  if (constantKeys === 0) time0.dispose();

  const missingBones = [...joints.keys()].filter((b) => !animNodes.has(b));
  const restOffsets = [];
  for (const [bone, target] of joints) {
    const animNode = animNodes.get(bone);
    if (!animNode || bone === HIPS) continue;
    const d = vecDiff(animNode.getTranslation(), target.getTranslation());
    if (d > 0.002) restOffsets.push(`${bone}:${(d * 100).toFixed(1)}cm`);
  }

  clipReport.duration = +(tMax - tMin).toFixed(4);
  clipReport.channels = anim.listChannels().length;
  clipReport.constantRotationKeys = constantKeys;
  clipReport.unmatchedBones = [...unmatched];
  clipReport.bonesMissingFromClip = missingBones;
  clipReport.boneLengthDifferences = restOffsets;
  clipReport.prefixes = [...new Set(animDoc.getRoot().listNodes().map((n) => (n.getName().match(/^(mixamorig\d*[:_])/i) || [, ''])[1]))].filter(Boolean);
  report.clips[clip.name] = clipReport;
}

// ---------------------------------------------------------------- materials

async function encodeWebp(input, { maxSize, quality, negate = false, greyscale = false }) {
  let img = sharp(input, { limitInputPixels: false });
  if (greyscale) img = img.greyscale();
  if (negate) img = img.negate({ alpha: false });
  const meta = await img.metadata();
  if (Math.max(meta.width, meta.height) > maxSize) img = img.resize(maxSize, maxSize, { fit: 'inside', kernel: 'lanczos3' });
  return img.webp({ quality, effort: 6, smartSubsample: true }).toBuffer({ resolveWithObject: true });
}

async function rebuildMaterials(doc, charTempDir, report) {
  doc.createExtension(EXTTextureWebP).setRequired(true);
  const { maxSize, quality } = TEXTURES;
  const done = new Set();
  report.textures = [];

  const encodeTexture = async (texture, label, opts) => {
    if (!texture || done.has(texture)) return;
    done.add(texture);
    const { data, info } = await encodeWebp(Buffer.from(texture.getImage()), { maxSize, ...opts });
    const name = label;
    texture.setImage(new Uint8Array(data)).setMimeType('image/webp').setURI(`${name}.webp`).setName(name);
    report.textures.push({ name, size: `${info.width}x${info.height}`, kb: +(data.length / 1024).toFixed(1) });
  };

  for (const mat of doc.getRoot().listMaterials()) {
    const base = mat.getBaseColorTexture();
    const stem = (base?.getName() || base?.getURI() || mat.getName()).replace(/_Diffuse.*$/i, '').replace(/\.\w+$/, '');

    // Mixamo "nonPBR" = diffuse/specular/glossiness. Specular is a flat ~4%
    // dielectric value, so metal/rough with metallic 0 and roughness = 1 - gloss.
    mat.setBaseColorFactor([1, 1, 1, 1]).setMetallicFactor(0).setRoughnessFactor(1).setEmissiveFactor([0, 0, 0]);
    mat.setMetallicRoughnessTexture(null); // FBX2glTF's JPEG ORM guess; prune() drops it

    const glossPath = await findInTemp(charTempDir, `${stem}_Glossiness.png`);
    if (glossPath) {
      const rough = doc.createTexture(`${stem}_Roughness`).setImage(new Uint8Array(await fs.readFile(glossPath))).setMimeType('image/png');
      mat.setMetallicRoughnessTexture(rough);
      await encodeTexture(rough, `${stem}_Roughness`, { quality: quality.roughness, greyscale: true, negate: true });
    } else {
      mat.setRoughnessFactor(0.8);
      report.warnings.push(`${mat.getName()}: no ${stem}_Glossiness.png found, using roughness 0.8`);
    }
    await encodeTexture(base, `${stem}_BaseColor`, { quality: quality.baseColor });
    await encodeTexture(mat.getNormalTexture(), `${stem}_Normal`, { quality: quality.normal });
    report.materials = report.materials || [];
    report.materials.push({ name: mat.getName(), stem, roughnessFrom: glossPath ? path.basename(glossPath) : null });
  }
}

// ---------------------------------------------------------------- main

async function main() {
  const started = Date.now();
  if (!existsSync(FBX2GLTF)) throw new Error(`FBX2glTF binary not found at ${FBX2GLTF} (npm install?)`);
  const files = (await fs.readdir(SRC)).filter((f) => /\.fbx$/i.test(f)).sort();
  if (!files.includes(CHARACTER.source)) throw new Error(`${CHARACTER.source} not found in ${SRC}`);

  const clips = files
    .filter((f) => f !== CHARACTER.source)
    .map((file) => {
      const base = path.basename(file, path.extname(file));
      const entry = CLIP_TABLE[base] ?? defaultClipEntry(base);
      return { file, base, root: entry.loop ? 'linear' : 'pin', ...entry, fromTable: Boolean(CLIP_TABLE[base]) };
    });
  // Table order first (so manifest.json reads idle, walk, run…), new files after.
  const order = Object.keys(CLIP_TABLE);
  const rank = (c) => (c.fromTable ? order.indexOf(c.base) : order.length);
  clips.sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name));
  const dupes = clips.map((c) => c.name).filter((n, i, a) => a.indexOf(n) !== i);
  if (dupes.length) throw new Error(`Duplicate normalized clip names: ${dupes.join(', ')}`);

  log(`converting ${files.length} FBX files with FBX2glTF…`);
  const converted = await convertAll(files);

  await MeshoptEncoder.ready;
  await MeshoptDecoder.ready;
  const io = new NodeIO()
    .registerExtensions(ALL_EXTENSIONS)
    .registerDependencies({ 'meshopt.encoder': MeshoptEncoder, 'meshopt.decoder': MeshoptDecoder });

  const report = { generatedAt: new Date().toISOString(), source: path.relative(PKG_DIR, SRC), clips: {}, warnings: [] };

  // Character
  const charConv = converted.get(CHARACTER.source);
  const doc = await io.read(charConv.glb);
  const root = doc.getRoot();
  // Drop the character file's own bind-pose take (samplers hold its accessors).
  for (const a of root.listAnimations()) {
    for (const c of a.listChannels()) c.dispose();
    for (const smp of a.listSamplers()) smp.dispose();
    a.dispose();
  }
  const skins = root.listSkins();
  const meshes = root.listMeshes();
  if (skins.length !== 1 || meshes.length !== 1) throw new Error(`expected 1 skin + 1 mesh, got ${skins.length} skins / ${meshes.length} meshes`);
  const joints = new Map(skins[0].listJoints().map((j) => [stripRig(j.getName()), j]));
  if (!joints.has(HIPS)) throw new Error('character skeleton has no Hips joint');
  report.character = { file: CHARACTER.source, joints: joints.size, jointPrefix: skins[0].listJoints()[0].getName().replace(/Hips$/, '') };

  // FBX2glTF wraps everything in an identity "RootNode"; lift its children to
  // the scene so the skinned mesh node is a root node (glTF best practice).
  const scene = root.listScenes()[0].setName(CHARACTER.rootName);
  for (const wrapper of scene.listChildren()) {
    const identity = wrapper.getTranslation().every((v) => v === 0) && wrapper.getRotation().every((v, i) => v === (i === 3 ? 1 : 0)) && wrapper.getScale().every((v) => v === 1);
    if (wrapper.getName() !== 'RootNode' || !identity || wrapper.getMesh()) continue;
    for (const child of wrapper.listChildren()) {
      wrapper.removeChild(child);
      scene.addChild(child);
    }
    scene.removeChild(wrapper);
    wrapper.dispose();
  }
  meshes[0].setName(CHARACTER.rootName);

  // Clips
  for (const clip of clips) {
    const animDoc = await io.read(converted.get(clip.file).glb);
    mergeClip(doc, joints, animDoc, clip, report);
    const r = report.clips[clip.name];
    const flags = [
      r.unmatchedBones.length ? `${r.unmatchedBones.length} unmatched` : null,
      r.bonesMissingFromClip.length ? `${r.bonesMissingFromClip.length} bones missing` : null,
      r.boneLengthDifferences.length ? `${r.boneLengthDifferences.length} bone length diffs` : null,
    ].filter(Boolean);
    log(`clip ${clip.name.padEnd(20)} ← ${clip.file.padEnd(32)} ${r.duration.toFixed(2)}s  ${(clip.loop ? 'loop' : 'once').padEnd(4)} root ${clip.root.padEnd(6)} travel [${r.rootTravelRemoved}]  ${flags.join(', ') || 'bones match'}`);
    if (!clip.fromTable) report.warnings.push(`${clip.file} not in CLIP_TABLE; using "${clip.name}" (loop=${clip.loop})`);
    if (flags.length) report.warnings.push(`${clip.name}: ${flags.join(', ')}`);
  }

  await rebuildMaterials(doc, charConv.tempDir, report);

  // Geometry facts (bind pose, metres)
  const bounds = getBounds(scene);
  const height = bounds.max[1] - bounds.min[1];
  report.bounds = { min: bounds.min.map((v) => +v.toFixed(4)), max: bounds.max.map((v) => +v.toFixed(4)), height: +height.toFixed(4) };
  if (Math.abs(bounds.min[1]) > 0.01) report.warnings.push(`feet not at origin: min.y = ${bounds.min[1].toFixed(4)}`);
  if (height < 1.5 || height > 2.1) report.warnings.push(`unexpected height ${height.toFixed(3)} m (unit conversion?)`);

  await doc.transform(
    dedup(),
    prune({ keepLeaves: true }),
    resample({ tolerance: 1e-4 }),
    prune({ keepLeaves: true }),
    reorder({ encoder: MeshoptEncoder, target: 'size' }),
    // POSITION stays float on purpose: quantizing a skinned mesh folds the
    // dequantization transform into the inverse bind matrices, after which
    // Skeleton.pose() (and anything trusting the IBMs) collapses the body.
    quantize({ pattern: /^(TEXCOORD|JOINTS|WEIGHTS|COLOR)(_\d+)?$/, quantizeTexcoord: 12, quantizeWeight: 8 }),
  );
  // FILTER: octahedral normals, 16-bit quaternion + exponential translation
  // filters on animation data, everything meshopt-compressed.
  doc.createExtension(EXTMeshoptCompression).setRequired(true).setEncoderOptions({ method: EXTMeshoptCompression.EncoderMethod.FILTER });
  // The octahedral filter stores NORMAL as normalized int8.
  doc.createExtension(KHRMeshQuantization).setRequired(true);

  await fs.mkdir(OUT, { recursive: true });
  const glbPath = path.join(OUT, CHARACTER.output);
  await io.write(glbPath, doc);
  const glbSize = (await fs.stat(glbPath)).size;

  const validation = await validator.validateBytes(new Uint8Array(await fs.readFile(glbPath)), { maxIssues: 50 });
  const { numErrors, numWarnings, numInfos, messages } = validation.issues;
  report.validation = { errors: numErrors, warnings: numWarnings, infos: numInfos, messages: messages.map((m) => `${m.severity === 0 ? 'ERROR' : m.severity === 1 ? 'WARN' : 'info'} ${m.code}: ${m.message} ${m.pointer ?? ''}`) };
  log(`glTF validator: ${numErrors} errors, ${numWarnings} warnings, ${numInfos} infos`);
  if (numErrors) {
    for (const m of report.validation.messages) log(m);
    throw new Error('guard.glb failed glTF validation');
  }

  const manifest = {
    model: CHARACTER.output,
    heightMeters: +height.toFixed(3),
    forward: '+Z',
    up: '+Y',
    compression: 'meshopt',
    clips: Object.fromEntries(clips.map((c) => [c.name, c.name])),
    // Extra, optional: per-clip facts for the game. rootSpeed is the speed (m/s)
    // the clip was authored at before root motion was removed: move the guard
    // at that speed (or scale timeScale) to avoid foot sliding. rootTravel is
    // the removed hips X/Z offset over the whole clip.
    clipInfo: Object.fromEntries(clips.map((c) => {
      const r = report.clips[c.name];
      const info = { loop: c.loop, duration: r.duration, rootSpeed: r.rootSpeed ?? 0, rootTravel: r.rootTravelRemoved ?? [0, 0] };
      if (c.note) info.note = c.note.replace('rootSpeed', String(info.rootSpeed));
      return [c.name, info];
    })),
  };
  await fs.writeFile(path.join(OUT, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');

  report.output = { glb: path.relative(PKG_DIR, glbPath), bytes: glbSize, mb: +(glbSize / 1048576).toFixed(2) };
  report.seconds = +((Date.now() - started) / 1000).toFixed(1);
  await fs.mkdir(path.dirname(REPORT), { recursive: true });
  await fs.writeFile(REPORT, JSON.stringify(report, null, 2) + '\n');

  log(`wrote ${path.relative(PKG_DIR, glbPath)} (${report.output.mb} MB), manifest.json with ${clips.length} clips, height ${height.toFixed(3)} m`);
  for (const w of report.warnings) log(`warning: ${w}`);
  log(`report: ${path.relative(PKG_DIR, REPORT)}  (${report.seconds}s)`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
