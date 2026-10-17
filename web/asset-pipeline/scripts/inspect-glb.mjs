#!/usr/bin/env node
// Prints the structure of a built character GLB: node tree root, skin, mesh
// primitives, materials/textures and every clip. Usage: node scripts/inspect-glb.mjs <file.glb>
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { MeshoptDecoder } from 'meshoptimizer';
import { fileURLToPath } from 'node:url';

const file = process.argv[2] ?? fileURLToPath(new URL('../../public/assets/characters/guard.glb', import.meta.url));
await MeshoptDecoder.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.decoder': MeshoptDecoder });
const doc = await io.read(file);
const root = doc.getRoot();
const count = (l) => l.length;
console.log(file);
console.log(`scenes ${count(root.listScenes())}  nodes ${count(root.listNodes())}  meshes ${count(root.listMeshes())}  skins ${count(root.listSkins())}  materials ${count(root.listMaterials())}  textures ${count(root.listTextures())}  animations ${count(root.listAnimations())}`);
console.log('extensions:', root.listExtensionsUsed().map((e) => e.extensionName + (e.isRequired() ? '*' : '')).join(' '));
for (const n of root.listScenes()[0].listChildren()) {
  console.log(`root node "${n.getName()}"  children: ${n.listChildren().map((c) => c.getName() + (c.getMesh() ? ' [mesh]' : '') + (c.getSkin() ? ' [skin]' : '')).join(', ')}`);
}
for (const s of root.listSkins()) console.log(`skin: ${s.listJoints().length} joints, skeleton ${s.getSkeleton()?.getName()}, used by ${s.listParents().filter((p) => p.propertyType === 'Node').map((p) => p.getName())}`);
for (const m of root.listMeshes()) for (const p of m.listPrimitives()) {
  const pos = p.getAttribute('POSITION');
  console.log(`prim ${m.getName()} verts ${pos.getCount()} tris ${p.getIndices().getCount() / 3} attrs ${p.listSemantics().map((s) => `${s}:${p.getAttribute(s).getComponentType()}${p.getAttribute(s).getNormalized() ? 'n' : ''}`).join(' ')}  material ${p.getMaterial()?.getName()}`);
}
for (const m of root.listMaterials()) console.log(`material ${m.getName()}: base ${m.getBaseColorTexture()?.getName()} normal ${m.getNormalTexture()?.getName()} mr ${m.getMetallicRoughnessTexture()?.getName()} metallic ${m.getMetallicFactor()} roughness ${m.getRoughnessFactor()} baseFactor ${m.getBaseColorFactor()}`);
for (const t of root.listTextures()) console.log(`texture ${t.getName()} ${t.getMimeType()} ${(t.getImage().byteLength / 1024).toFixed(0)} KB ${t.getSize()}`);
for (const a of root.listAnimations()) {
  const ch = a.listChannels();
  const dur = Math.max(...ch.map((c) => c.getSampler().getInput().getMax([])[0]));
  const keys = ch.reduce((s, c) => s + c.getSampler().getInput().getCount(), 0);
  console.log(`clip ${a.getName().padEnd(20)} ${dur.toFixed(2)}s  channels ${ch.length}  keys ${keys}`);
}
