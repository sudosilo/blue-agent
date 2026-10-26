// detailer eye v1
// Gives the detailer agent eyes on the city without a browser: it draws the city's line work into a PNG
// with the test bed's own engine geometry, and scans every record for things that move or sit wrong.

import zlib from 'node:zlib';

const S = 79248;
const BG = [244, 242, 234];

// ---------- PNG ----------

const CRC = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
function crc32(buf) { let c = 0xffffffff; for (const b of buf) c = CRC[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function chunkPng(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function encodePng(w, h, rgb) {
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 3 + 1)] = 0; rgb.copy(raw, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunkPng('IHDR', ihdr), chunkPng('IDAT', zlib.deflateSync(raw, { level: 6 })), chunkPng('IEND', Buffer.alloc(0))]);
}

// ---------- canvas ----------

function canvas(w, h) {
  const px = Buffer.alloc(w * h * 3);
  for (let i = 0; i < w * h; i++) { px[i * 3] = BG[0]; px[i * 3 + 1] = BG[1]; px[i * 3 + 2] = BG[2]; }
  const dot = (x, y, c) => { if (x < 0 || y < 0 || x >= w || y >= h) return; const i = (y * w + x) * 3; px[i] = c[0]; px[i + 1] = c[1]; px[i + 2] = c[2]; };
  function line(x0, y0, x1, y1, c, thick) {
    // clip to the frame
    let t0 = 0, t1 = 1; const dx = x1 - x0, dy = y1 - y0;
    for (const [p, q] of [[-dx, x0], [dx, w - 1 - x0], [-dy, y0], [dy, h - 1 - y0]]) {
      if (p === 0) { if (q < 0) return; continue; }
      const r = q / p; if (p < 0) { if (r > t1) return; if (r > t0) t0 = r; } else { if (r < t0) return; if (r < t1) t1 = r; }
    }
    let ax = Math.round(x0 + t0 * dx), ay = Math.round(y0 + t0 * dy); const bx = Math.round(x0 + t1 * dx), by = Math.round(y0 + t1 * dy);
    const sx = ax < bx ? 1 : -1, sy = ay < by ? 1 : -1, ddx = Math.abs(bx - ax), ddy = -Math.abs(by - ay);
    let err = ddx + ddy, guard = 0;
    for (;;) {
      dot(ax, ay, c); if (thick) { dot(ax + 1, ay, c); dot(ax, ay + 1, c); }
      if ((ax === bx && ay === by) || ++guard > 20000) break;
      const e2 = 2 * err; if (e2 >= ddy) { err += ddy; ax += sx; } if (e2 <= ddx) { err += ddx; ay += sy; }
    }
  }
  function ring(x, y, r, c) { for (let a = 0; a < 24; a++) line(x + r * Math.cos(a / 24 * 6.283), y + r * Math.sin(a / 24 * 6.283), x + r * Math.cos((a + 1) / 24 * 6.283), y + r * Math.sin((a + 1) / 24 * 6.283), c, true); }
  return { w, h, px, line, ring };
}
const hex = s => [parseInt(s.slice(1, 3), 16), parseInt(s.slice(3, 5), 16), parseInt(s.slice(5, 7), 16)];

// ---------- camera ----------
// mode top: straight down, centered on center [x, y] mm, span meters across the short side.
// mode iso: perspective, looking at center from az degrees (0 = from the south looking north, 90 = from the east), el degrees up, dist meters away.
function camera(v, w, h) {
  const c = v.center || [S / 2, S / 2];
  const tx = c[0] / 1000, ty = c[1] / 1000, tz = (c[2] || 0) / 1000;
  if ((v.mode || 'top') === 'top') {
    const span = Math.max(4, Math.min(1500, Number(v.span) || 90)), k = Math.min(w, h) / span;
    return p => ({ x: w / 2 + (p[0] / 1000 - tx) * k, y: h / 2 - (p[1] / 1000 - ty) * k, z: 1 });
  }
  const az = (Number(v.az) || 0) * Math.PI / 180, el = Math.max(3, Math.min(89, Number(v.el ?? 35))) * Math.PI / 180, d = Math.max(3, Math.min(2000, Number(v.dist) || 90));
  const eye = [tx + Math.sin(az) * Math.cos(el) * d, ty - Math.cos(az) * Math.cos(el) * d, tz + Math.sin(el) * d];
  const f = norm([tx - eye[0], ty - eye[1], tz - eye[2]]), r = norm(cross(f, [0, 0, 1])), u = cross(r, f);
  const fov = (Number(v.fov) || 50) * Math.PI / 180, k = (h / 2) / Math.tan(fov / 2);
  return p => {
    const q = [p[0] / 1000 - eye[0], p[1] / 1000 - eye[1], p[2] / 1000 - eye[2]];
    const z = dot(q, f);
    return { x: w / 2 + dot(q, r) * k / z, y: h / 2 - dot(q, u) * k / z, z, cam: [dot(q, r), dot(q, u), z] };
  };
}
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const norm = a => { const l = Math.hypot(...a) || 1; return a.map(x => x / l); };

