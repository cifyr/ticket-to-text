// City-map outline generator. The 6 city boards are district networks, so their
// geography is local water. Each district node gets its real lon/lat; nodes and
// the 10m ocean/lake/river data are projected together (equirectangular, cos-lat)
// into the board box, so the water lines up with the districts. Run:
//   node src/gen-city-outlines.ts <dir-with-ne-10m-geojson>
// Emits CityOutlines.swift (water fills + river polylines) and prints the node
// coords to paste into each city map's def. Natural Earth is public domain.
import { readFileSync, writeFileSync } from "node:fs";

type Pt = [number, number];
type BBox = [number, number, number, number];
type City = { id: string; bbox: BBox; nodes: [string, number, number][] };

const MAP_ASPECT = 0.5715;

const CITIES: City[] = [
  { id: "newyork", bbox: [-74.05, 40.62, -73.80, 40.90], nodes: [
    ["Inwood", -73.921, 40.867], ["Harlem", -73.945, 40.811], ["Upper West Side", -73.975, 40.787],
    ["Upper East Side", -73.957, 40.773], ["Midtown", -73.984, 40.754], ["Chelsea", -74.001, 40.744],
    ["Greenwich Village", -73.997, 40.733], ["SoHo", -74.000, 40.723], ["Lower Manhattan", -74.011, 40.706],
    ["Brooklyn", -73.950, 40.650], ["Queens", -73.840, 40.730], ["Bronx", -73.866, 40.844],
  ] },
  { id: "london", bbox: [-0.25, 51.44, 0.05, 51.56], nodes: [
    ["Camden", -0.143, 51.539], ["Islington", -0.103, 51.538], ["Paddington", -0.176, 51.515],
    ["Westminster", -0.137, 51.501], ["City", -0.092, 51.515], ["Shoreditch", -0.078, 51.526],
    ["Kensington", -0.192, 51.500], ["Southwark", -0.094, 51.503], ["Greenwich", 0.000, 51.483],
    ["Brixton", -0.115, 51.462],
  ] },
  { id: "paris", bbox: [2.25, 48.81, 2.42, 48.90], nodes: [
    ["Montmartre", 2.343, 48.886], ["La Villette", 2.388, 48.890], ["Champs-Elysees", 2.307, 48.872],
    ["Louvre", 2.337, 48.861], ["Bastille", 2.369, 48.853], ["Eiffel Tower", 2.294, 48.858],
    ["Latin Quarter", 2.347, 48.849], ["Bercy", 2.382, 48.838], ["Montparnasse", 2.323, 48.840],
    ["Place d'Italie", 2.355, 48.831],
  ] },
  { id: "amsterdam", bbox: [4.83, 52.33, 4.96, 52.40], nodes: [
    ["Centraal", 4.900, 52.379], ["Jordaan", 4.881, 52.374], ["Dam", 4.893, 52.373],
    ["Plantage", 4.912, 52.366], ["Museumplein", 4.879, 52.358], ["De Pijp", 4.894, 52.355],
    ["Oost", 4.927, 52.359], ["Vondelpark", 4.869, 52.358], ["Zuid", 4.873, 52.341],
    ["Oud-West", 4.866, 52.366],
  ] },
  { id: "berlin", bbox: [13.15, 52.45, 13.55, 52.56], nodes: [
    ["Spandau", 13.200, 52.535], ["Charlottenburg", 13.305, 52.516], ["Mitte", 13.405, 52.520],
    ["Prenzlauer Berg", 13.424, 52.540], ["Friedrichshain", 13.454, 52.515], ["Kreuzberg", 13.403, 52.499],
    ["Neukolln", 13.435, 52.481], ["Tempelhof", 13.385, 52.470], ["Schoneberg", 13.353, 52.483],
    ["Lichtenberg", 13.500, 52.515],
  ] },
  { id: "sanfrancisco", bbox: [-122.53, 37.70, -122.35, 37.83], nodes: [
    ["Marina", -122.437, 37.803], ["North Beach", -122.410, 37.806], ["Richmond", -122.477, 37.780],
    ["Nob Hill", -122.415, 37.793], ["Financial District", -122.400, 37.794], ["Haight", -122.446, 37.770],
    ["Mission", -122.418, 37.760], ["Castro", -122.435, 37.762], ["Sunset", -122.494, 37.756],
    ["Bayview", -122.390, 37.730],
  ] },
];

const dir = process.argv[2];
const ocean = JSON.parse(readFileSync(`${dir}/ne_10m_ocean.geojson`, "utf8"));
const lakes = JSON.parse(readFileSync(`${dir}/ne_10m_lakes.geojson`, "utf8"));
const rivers = JSON.parse(readFileSync(`${dir}/ne_10m_rivers_lake_centerlines.geojson`, "utf8"));

function projector(bbox: BBox) {
  const [minLon, minLat, maxLon, maxLat] = bbox;
  const k = Math.cos(((minLat + maxLat) / 2) * Math.PI / 180);
  const pxmin = minLon * k, pxmax = maxLon * k, pymin = -maxLat, pymax = -minLat;
  const W = pxmax - pxmin, H = pymax - pymin;
  const scale = Math.min(0.95 / W, MAP_ASPECT / H);
  const ox = (1 - W * scale) / 2, oy = (MAP_ASPECT - H * scale) / 2;
  return (lon: number, lat: number): Pt =>
    [ox + (lon * k - pxmin) * scale, oy + (-lat - pymin) * scale];
}

