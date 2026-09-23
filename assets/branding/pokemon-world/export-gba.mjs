// Technical export of generated artwork and the game's existing title-screen fog.
// Run: node assets/branding/pokemon-world/export-gba.mjs
// Requires Node.js, ImageMagick (`magick`), and this repo's tools/gbagfx/gbagfx.
import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';
import assert from 'node:assert/strict';

const root = dirname(fileURLToPath(import.meta.url));
const out = join(root, 'game/gba');
mkdirSync(out, { recursive: true });
const W = 240, H = 160;

function decode(path, width, height, filter = 'Lanczos') {
  const rgba = execFileSync('magick', [join(root, path), '-filter', filter,
    '-resize', `${width}x${height}!`, '-alpha', 'on', '-depth', '8', 'rgba:-'],
    { maxBuffer: 32 * 1024 * 1024 });
  assert.equal(rgba.length, width * height * 4);
  return rgba;
}

const to5 = value => value >>> 3;
const to8 = value => Math.round(value * 255 / 31);
function rgb5(rgba, i) { return [to5(rgba[i]), to5(rgba[i + 1]), to5(rgba[i + 2])]; }
function key(c) { return c[0] | c[1] << 5 | c[2] << 10; }

// Weighted median cut in the hardware's RGB555 color space.
function paletteFor(images, count) {
  const histogram = new Map();
  for (const rgba of images) for (let i = 0; i < rgba.length; i += 4) {
    if (rgba[i + 3] < 128) continue;
    const c = rgb5(rgba, i), k = key(c);
    const sample = histogram.get(k);
    if (sample) sample.n++; else histogram.set(k, { c, n: 1 });
  }
  const box = items => {
    const ranges = [0, 1, 2].map(ch => Math.max(...items.map(p => p.c[ch])) - Math.min(...items.map(p => p.c[ch])));
    const axis = ranges.indexOf(Math.max(...ranges));
    return { items, axis, score: ranges[axis] * Math.sqrt(items.reduce((n, p) => n + p.n, 0)) };
  };
  const boxes = [box([...histogram.values()])];
  while (boxes.length < count) {
    boxes.sort((a, b) => b.score - a.score);
    const b = boxes.shift();
    if (b.items.length < 2 || !b.score) { boxes.unshift(b); break; }
    b.items.sort((a, c) => a.c[b.axis] - c.c[b.axis]);
    const halfway = b.items.reduce((n, p) => n + p.n, 0) / 2;
    let sum = 0, at = 0;
    while (at < b.items.length - 1 && sum < halfway) sum += b.items[at++].n;
    boxes.push(box(b.items.slice(0, at)), box(b.items.slice(at)));
  }
  return [[0, 0, 0], ...boxes.map(b => {
    const total = b.items.reduce((n, p) => n + p.n, 0);
    return [0, 1, 2].map(ch => Math.round(b.items.reduce((n, p) => n + p.c[ch] * p.n, 0) / total));
  })];
}

function indexPixels(rgba, palette) {
  const indices = Buffer.alloc(rgba.length / 4), cache = new Map();
  for (let i = 0; i < indices.length; i++) {
    if (rgba[i * 4 + 3] < 128) continue;
    const c = rgb5(rgba, i * 4), k = key(c);
    if (!cache.has(k)) {
      let best = 1, distance = Infinity;
      for (let j = 1; j < palette.length; j++) {
        const d = palette[j].reduce((s, v, ch) => s + (v - c[ch]) ** 2, 0);
        if (d < distance) { best = j; distance = d; }
      }
      cache.set(k, best);
    }
    indices[i] = cache.get(k);
  }
  return indices;
}

function paletteBinary(palette, length) {
  const bytes = Buffer.alloc(length * 2);
  palette.forEach((c, i) => bytes.writeUInt16LE(key(c), i * 2));
  return bytes;
}

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const payload = Buffer.concat([Buffer.from(type), data]);
  const head = Buffer.alloc(4), tail = Buffer.alloc(4);
  head.writeUInt32BE(data.length); tail.writeUInt32BE(crc32(payload));
  return Buffer.concat([head, payload, tail]);
}
function savePng(name, pixels, width, height, palette) {
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0); header.writeUInt32BE(height, 4);
  header[8] = 8; header[9] = 3;
  const rows = Buffer.alloc((width + 1) * height);
  for (let y = 0; y < height; y++) pixels.copy(rows, y * (width + 1) + 1, y * width, (y + 1) * width);
  writeFileSync(join(out, name), Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header),
    chunk('PLTE', Buffer.from(palette.flatMap(c => c.map(to8)))),
    chunk('tRNS', Buffer.from([0, ...palette.slice(1).map(() => 255)])),
    chunk('IDAT', deflateSync(rows)), chunk('IEND', Buffer.alloc(0)),
  ]));
}