// Which chunks a view can see, so the caller fetches only those.
export function chunksForView(v) {
  const c = v.center || [S / 2, S / 2];
  const reach = (v.mode || 'top') === 'top' ? (Number(v.span) || 90) * 700 : (Number(v.dist) || 90) * 1300;
  const out = [];
  for (let cx = Math.floor((c[0] - reach) / S); cx <= Math.floor((c[0] + reach) / S); cx++)
    for (let cy = Math.floor((c[1] - reach) / S); cy <= Math.floor((c[1] + reach) / S); cy++) out.push([cx, cy]);
  return out.slice(0, 25);
}

// records: full chunk detail records (kind, color, color2, pts, at, rot, closed, pattern, spacing, angle, meta, hidden).
// engine: the test bed's engine.js module (PALETTE, recSegs).
export function renderView(records, engine, v) {
  const w = Math.max(320, Math.min(1400, Number(v.width) || 1100)), h = Math.max(240, Math.min(1100, Number(v.height) || 800));
  const cv = canvas(w, h), proj = camera(v, w, h);
  const pal = (engine.PALETTE || []).map(hex);
  const mark = new Set((v.highlight || []).map(Number));
  const only = v.agent ? String(v.agent) : null;
  const near = 0.3;
  const seg = (a, b, col, thick) => {
    let A = proj(a), B = proj(b);
    if (A.cam) { // clip against the near plane
      if (A.z < near && B.z < near) return;
      if (A.z < near || B.z < near) {
        const t = (near - A.z) / (B.z - A.z), m = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
        if (A.z < near) A = proj(m); else B = proj(m);
      }
    }
    cv.line(A.x, A.y, B.x, B.y, col, thick);
  };
  let drawn = 0;
  for (const r of records) {
    if (r.hidden && !v.showHidden) continue;
    if (only && r.agent !== only) continue;
    if (v.discipline && r.discipline !== v.discipline) continue;
    let segs; try { segs = engine.recSegs(Object.assign({ rot: 0, meta: null }, r)); } catch { continue; }
    const c1 = pal[r.color] || [90, 90, 90], c2 = r.color2 != null ? pal[r.color2] : null;
    const hl = mark.has(r.id);
    for (let i = 0; i + 1 < segs.length; i += 2) {
      const p = segs[i], q = segs[i + 1];
      let col = hl ? [230, 0, 200] : r.hidden ? [205, 205, 205] : c1;
      if (!hl && !r.hidden && c2 && p.length > 3) { const t = p[3]; col = c1.map((x, k) => Math.round(x + (c2[k] - x) * t)); }
      seg(p, q, col, hl);
    }
    const an = r.meta && r.meta.anim;
    if (v.paths !== false && an && an.type === 'path' && Array.isArray(an.pts)) for (let i = 0; i < an.pts.length; i++) seg(an.pts[i], an.pts[(i + 1) % an.pts.length], [235, 40, 40], false);
    drawn++;
  }
  // chunk edges, faint
  for (const [cx, cy] of v._chunks || []) { const x0 = cx * S, y0 = cy * S, q = [[x0, y0], [x0 + S, y0], [x0 + S, y0 + S], [x0, y0 + S]]; for (let i = 0; i < 4; i++) seg([...q[i], 0], [...q[(i + 1) % 4], 0], [215, 210, 195], false); }
  // flags as red rings
  for (const f of v._flags || []) { const P = proj(f); if (!P.cam || P.z > near) cv.ring(P.x, P.y, 9, [220, 0, 0]); }
  return { png: encodePng(w, h, cv.px), drawn, width: w, height: h };
}

