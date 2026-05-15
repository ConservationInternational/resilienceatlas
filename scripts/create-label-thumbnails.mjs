/**
 * Creates coregistered label thumbnail images for the labels popup.
 *
 * Generates all 12 combinations: 4 basemaps × 3 label styles.
 * Each thumbnail shows the same geographic area (Douala/Buea, Cameroon)
 * so the labels popup can display the correct basemap context.
 *
 * Output naming: labels_{basemap}_{labelstyle}.jpg
 *   e.g. labels_defaultmap_dark.jpg, labels_satellite_none.jpg
 */

import { createRequire } from 'module';
import { writeFile, mkdir } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Resolve sharp from the frontend directory where it's installed
const require = createRequire(join(__dirname, '..', 'frontend', 'package.json'));
const sharp = require('sharp');

const OUTPUT_DIR = join(__dirname, '..', 'frontend', 'public', 'images');

const ACCESS_TOKEN =
  'pk.eyJ1IjoiY2lncnAiLCJhIjoiYTQ5YzVmYTk4YzM0ZWM4OTU1ZjQxMWI5ZDNiNTQ5M2IifQ.SBgo9jJftBDx4c5gX4wm3g';

// Basemap tile URLs (from basemaps.json)
const BASEMAPS = {
  defaultmap: `https://api.mapbox.com/styles/v1/cigrp/cixkh6jb000582smx8pfdeu23/tiles/256/{z}/{x}/{y}@2x?access_token=${ACCESS_TOKEN}`,
  satellite:  `https://api.mapbox.com/styles/v1/cigrp/cizsz6pv700422ro73xdhzi1g/tiles/256/{z}/{x}/{y}@2x?access_token=${ACCESS_TOKEN}`,
  topographic:`https://api.mapbox.com/styles/v1/cigrp/clgmd4mqr00ci01r7eh0ngxkz/tiles/256/{z}/{x}/{y}@2x?access_token=${ACCESS_TOKEN}`,
  dark:       `https://api.mapbox.com/styles/v1/cigrp/cixtef50400162rla1jtwtoyi/tiles/256/{z}/{x}/{y}@2x?access_token=${ACCESS_TOKEN}`,
};

// Label overlay tile URLs (from labels.json)
const LABEL_OVERLAYS = {
  dark:  `https://api.mapbox.com/styles/v1/cigrp/clgyh74fy00g901qy2bmmerq9/tiles/256/{z}/{x}/{y}@2x?access_token=${ACCESS_TOKEN}`,
  light: `https://api.mapbox.com/styles/v1/cigrp/clgyr7y4u009l01qt32300lx9/tiles/256/{z}/{x}/{y}@2x?access_token=${ACCESS_TOKEN}`,
  none:  null,
};

// Tile coordinates: Douala/Edéa area, Cameroon at zoom 11
// Higher zoom = larger labels = more visible in small thumbnails
const Z = 11;
const X = 1081;
const Y = 1001;

function buildUrl(template, z, x, y) {
  return template.replace('{z}', z).replace('{x}', x).replace('{y}', y);
}

async function fetchTile(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to fetch tile: ${res.status} ${url}`);
  return Buffer.from(await res.arrayBuffer());
}

async function compositeAndSave(baseBuf, labelBuf, outputName) {
  // First ensure the base is PNG so we can composite with alpha
  const basePng = await sharp(baseBuf).png().toBuffer();
  const baseMeta = await sharp(basePng).metadata();

  let composited;
  if (labelBuf) {
    // Ensure label overlay matches basemap dimensions
    const labelPng = await sharp(labelBuf)
      .resize(baseMeta.width, baseMeta.height)
      .png()
      .toBuffer();
    composited = await sharp(basePng)
      .composite([{ input: labelPng, blend: 'over' }])
      .toBuffer();
  } else {
    composited = basePng;
  }

  // @2x tiles are 512x512. Resize full tile to 200x200 for thumbnail.
  const result = await sharp(composited)
    .resize(200, 200, { kernel: 'lanczos3' })
    .jpeg({ quality: 85 })
    .toBuffer();

  const outputPath = join(OUTPUT_DIR, outputName);
  await writeFile(outputPath, result);
  console.log(`  Created: ${outputName}`);
}

async function main() {
  await mkdir(OUTPUT_DIR, { recursive: true });

  // 1. Download all unique tiles
  console.log('Downloading basemap tiles...');
  const basemapBuffers = {};
  for (const [name, urlTemplate] of Object.entries(BASEMAPS)) {
    const url = buildUrl(urlTemplate, Z, X, Y);
    basemapBuffers[name] = await fetchTile(url);
    const meta = await sharp(basemapBuffers[name]).metadata();
    console.log(`  ${name}: ${basemapBuffers[name].length} bytes (${meta.width}x${meta.height})`);
  }

  console.log('Downloading label overlay tiles...');
  const labelBuffers = {};
  for (const [name, urlTemplate] of Object.entries(LABEL_OVERLAYS)) {
    if (!urlTemplate) {
      labelBuffers[name] = null;
      console.log(`  ${name}: (none)`);
      continue;
    }
    const url = buildUrl(urlTemplate, Z, X, Y);
    labelBuffers[name] = await fetchTile(url);
    console.log(`  ${name}: ${labelBuffers[name].length} bytes`);
  }

  // 2. Generate all 12 combinations
  console.log('\nGenerating 12 thumbnails (4 basemaps × 3 label styles)...');
  for (const basemapName of Object.keys(BASEMAPS)) {
    for (const labelName of Object.keys(LABEL_OVERLAYS)) {
      const filename = `labels_${basemapName}_${labelName}.jpg`;
      await compositeAndSave(basemapBuffers[basemapName], labelBuffers[labelName], filename);
    }
  }

  console.log('\nDone! All 12 label thumbnails created.');
}

main().catch((err) => {
  console.error('Error:', err);
  process.exit(1);
});
