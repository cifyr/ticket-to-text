// Outline generator: clips each map's region out of public-domain Natural Earth
// data, projects it to fit that map's existing city layout, simplifies, and
// emits Swift outline arrays (faint land + water backgrounds). Run:
//   node src/gen-outlines.ts <dir-with-ne-geojson>
// Expects ne_110m_countries.geojson, ne_states.geojson, ne_lakes.geojson there.
// Natural Earth is public domain (naturalearthdata.com/about/terms-of-use).
import { readFileSync, writeFileSync } from "node:fs";
import { MAPS } from "./map.ts";

type Pt = [number, number];
type BBox = [number, number, number, number]; // [minLon, minLat, maxLon, maxLat]
type Spec = {
  bbox: BBox;
  land?: { src: "countries" | "states"; filter?: (p: any) => boolean };
  water?: { src: "lakes" };
};

const REGIONS: Record<string, Spec> = {
  europe: { bbox: [-11, 35, 40, 62], land: { src: "countries" } },
  germany: { bbox: [5, 47, 16, 55.5], land: { src: "countries" } },
  france: { bbox: [-5, 41, 9, 51.5], land: { src: "countries" } },
  uk: { bbox: [-11, 49.5, 2, 61], land: { src: "countries" } },
  switzerland: { bbox: [5.8, 45.7, 10.6, 47.9], land: { src: "countries" } },
  nordic: { bbox: [4, 54, 32, 71], land: { src: "countries" } },
  india: { bbox: [67, 6, 90, 36], land: { src: "countries" } },
  africa: { bbox: [-19, -36, 52, 38], land: { src: "countries" } },
  asia: { bbox: [44, 4, 150, 61], land: { src: "countries" } },
  netherlands: { bbox: [3.2, 50.6, 7.4, 53.7], land: { src: "countries" } },
  italy: { bbox: [6, 36, 19, 47.6], land: { src: "countries" } },
  japan: { bbox: [128, 30, 146, 46], land: { src: "countries" } },
  poland: { bbox: [13.8, 48.8, 24.5, 55.2], land: { src: "countries" } },
  oldwest: { bbox: [-125, 28, -94, 49.5], land: { src: "countries" } },
  world: { bbox: [-170, -56, 190, 72], land: { src: "countries" } },
  pennsylvania: {
    bbox: [-80.6, 39.6, -74.6, 42.4],
    land: { src: "states", filter: (p) => /Pennsylvania/.test(p.name ?? p.NAME ?? "") },
  },
  greatlakes: { bbox: [-93, 40.5, -74, 49], land: { src: "countries" }, water: { src: "lakes" } },
};

const dir = process.argv[2];
const data = {
  countries: JSON.parse(readFileSync(`${dir}/ne_110m_countries.geojson`, "utf8")),
  states: JSON.parse(readFileSync(`${dir}/ne_states.geojson`, "utf8")),
  lakes: JSON.parse(readFileSync(`${dir}/ne_lakes.geojson`, "utf8")),
};

function clip(ring: Pt[], [minX, minY, maxX, maxY]: BBox): Pt[] {
  const edges: ((p: Pt) => boolean)[] = [
    (p) => p[0] >= minX, (p) => p[0] <= maxX, (p) => p[1] >= minY, (p) => p[1] <= maxY,
  ];
  const inter: ((a: Pt, b: Pt) => Pt)[] = [
    (a, b) => [minX, a[1] + (b[1] - a[1]) * ((minX - a[0]) / (b[0] - a[0]))],
    (a, b) => [maxX, a[1] + (b[1] - a[1]) * ((maxX - a[0]) / (b[0] - a[0]))],
    (a, b) => [a[0] + (b[0] - a[0]) * ((minY - a[1]) / (b[1] - a[1])), minY],
    (a, b) => [a[0] + (b[0] - a[0]) * ((maxY - a[1]) / (b[1] - a[1])), maxY],
  ];
  let out = ring;
  for (let e = 0; e < 4; e++) {
    const inp = out; out = [];
    for (let i = 0; i < inp.length; i++) {
      const cur = inp[i], prev = inp[(i + inp.length - 1) % inp.length];
      const curIn = edges[e](cur), prevIn = edges[e](prev);
      if (curIn) { if (!prevIn) out.push(inter[e](prev, cur)); out.push(cur); }
      else if (prevIn) out.push(inter[e](prev, cur));
    }
    if (out.length === 0) return [];
  }
  return out;
}

