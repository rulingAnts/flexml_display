#!/usr/bin/env node
// Generate macOS .icns and Windows .ico from a single SVG using sharp + iconutil
// Requirements: Node 18+, macOS (for iconutil), and `sharp` installed (we install locally via npm script)

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import child_process from 'node:child_process';
import util from 'node:util';

const exec = util.promisify(child_process.exec);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const ROOT = path.resolve(__dirname, '..');
const ASSETS = path.join(ROOT, 'assets');
const ICON_SVG = path.join(ASSETS, 'icon.svg');
const ICONSET_DIR = path.join(ASSETS, 'app.iconset');
const ICON_ICNS = path.join(ASSETS, 'icon.icns');
const ICON_ICO = path.join(ASSETS, 'icon.ico');
const ICON_PNG = path.join(ASSETS, 'icon.png');

async function ensureSharp(){
  try{
    const { default: sharp } = await import('sharp');
    return sharp;
  }catch(e){
    throw new Error('sharp is not installed. Run: npm i -D sharp');
  }
}

async function rimraf(p){ await fs.rm(p, { recursive:true, force:true }); }
async function mkdirp(p){ await fs.mkdir(p, { recursive:true }); }

async function renderPngs(sharpLib){
  const sizes = [16,32,64,128,256,512,1024];
  await mkdirp(ICONSET_DIR);
  for(const size of sizes){
    const base = path.join(ICONSET_DIR, `icon_${size}x${size}.png`);
    const scale2 = path.join(ICONSET_DIR, `icon_${size}x${size}@2x.png`);
    const img = sharpLib(ICON_SVG);
    await img.resize(size, size, { fit:'contain' }).png().toFile(base);
    await img.resize(size*2, size*2, { fit:'contain' }).png().toFile(scale2);
  }
  // Also emit a top-level PNG for Linux and dev BrowserWindow (256px)
  await sharpLib(ICON_SVG).resize(256, 256, { fit:'contain' }).png().toFile(ICON_PNG);
}

async function buildIcns(){
  // macOS tool: iconutil converts .iconset -> .icns
  try{
    await exec(`iconutil -c icns "${ICONSET_DIR}" -o "${ICON_ICNS}"`);
  }catch(e){
    throw new Error('Failed to run iconutil. Are you on macOS? ' + (e?.stderr || e?.message));
  }
}

async function buildIco(sharpLib){
  // Build multi-size ICO (for parity and Windows builds)
  const sizes = [16,24,32,48,64,128,256];
  const pngBuffers = [];
  for(const s of sizes){
    const buf = await sharpLib(ICON_SVG).resize(s, s).png().toBuffer();
    pngBuffers.push(buf);
  }
  // Lazy import to avoid extra dep when not needed
  let toIco;
  try{
    ({ default: toIco } = await import('to-ico'));
  }catch(_){
    throw new Error('to-ico is not installed. Run: npm i -D to-ico');
  }
  const ico = await toIco(pngBuffers);
  await fs.writeFile(ICON_ICO, ico);
}

async function main(){
  const sharp = await ensureSharp();
  try{
    await rimraf(ICONSET_DIR);
    await mkdirp(ASSETS);
    // Clean older one-off PNG sizes to "start from scratch"
    const stale = await fs.readdir(ASSETS);
    await Promise.all(
      stale
        .filter(f=> /^icon-(16|32|48|64|128|256)\.png$/i.test(f))
        .map(f=> fs.rm(path.join(ASSETS, f)).catch(()=>{}))
    );
    // Remove previous outputs so builder can't pick stale files
    await Promise.all([
      fs.rm(ICON_ICNS, { force:true }).catch(()=>{}),
      fs.rm(ICON_ICO, { force:true }).catch(()=>{}),
      fs.rm(ICON_PNG, { force:true }).catch(()=>{})
    ]);
    await renderPngs(sharp);
    await buildIcns();
    await buildIco(sharp);
    console.log('Icons generated:', ICON_ICNS, ICON_ICO);
  }catch(err){
    console.error('Icon generation failed:', err.message);
    process.exitCode = 1;
  }finally{
    await rimraf(ICONSET_DIR); // cleanup iconset folder
  }
}

main();
