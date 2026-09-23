// Convert the finished artwork into native GBA title resources.
// Run: node tools/export-world-title.mjs
// Requires Node.js, ImageMagick (`magick`), and this repo's tools/gbagfx/gbagfx.
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const repo = join(dirname(fileURLToPath(import.meta.url)), '..');
const root = join(repo, 'assets/branding/pokemon-world');
const out = join(repo, 'graphics/title_screen/world');
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

function copyRgba(source, sw, sh, target, tw, x, y) {
  for (let row = 0; row < sh; row++) source.copy(target, ((y + row) * tw + x) * 4, row * sw * 4, (row + 1) * sw * 4);
}
const scenery = decode('artwork/title-background.png', W, H);
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
  return rgba;
}
const logo = logoLayer('logos/pokemon-world.png', 160, 4);
const worldLogo = logoLayer('logos/world.png', 144, 20);
// Reserve palette bank 15 for the existing 4bpp cloud layer.
// Retain the alternate wordmark's shared palette and tile allocation so this
// relocation reproduces the already validated game resources exactly.
const artPalette = paletteFor([scenery, logo, worldLogo], 239);
const cloudPalette = readFileSync(join(repo, 'graphics/title_screen/rayquaza_and_clouds.pal'), 'utf8')
  .trim().split(/\r?\n/).slice(3).map(row => row.trim().split(/\s+/).map(Number).map(to5));
assert.equal(cloudPalette.length, 16);
const bgPalette = [...artPalette];
while (bgPalette.length < 240) bgPalette.push([0, 0, 0]);
bgPalette.push(...cloudPalette);
const sceneryIndex = indexPixels(scenery, artPalette);
const logoIndex = indexPixels(logo, artPalette), worldIndex = indexPixels(worldLogo, artPalette);
writeFileSync(join(out, 'palette.bin'), paletteBinary(bgPalette, 256));

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
const fogTileOffset = 192, fogAddress = 0xD800;
assert(tiles.length * 64 <= fogAddress, `${tiles.length} BG tiles overlap the fog allocation`);
writeFileSync(join(out, 'background_tiles.bin'), Buffer.concat(tiles));
writeFileSync(join(out, 'background_map.bin'), sceneryMap);
writeFileSync(join(out, 'logo_map.bin'), logoMap);

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
execFileSync(join(repo, 'tools/gbagfx/gbagfx'), [
  join(repo, 'graphics/title_screen/clouds.png'), join(out, 'fog_tiles.4bpp'),
]);
renameSync(join(out, 'fog_tiles.4bpp'), join(out, 'fog_tiles.bin'));
const fogTiles = readFileSync(join(out, 'fog_tiles.bin'));
assert.equal(fogTiles.length, 112 * 32);
assert(fogAddress + fogTiles.length <= 29 * 2048, 'Fog overlaps the tilemaps');
const fogMapSource = readFileSync(join(repo, 'graphics/title_screen/clouds.bin'));
const fogMap = Buffer.alloc(fogMapSource.length);
for (let cell = 0; cell < 1024; cell++) {
  const entry = fogMapSource.readUInt16LE(cell * 2), tile = entry & 1023;
  assert(tile * 32 < fogTiles.length);
  fogMap.writeUInt16LE((15 << 12) | (entry & 0xC00) | (tile + fogTileOffset), cell * 2);
}
writeFileSync(join(out, 'fog_map.bin'), fogMap);
console.log(`Exported ${tiles.length} artwork tiles (${tiles.length * 64} bytes) and ${fogTiles.length} bytes of existing fog tiles.`);
console.log('Validated tilemaps, visible logo centering, palette allocation and VRAM limits.');
