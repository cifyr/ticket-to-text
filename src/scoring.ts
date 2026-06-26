import type { GameState, PlayerState, Route } from "./types.ts";

// Standard Ticket to Ride per-route point table (by length).
const ROUTE_POINTS: Record<number, number> = { 1: 1, 2: 2, 3: 4, 4: 7, 5: 10, 6: 15 };

export function routePoints(length: number): number {
  return ROUTE_POINTS[length] ?? length;
}

function playerRoutes(state: GameState, player: number): Route[] {
  return state.routes.filter((r) => r.claimedBy === player);
}

function adjacency(routes: Route[]): Map<number, { to: number; route: Route }[]> {
  const adj = new Map<number, { to: number; route: Route }[]>();
  const add = (from: number, to: number, route: Route) => {
    if (!adj.has(from)) adj.set(from, []);
    adj.get(from)!.push({ to, route });
  };
  for (const r of routes) {
    add(r.cityA, r.cityB, r);
    add(r.cityB, r.cityA, r);
  }
  return adj;
}

// Are the two cities connected through this player's claimed routes?
export function connected(routes: Route[], from: number, to: number): boolean {
  if (from === to) return true;
  const adj = adjacency(routes);
  const seen = new Set<number>([from]);
  const stack = [from];
  while (stack.length) {
    const city = stack.pop()!;
    for (const { to: next } of adj.get(city) ?? []) {
      if (next === to) return true;
      if (!seen.has(next)) { seen.add(next); stack.push(next); }
    }
  }
  return false;
}

// Tickets: + points if connected, - points if not (standard end scoring).
export function ticketScore(state: GameState, player: number): number {
  const routes = playerRoutes(state, player);
  return state.players[player].tickets.reduce(
    (sum, t) => sum + (connected(routes, t.cityA, t.cityB) ? t.points : -t.points),
    0,
  );
}

// Longest continuous path (trail: each segment used once), summed by length.
export function longestRoute(state: GameState, player: number): number {
  const routes = playerRoutes(state, player);
  const adj = adjacency(routes);
  let best = 0;
  const used = new Set<number>();

  const dfs = (city: number, total: number) => {
    if (total > best) best = total;
    for (const { to, route } of adj.get(city) ?? []) {
      if (used.has(route.id)) continue;
      used.add(route.id);
      dfs(to, total + route.length);
      used.delete(route.id);
    }
  };

  for (const city of adj.keys()) dfs(city, 0);
  return best;
}

export const LONGEST_ROUTE_BONUS = 10;

export interface FinalScore {
  routeScore: number;
  ticketScore: number;
  longestRoute: number;
  longestBonus: number;
  total: number;
}

export function finalScores(state: GameState): FinalScore[] {
  const longest = state.players.map((_, p) => longestRoute(state, p));
  const maxLongest = Math.max(...longest);

  return state.players.map((_, p) => {
    const routeScore = state.players[p].score;
    const tScore = ticketScore(state, p);
    // Every player tied for the longest path gets the bonus.
    const longestBonus = maxLongest > 0 && longest[p] === maxLongest ? LONGEST_ROUTE_BONUS : 0;
    return {
      routeScore,
      ticketScore: tScore,
      longestRoute: longest[p],
      longestBonus,
      total: routeScore + tScore + longestBonus,
    };
  });
}

// nil = tie, else winning player index.
export function finalWinner(state: GameState): number | null {
  const scores = finalScores(state);
  const max = Math.max(...scores.map((s) => s.total));
  const leaders = scores.flatMap((s, i) => (s.total === max ? [i] : []));
  return leaders.length === 1 ? leaders[0] : null;
}
