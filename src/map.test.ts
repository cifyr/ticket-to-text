import { test } from "node:test";
import assert from "node:assert/strict";

import { MAPS, getMap, listMaps } from "./map.ts";

// Validates every registered board so a new map can't ship with bad data:
// in-range city indices, no self-loops, and a fully connected route graph
// (so destination tickets are always completable in principle).
test("every registered map is well-formed and connected", () => {
  for (const { id } of listMaps()) {
    const m = getMap(id);
    const n = m.cities.length;
    assert.ok(n >= 2, `${id}: has cities`);

    for (const [a, b, len] of m.routeDefs) {
      assert.ok(a >= 0 && a < n && b >= 0 && b < n, `${id}: route endpoints in range`);
      assert.notEqual(a, b, `${id}: no self-loop route`);
      assert.ok(len >= 1 && len <= 6, `${id}: route length 1..6`);
    }
    for (const [a, b, pts] of m.ticketDefs) {
      assert.ok(a >= 0 && a < n && b >= 0 && b < n, `${id}: ticket endpoints in range`);
      assert.notEqual(a, b, `${id}: ticket connects two cities`);
      assert.ok(pts > 0, `${id}: ticket worth points`);
    }

    // Connectivity: every city reachable from city 0 via the route graph.
    const adj: number[][] = Array.from({ length: n }, () => []);
    for (const [a, b] of m.routeDefs) { adj[a].push(b); adj[b].push(a); }
    const seen = new Set<number>([0]);
    const stack = [0];
    while (stack.length) {
      const u = stack.pop()!;
      for (const v of adj[u]) if (!seen.has(v)) { seen.add(v); stack.push(v); }
    }
    assert.equal(seen.size, n, `${id}: route graph is fully connected`);
  }
});

test("registry has USA and Europe", () => {
  assert.ok(MAPS.usa, "usa present");
  assert.ok(MAPS.europe, "europe present");
});