function copyRgba(source, sw, sh, target, tw, x, y) {
  for (let row = 0; row < sh; row++) source.copy(target, ((y + row) * tw + x) * 4, row * sw * 4, (row + 1) * sw * 4);
}
const scenery = decode('game/masters/title-background.png', W, H);
function logoLayer(path, width, y) {
  const [sourceWidth, sourceHeight] = execFileSync('magick', ['identify', '-format', '%w %h', join(root, path)], { encoding: 'utf8' }).trim().split(' ').map(Number);
  const height = Math.round(width * sourceHeight / sourceWidth);
  const pixels = decode(path, width, height);
  // Center the visible silhouette, excluding the master's uneven transparent
  // padding. Use the same alpha cutoff as indexPixels, and keep the stack intact.
  let left = width, right = -1;
  for (let i = 0; i < pixels.length; i += 4) if (pixels[i + 3] >= 128) {
    const px = (i / 4) % width;
    left = Math.min(left, px); right = Math.max(right, px);
  }
  assert(right >= left, 'Logo must contain visible pixels');
  const visibleWidth = right - left + 1;
  const visibleLeft = Math.floor((W - visibleWidth) / 2);
  const x = visibleLeft - left;
  const margins = { left: visibleLeft, right: W - visibleLeft - visibleWidth };
  assert(Math.abs(margins.left - margins.right) <= 1, 'Visible logo must be centered within one pixel');
  assert(x >= 0 && x + width <= W && y + height <= H, 'Logo must fit');
  const rgba = Buffer.alloc(W * H * 4);
  copyRgba(pixels, width, height, rgba, W, x, y);
  return { rgba, layout: { x, y, width, height, sourceWidth, sourceHeight, visibleWidth, margins } };
}
const logo = logoLayer('logos/pokemon-world.png', 160, 4);
const worldLogo = logoLayer('logos/world.png', 144, 20);
// Reserve palette bank 15 for the existing 4bpp cloud layer.
const artPalette = paletteFor([scenery, logo.rgba, worldLogo.rgba], 239);
const cloudPalette = readFileSync(join(root, 'game/fog/cloud-palette-source.pal'), 'utf8')
  .trim().split(/\r?\n/).slice(3).map(row => row.trim().split(/\s+/).map(Number).map(to5));
assert.equal(cloudPalette.length, 16);
const bgPalette = [...artPalette];
while (bgPalette.length < 240) bgPalette.push([0, 0, 0]);
bgPalette.push(...cloudPalette);
const sceneryIndex = indexPixels(scenery, artPalette);
const logoIndex = indexPixels(logo.rgba, artPalette), worldIndex = indexPixels(worldLogo.rgba, artPalette);
savePng('background.png', sceneryIndex, W, H, bgPalette);
savePng('logo-layer.png', logoIndex, W, H, bgPalette);
savePng('world-logo-layer.png', worldIndex, W, H, bgPalette);
writeFileSync(join(out, 'background.gbapal'), paletteBinary(bgPalette, 256));

// Both regular 32x32 text maps refer to one deduplicated 8bpp tileset.
const tiles = [Buffer.alloc(64)], tileIds = new Map([[tiles[0].toString('hex'), 0]]);
function textMap(pixels) {
  const map = Buffer.alloc(32 * 32 * 2);
  for (let ty = 0; ty < H / 8; ty++) for (let tx = 0; tx < W / 8; tx++) {
    const tile = Buffer.alloc(64);
    for (let row = 0; row < 8; row++) pixels.copy(tile, row * 8, (ty * 8 + row) * W + tx * 8, (ty * 8 + row) * W + tx * 8 + 8);
    const k = tile.toString('hex');
    if (!tileIds.has(k)) { tileIds.set(k, tiles.length); tiles.push(tile); }
    map.writeUInt16LE(tileIds.get(k), (ty * 32 + tx) * 2);
  }
  return map;
}
const sceneryMap = textMap(sceneryIndex), logoMap = textMap(logoIndex), worldMap = textMap(worldIndex);
const fogCharBase = 3, fogTileOffset = 192, fogAddress = 0xD800;
assert(tiles.length * 64 <= fogAddress, `${tiles.length} BG tiles overlap the fog allocation`);
writeFileSync(join(out, 'background.8bpp'), Buffer.concat(tiles));
writeFileSync(join(out, 'background-map.bin'), sceneryMap);
writeFileSync(join(out, 'logo-map.bin'), logoMap);
writeFileSync(join(out, 'world-logo-map.bin'), worldMap);

function unpackMap(map) {
  const image = Buffer.alloc(W * H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const id = map.readUInt16LE((Math.floor(y / 8) * 32 + Math.floor(x / 8)) * 2);
    image[y * W + x] = tiles[id][(y % 8) * 8 + x % 8];
  }
  return image;
}
assert.deepEqual(unpackMap(sceneryMap), sceneryIndex);
assert.deepEqual(unpackMap(logoMap), logoIndex);
assert.deepEqual(unpackMap(worldMap), worldIndex);

