import { deflateSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';

const S = 1024;
const px = Buffer.alloc(S * S * 4);
const clamp = (v, a = 0, b = 1) => (v < a ? a : v > b ? b : v);
const mix = (a, b, t) => a + (b - a) * t;

function segDist(x, y, ax, ay, bx, by) {
  const vx = bx - ax, vy = by - ay, wx = x - ax, wy = y - ay;
  const t = clamp((wx * vx + wy * vy) / (vx * vx + vy * vy));
  const dx = x - (ax + vx * t), dy = y - (ay + vy * t);
  return Math.sqrt(dx * dx + dy * dy);
}
function rrectDist(x, y, cx, cy, hw, hh, r) {
  const qx = Math.abs(x - cx) - (hw - r);
  const qy = Math.abs(y - cy) - (hh - r);
  const ox = Math.max(qx, 0), oy = Math.max(qy, 0);
  return Math.sqrt(ox * ox + oy * oy) + Math.min(Math.max(qx, qy), 0) - r;
}

// 图形：圆角方块轮廓 + 向上箭头
const tile = { cx: 0.5, cy: 0.5, hw: 0.30, hh: 0.30, r: 0.09, w: 0.028 };
const arrow = [
  { a: [0.5, 0.395], b: [0.5, 0.625], r: 0.026 },   // 竖杆
  { a: [0.5, 0.395], b: [0.405, 0.487], r: 0.026 }, // 左斜
  { a: [0.5, 0.395], b: [0.595, 0.487], r: 0.026 }  // 右斜
];

for (let y = 0; y < S; y++) {
  for (let x = 0; x < S; x++) {
    const u = x / (S - 1), v = y / (S - 1);

    // 渐变背景：靛蓝 -> 紫
    const t = clamp((u * 0.55 + v * 0.75));
    let r = mix(20, 92, t), g = mix(120, 56, t), b = mix(250, 240, t);

    // 轻微暗角
    const dx = u - 0.5, dy = v - 0.5;
    const d = Math.sqrt(dx * dx + dy * dy) * 1.5;
    const vig = clamp(1 - d * 0.35);
    r *= vig; g *= vig; b *= vig;

    // 方块轮廓
    const td = Math.abs(rrectDist(u, v, tile.cx, tile.cy, tile.hw, tile.hh, tile.r)) - tile.w;
    const tileA = clamp(0.5 - td / 0.0035);

    // 箭头
    let ad = 1e9;
    for (const s of arrow) ad = Math.min(ad, segDist(u, v, s.a[0], s.a[1], s.b[0], s.b[1]) - s.r);
    const arrowA = clamp(0.5 - ad / 0.0035);

    const w = Math.max(tileA, arrowA);
    if (w > 0) {
      r = mix(r, 255, w);
      g = mix(g, 255, w);
      b = mix(b, 255, w);
    }

    const i = (y * S + x) * 4;
    px[i] = r | 0; px[i + 1] = g | 0; px[i + 2] = b | 0; px[i + 3] = 255;
  }
}

const raw = Buffer.alloc(S * (S * 4 + 1));
for (let y = 0; y < S; y++) {
  raw[y * (S * 4 + 1)] = 0;
  px.copy(raw, y * (S * 4 + 1) + 1, y * S * 4, (y + 1) * S * 4);
}
function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const t = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([t, data])));
  return Buffer.concat([len, t, data, crc]);
}
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(S, 0); ihdr.writeUInt32BE(S, 4);
ihdr[8] = 8; ihdr[9] = 6;
writeFileSync(process.argv[2] || 'icon1024.png', Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0))
]));
console.log('icon ok');