function inBox([lon, lat]: Pt, [m0, m1, m2, m3]: BBox) { return lon >= m0 && lon <= m2 && lat >= m1 && lat <= m3; }

function clipPoly(ring: Pt[], [minX, minY, maxX, maxY]: BBox): Pt[] {
  const edges = [(p: Pt) => p[0] >= minX, (p: Pt) => p[0] <= maxX, (p: Pt) => p[1] >= minY, (p: Pt) => p[1] <= maxY];
  const inter = [
    (a: Pt, b: Pt): Pt => [minX, a[1] + (b[1] - a[1]) * ((minX - a[0]) / (b[0] - a[0]))],
    (a: Pt, b: Pt): Pt => [maxX, a[1] + (b[1] - a[1]) * ((maxX - a[0]) / (b[0] - a[0]))],
    (a: Pt, b: Pt): Pt => [a[0] + (b[0] - a[0]) * ((minY - a[1]) / (b[1] - a[1])), minY],
    (a: Pt, b: Pt): Pt => [a[0] + (b[0] - a[0]) * ((maxY - a[1]) / (b[1] - a[1])), maxY],
  ];
  let out = ring;
  for (let e = 0; e < 4; e++) {
    const inp = out; out = [];
    for (let i = 0; i < inp.length; i++) {
      const cur = inp[i], prev = inp[(i + inp.length - 1) % inp.length];
      if (edges[e](cur)) { if (!edges[e](prev)) out.push(inter[e](prev, cur)); out.push(cur); }
      else if (edges[e](prev)) out.push(inter[e](prev, cur));
    }
    if (!out.length) return [];
  }
  return out;
}

function polysOf(geom: any): Pt[][] {
  if (geom.type === "Polygon") return [geom.coordinates[0]];
  if (geom.type === "MultiPolygon") return geom.coordinates.map((p: Pt[][]) => p[0]);
  return [];
}
function linesOf(geom: any): Pt[][] {
  if (geom.type === "LineString") return [geom.coordinates];
  if (geom.type === "MultiLineString") return geom.coordinates;
  return [];
}
function fmt(r: Pt[]) { return "[" + r.map(([x, y]) => `(${x.toFixed(4)}, ${y.toFixed(4)})`).join(", ") + "]"; }

const waterOut: Record<string, Pt[][]> = {};
const riverOut: Record<string, Pt[][]> = {};
const nodeLines: string[] = [];

for (const c of CITIES) {
  const proj = projector(c.bbox);
  // Nodes
  nodeLines.push(`// ${c.id}`);
  nodeLines.push(c.nodes.map(([n, lon, lat]) => {
    const [x, y] = proj(lon, lat);
    return `("${n}", ${x.toFixed(3)}, ${y.toFixed(3)})`;
  }).join("\n"));

  // Water: ocean + lakes polygons clipped to bbox
  const wr: Pt[][] = [];
  for (const fc of [ocean, lakes]) {
    for (const f of fc.features) {
      for (const ring of polysOf(f.geometry)) {
        const cl = clipPoly(ring as Pt[], c.bbox);
        if (cl.length < 4) continue;
        wr.push(cl.map(([lon, lat]) => proj(lon, lat)));
      }
    }
  }
  waterOut[c.id] = wr;

  // Rivers: clip line segments to bbox, keep inside runs
  const rr: Pt[][] = [];
  for (const f of rivers.features) {
    for (const line of linesOf(f.geometry)) {
      let run: Pt[] = [];
      for (const p of line as Pt[]) {
        if (inBox(p, c.bbox)) run.push(proj(p[0], p[1]));
        else { if (run.length > 1) rr.push(run); run = []; }
      }
      if (run.length > 1) rr.push(run);
    }
  }
  riverOut[c.id] = rr;
  console.log(`${c.id}: water=${wr.length} rivers=${rr.length}`);
}

const swift = [
  "import Foundation",
  "",
  "// Generated by src/gen-city-outlines.ts from Natural Earth 10m (public domain).",
  "// Local water for the city district maps, projected to fit each board.",
  "extension BoardGeometry {",
  "    static let cityWater: [String: [[(Double, Double)]]] = [",
  Object.entries(waterOut).map(([id, rs]) => `    "${id}": [\n${rs.map((r) => "        " + fmt(r)).join(",\n")}\n    ],`).join("\n"),
  "    ]",
  "    static let cityRivers: [String: [[(Double, Double)]]] = [",
  Object.entries(riverOut).map(([id, rs]) => `    "${id}": [\n${rs.map((r) => "        " + fmt(r)).join(",\n")}\n    ],`).join("\n"),
  "    ]",
  "}",
  "",
].join("\n");
writeFileSync("ios/MessagesExtension/UI/CityOutlines.swift", swift);
writeFileSync("/tmp/city-nodes.txt", nodeLines.join("\n"));
console.log("wrote CityOutlines.swift; node coords -> /tmp/city-nodes.txt");