// ---------- inspector ----------
// records: allRecords from /api/state?all=1 (id, chunk, agent, discipline, kind, type, at, pts, meta, hidden).
export function inspect(records) {
  const recs = records.filter(r => !r.hidden);
  const out = [];
  const add = (kind, r, msg) => out.push({ kind, id: r.id, agent: r.agent, chunk: r.chunk, msg });
  const inside = (pt, poly) => { let c = false; for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) { const a = poly[i], b = poly[j]; if ((a[1] > pt[1]) !== (b[1] > pt[1]) && pt[0] < (b[0] - a[0]) * (pt[1] - a[1]) / (b[1] - a[1]) + a[0]) c = !c; } return c; };
  const crosses = (a, b, p, q) => { const d = (b[0] - a[0]) * (q[1] - p[1]) - (b[1] - a[1]) * (q[0] - p[0]); if (Math.abs(d) < 1e-9) return false; const t = ((p[0] - a[0]) * (q[1] - p[1]) - (p[1] - a[1]) * (q[0] - p[0])) / d, u = ((p[0] - a[0]) * (b[1] - a[1]) - (p[1] - a[1]) * (b[0] - a[0])) / d; return t > 0.001 && t < 0.999 && u >= 0 && u <= 1; };
  const dseg = (p, a, b) => { const dx = b[0] - a[0], dy = b[1] - a[1], L = dx * dx + dy * dy || 1; const t = Math.max(0, Math.min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L)); return Math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy); };
  const walls = recs.filter(r => r.kind === 'line' && r.meta && r.meta.wall && Array.isArray(r.pts));
  const polys = walls.filter(r => r.pts.length >= 3).map(r => ({ name: r.meta.building, pts: r.pts, h: r.meta.h || 3048, zmin: r.meta.zmin || 0 }));
  const wsegs = []; for (const r of walls) { const p = r.pts.length >= 3 ? r.pts.concat([r.pts[0]]) : r.pts; for (let i = 0; i + 1 < p.length; i++) wsegs.push({ a: p[i], b: p[i + 1], name: r.meta.building }); }
  // every building's overall footprint box, from all its wall lines, so multi floor and open plan buildings count too
  const boxes = new Map();
  for (const r of walls) { const n = r.meta.building || ('#' + r.id); const b = boxes.get(n) || { name: n, x0: 1e12, y0: 1e12, x1: -1e12, y1: -1e12, h: 0, zmin: 0 }; for (const p of r.pts) { b.x0 = Math.min(b.x0, p[0]); b.y0 = Math.min(b.y0, p[1]); b.x1 = Math.max(b.x1, p[0]); b.y1 = Math.max(b.y1, p[1]); } b.h = Math.max(b.h, (r.meta.h || 3048)); b.zmin = Math.min(b.zmin, r.meta.zmin || 0); boxes.set(n, b); }
  const boxList = [...boxes.values()].filter(b => b.x1 - b.x0 > 1500 && b.y1 - b.y0 > 1500);
  const inB = pt => polys.find(b => inside(pt, b.pts)) || boxList.find(b => pt[0] > b.x0 + 200 && pt[0] < b.x1 - 200 && pt[1] > b.y0 + 200 && pt[1] < b.y1 - 200);
  const routes = [];
  for (const r of recs) {
    const m = r.meta || {}, a = m.anim, P = a && a.type === 'path' && Array.isArray(a.pts) ? a.pts : null;
    if (r.kind === 'symbol') {
      if (r.type === 'bike' && P) add('riderless-bike', r, 'bike moves along a route with nobody on it; use cyclist');
      if (r.type === 'person' && P && m.pose !== 'walking') add('sliding-person', r, 'person moves along a route with pose ' + (m.pose || 'standing'));
      if (['person', 'dog'].includes(r.type) && a && a.type === 'bob' && a.mm > 300) add('bouncing', r, r.type + ' bobs ' + a.mm + ' mm');
      const b = inB(r.at);
      if (!P && ['tree', 'car', 'truck', 'hydrant', 'pole'].includes(r.type) && b && r.at[2] <= b.h) add('inside-building', r, r.type + ' stands inside ' + b.name);
      if (!b && r.at[2] > 150 && ['tree', 'shrub', 'car', 'truck', 'person', 'dog', 'bench', 'table', 'bike', 'cyclist', 'cart', 'hydrant'].includes(r.type) && r.discipline !== 'interior') add('floating', r, r.type + ' floats at z ' + r.at[2] + ' outside any building');
      if (r.at[2] < -50 && !b) add('sunk', r, r.type + ' sits below grade at z ' + r.at[2]);
    }
    if (P && P.length >= 2) {
      routes.push({ r, P });
      if (['car', 'truck', 'bike', 'cyclist', 'cart'].includes(r.type)) {
        for (let i = 0; i + 1 < P.length; i++) { const w = wsegs.find(s => Math.min(P[i][2], P[i + 1][2]) < 2500 && crosses(P[i], P[i + 1], s.a, s.b)); if (w) { add('drives-through-wall', r, r.type + ' route crosses a wall of ' + w.name); break; } }
        const z = P[P.length - 1]; if (Math.hypot(P[0][0] - z[0], P[0][1] - z[1]) > 20000) add('teleport-loop', r, r.type + ' jumps ' + Math.round(Math.hypot(P[0][0] - z[0], P[0][1] - z[1]) / 1000) + ' m back to its start every loop');
        for (let i = 0; i + 1 < P.length; i++) {
          const p = P[i], q = P[i + 1], dx = q[0] - p[0], dy = q[1] - p[1];
          if (Math.abs(dx) > 5 * Math.abs(dy) && Math.abs(dx) > 1000) { const k = Math.round(p[1] / S) * S, off = p[1] - k; if (Math.abs(off) < 7000 && off !== 0 && Math.sign(off) === Math.sign(dx)) { add('wrong-side', r, r.type + ' heads ' + (dx > 0 ? 'east' : 'west') + ' in the oncoming lane of the street at y ' + k); break; } }
          if (Math.abs(dy) > 5 * Math.abs(dx) && Math.abs(dy) > 1000) { const k = Math.round(p[0] / S) * S, off = p[0] - k; if (Math.abs(off) < 7000 && off !== 0 && Math.sign(off) === -Math.sign(dy)) { add('wrong-side', r, r.type + ' heads ' + (dy > 0 ? 'north' : 'south') + ' in the oncoming lane of the street at x ' + k); break; } }
        }
      }
      if (r.type === 'person') for (let i = 0; i + 1 < P.length; i++) { const w = wsegs.find(s => crosses(P[i], P[i + 1], s.a, s.b)); if (w) { add('walks-through-wall', r, 'walker crosses a wall of ' + w.name + '; route it through a door'); break; } }
    }
  }
  // fixed things standing on a route that something moves along
  const blockers = recs.filter(r => r.kind === 'symbol' && ['bench', 'table', 'tree', 'shrub', 'umbrella', 'cart', 'sign', 'hydrant', 'pole', 'car', 'truck'].includes(r.type) && !(r.meta && r.meta.anim && r.meta.anim.type === 'path'));
  for (const b of blockers) {
    const clear = ['tree', 'car', 'truck'].includes(b.type) ? 1500 : 700;
    for (const { r, P } of routes) {
      if (r.type === 'mark') continue;
      if (Math.abs((P[0][2] || 0) - b.at[2]) > 1500) continue;
      let d = 1e12; for (let i = 0; i + 1 < P.length; i++) d = Math.min(d, dseg(b.at, P[i], P[i + 1]));
      if (d < clear) { add('in-the-way', b, b.type + ' stands on the route of moving ' + (r.type || r.kind) + ' ' + r.id + ' (' + Math.round(d) + ' mm off its line)'); break; }
    }
  }
  // same type stacked on itself
  const R = { tree: 1500, car: 1800, truck: 2400, bench: 900, table: 800, person: 250, umbrella: 1000 };
  const syms = recs.filter(r => r.kind === 'symbol' && R[r.type] && !(r.meta && r.meta.anim && r.meta.anim.type === 'path'));
  const grid = new Map(); for (const s of syms) { const k = Math.floor(s.at[0] / 3000) + ',' + Math.floor(s.at[1] / 3000); (grid.get(k) || grid.set(k, []).get(k)).push(s); }
  for (const s of syms) { const gx = Math.floor(s.at[0] / 3000), gy = Math.floor(s.at[1] / 3000); for (let i = -1; i <= 1; i++) for (let j = -1; j <= 1; j++) for (const t of grid.get((gx + i) + ',' + (gy + j)) || []) if (t.id > s.id && t.type === s.type && t.at[2] === s.at[2] && Math.hypot(s.at[0] - t.at[0], s.at[1] - t.at[1]) < R[s.type]) add('overlap', t, t.type + ' overlaps ' + s.type + ' ' + s.id); }
  // duplicate lines drawn on top of each other
  const seen = new Map(); for (const r of recs) if (r.kind === 'line' && Array.isArray(r.pts)) { const k = r.discipline + '|' + JSON.stringify(r.pts.map(p => p.map(v => Math.round(v / 50)))); if (seen.has(k)) add('duplicate-line', r, 'drawn exactly on top of ' + seen.get(k)); else seen.set(k, r.id); }
  const counts = {}; for (const o of out) counts[o.kind] = (counts[o.kind] || 0) + 1;
  return { counts, findings: out };
}