// Preserve the game's existing cloud indices, tile pattern and map flips.
execFileSync(join(root, '../../../tools/gbagfx/gbagfx'), [
  join(root, 'game/fog/cloud-tiles-source.png'), join(out, 'fog.4bpp'),
]);
const fogTiles = readFileSync(join(out, 'fog.4bpp'));
assert.equal(fogTiles.length, 112 * 32);
assert(fogAddress + fogTiles.length <= 29 * 2048, 'Fog overlaps the tilemaps');
const fogMapSource = readFileSync(join(root, 'game/fog/cloud-map-source.bin'));
const fogMap = Buffer.alloc(fogMapSource.length), fogPixels = Buffer.alloc(256 * 256);
for (let cell = 0; cell < 1024; cell++) {
  const entry = fogMapSource.readUInt16LE(cell * 2), tile = entry & 1023;
  assert(tile * 32 < fogTiles.length);
  fogMap.writeUInt16LE((15 << 12) | (entry & 0xC00) | (tile + fogTileOffset), cell * 2);
  for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) {
    const sx = entry & 0x400 ? 7 - x : x, sy = entry & 0x800 ? 7 - y : y;
    const byte = fogTiles[tile * 32 + sy * 4 + Math.floor(sx / 2)];
    fogPixels[(Math.floor(cell / 32) * 8 + y) * 256 + (cell % 32) * 8 + x] = (byte >> ((sx % 2) * 4)) & 15;
  }
}
savePng('fog-layer.png', fogPixels, 256, 256, cloudPalette);
writeFileSync(join(out, 'fog-map.bin'), fogMap);
writeFileSync(join(out, 'fog.gbapal'), paletteBinary(cloudPalette, 16));
// Match the original Q8.8 sine table and integer truncation used by GenerateWave.
const sineText = readFileSync(join(root, '../../../src/trig.c'), 'utf8').split('const s16 gSineTable[] =')[1].split('};')[0];
const sine = [...sineText.matchAll(/Q_8_8\(([-\d.]+)\)/g)].slice(0, 256).map(m => Number(m[1]) * 256);
assert.equal(sine.length, 256);
const wave = Array.from({ length: 64 }, (_, i) => Math.trunc(sine[(i * 4) & 255] * 4 / 256));
const animation = { fps: 60, scrollFramesPerPixel: 4, wave, blend: { foreground: 6, background: 15, denominator: 16 } };
writeFileSync(join(root, 'game/fog/animation.json'), JSON.stringify(animation, null, 2) + '\n');
// A classic script also works when the review page is opened through file://.
writeFileSync(join(out, 'preview-config.js'), `window.WORLD_TITLE_CONFIG = ${JSON.stringify(animation)};\n`);
const manifest = {
  screen: { width: W, height: H, mode: 0 },
  background: { bpp: 8, artColors: artPalette.length, tiles: tiles.length, tileBytes: tiles.length * 64,
    charBase: 0, sceneryScreenBase: 30, logoScreenBase: 31, sceneryPriority: 2, logoPriority: 0,
    logos: { full: logo.layout, world: worldLogo.layout } },
  fog: { source: 'graphics/title_screen/clouds.png + clouds.bin + rayquaza_and_clouds.pal',
    bpp: 4, charBase: fogCharBase, tileOffset: fogTileOffset, vramOffset: fogAddress,
    tileBytes: fogTiles.length, screenBase: 29, paletteBank: 15, priority: 1, ...animation },
  sprites: { actors: [], bytes: 0 },
  preview: { movement: 'Existing title-screen cloud map, vertical scroll and scanline wave; no Pokémon sprites.' },
  integration: 'CB2_InitTitleScreen selects src/title_screen_world.c for ALL_REGIONS builds. Canonical engine binaries: graphics/title_screen/world/.',
};
writeFileSync(join(out, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
// Install the raw hardware resources consumed by the ROM's INCBIN declarations.
const engine = join(root, '../../../graphics/title_screen/world');
mkdirSync(engine, { recursive: true });
for (const [source, target] of Object.entries({
  'background.8bpp': 'background_tiles.bin', 'background.gbapal': 'palette.bin',
  'background-map.bin': 'background_map.bin', 'logo-map.bin': 'logo_map.bin',
  'fog.4bpp': 'fog_tiles.bin', 'fog-map.bin': 'fog_map.bin',
})) copyFileSync(join(out, source), join(engine, target));
console.log(`Exported ${tiles.length} background tiles (${tiles.length * 64} bytes), three artwork maps, and ${fogTiles.length} bytes of existing fog tiles.`);
console.log('Validated artwork tilemap round trips, logo aspect ratios, fog tile references, palette allocation, and VRAM budgets.');
