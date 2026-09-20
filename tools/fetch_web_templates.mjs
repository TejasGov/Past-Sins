// Tooling only: fetch just the two Web templates from the official multi-platform
// ZIP via HTTP ranges. No downloaded assets enter the game repository.
import { mkdir, writeFile } from 'node:fs/promises';
import { inflateRawSync } from 'node:zlib';
import { join } from 'node:path';

const target = process.argv[2];
if (!target || !target.endsWith('/4.7.2.stable')) throw new Error('Pass the explicit Godot 4.7.2 template directory');
const url = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz';
const head = await fetch(url, {method: 'HEAD'});
if (!head.ok) throw new Error(`Official release unavailable: ${head.status}`);
const length = Number(head.headers.get('content-length'));
async function range(start, end) {
  const response = await fetch(head.url, {headers: {Range: `bytes=${start}-${end}`}});
  if (response.status !== 206) throw new Error('Server did not honor partial download; refusing full archive');
  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length !== end - start + 1) throw new Error('Truncated archive range');
  return bytes;
}
const tail = await range(length - 65557, length - 1);
const eocd = tail.lastIndexOf(Buffer.from([0x50,0x4b,0x05,0x06]));
if(eocd < 0) throw new Error('ZIP end record missing');
const directorySize = tail.readUInt32LE(eocd + 12);
const directoryOffset = tail.readUInt32LE(eocd + 16);
const directory = await range(directoryOffset, directoryOffset + directorySize - 1);
const wanted = new Set(['web_nothreads_debug.zip','web_nothreads_release.zip']);
await mkdir(target, {recursive: true});
for (let offset = 0; offset < directory.length;) {
  if(directory.readUInt32LE(offset) !== 0x02014b50) throw new Error('Invalid ZIP directory');
  const nameLength=directory.readUInt16LE(offset+28), extraLength=directory.readUInt16LE(offset+30), commentLength=directory.readUInt16LE(offset+32);
  const name=directory.subarray(offset+46,offset+46+nameLength).toString();
  const basename=name.split('/').pop();
  if(wanted.has(basename)) {
    const compressedSize=directory.readUInt32LE(offset+20), expectedSize=directory.readUInt32LE(offset+24), method=directory.readUInt16LE(offset+10);
    const localOffset=directory.readUInt32LE(offset+42);
    const header=await range(localOffset,localOffset+29);
    const start=localOffset+30+header.readUInt16LE(26)+header.readUInt16LE(28);
    console.log(`Downloading ${basename}: ${(compressedSize/1048576).toFixed(1)} MiB`);
    const payload=await range(start,start+compressedSize-1);
    const bytes=method===8?inflateRawSync(payload):payload;
    if(bytes.length!==expectedSize) throw new Error('Template length mismatch');
    let crc=0xffffffff;
    for(const byte of bytes) { crc ^= byte; for(let i=0;i<8;i++) crc=(crc>>>1)^((crc&1)?0xedb88320:0); }
    if(((crc^0xffffffff)>>>0)!==directory.readUInt32LE(offset+16)) throw new Error('Template CRC mismatch');
    await writeFile(join(target,basename), bytes, {flag:'wx'});
    wanted.delete(basename);
  }
  offset+=46+nameLength+extraLength+commentLength;
}
if(wanted.size) throw new Error(`Missing templates: ${[...wanted]}`);
console.log('Matching Web templates installed; other platforms were not downloaded.');