function simplify(ring: Pt[], eps: number): Pt[] {
  const out: Pt[] = [];
  for (const p of ring) {
    const last = out[out.length - 1];
    if (!last || Math.hypot(p[0] - last[0], p[1] - last[1]) >= eps) out.push(p);
  }
  return out;
}

function ringsOf(geom: any): Pt[][] {
  if (geom.type === "Polygon") return [geom.coordinates[0]];
  if (geom.type === "MultiPolygon") return geom.coordinates.map((poly: Pt[][]) => poly[0]);
  return [];
}

// Clip+project all rings of a feature collection to a map's normalized city box.
function project(fc: any, spec: Spec, filter: ((p: any) => boolean) | undefined,
                cBox: [number, number, number, number]): Pt[][] {
  const [cx0, cy0, cx1, cy1] = cBox;
  const [minLon, minLat, maxLon, maxLat] = spec.bbox;
  const sx = (lon: number) => cx0 + ((lon - minLon) / (maxLon - minLon)) * (cx1 - cx0);
  const sy = (lat: number) => cy0 + ((maxLat - lat) / (maxLat - minLat)) * (cy1 - cy0);
  const rings: Pt[][] = [];
  for (const f of fc.features) {
    if (filter && !filter(f.properties)) continue;
    for (const ring of ringsOf(f.geometry)) {
      const clipped = clip(ring as Pt[], spec.bbox);
      if (clipped.length < 4) continue;
      const proj = simplify(clipped.map(([lon, lat]) => [sx(lon), sy(lat)] as Pt), 0.006);
      if (proj.length < 4) continue;
      let area = 0;
      for (let i = 0; i < proj.length; i++) {
        const a = proj[i], b = proj[(i + 1) % proj.length];
        area += a[0] * b[1] - b[0] * a[1];
      }
      if (Math.abs(area) / 2 < 0.0006) continue;
      rings.push(proj);
    }
  }
  rings.sort((a, b) => b.length - a.length);
  return rings;
}

function emit(dict: Record<string, Pt[][]>): string {
  return Object.entries(dict).map(([id, rings]) => {
    const body = rings.map((r) =>
      "        [" + r.map(([x, y]) => `(${x.toFixed(4)}, ${y.toFixed(4)})`).join(", ") + "]"
    ).join(",\n");
    return `    "${id}": [\n${body}\n    ],`;
  }).join("\n");
}

const land: Record<string, Pt[][]> = {};
const water: Record<string, Pt[][]> = {};
for (const [id, spec] of Object.entries(REGIONS)) {
  const map = MAPS[id];
  if (!map) { console.warn("no map for", id); continue; }
  const cx = map.cities.map((c) => c.x), cy = map.cities.map((c) => c.y);
  const cBox: [number, number, number, number] =
    [Math.min(...cx), Math.min(...cy), Math.max(...cx), Math.max(...cy)];
  if (spec.land) {
    land[id] = project(data[spec.land.src], spec, spec.land.filter, cBox);
  }
  if (spec.water) {
    water[id] = project(data[spec.water.src], spec, undefined, cBox);
  }
  console.log(`${id}: land=${(land[id] ?? []).length} water=${(water[id] ?? []).length}`);
}

const out = [
  "import Foundation",
  "",
  "// Generated by src/gen-outlines.ts from Natural Earth (public domain).",
  "// Faint per-map land + water outlines, projected to fit each board's cities.",
  "extension BoardGeometry {",
  "    static let mapOutlines: [String: [[(Double, Double)]]] = [",
  emit(land),
  "    ]",
  "    static let mapWater: [String: [[(Double, Double)]]] = [",
  emit(water),
  "    ]",
  "}",
  "",
].join("\n");
writeFileSync("ios/MessagesExtension/UI/MapOutlines.swift", out);
console.log("wrote ios/MessagesExtension/UI/MapOutlines.swift");
