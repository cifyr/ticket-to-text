import type { GameState } from "./types.ts";

// Models the MSMessage.url payload: encode the whole state into one string that
// rides inside the message, decode it on the other phone. Swift port: base64 a
// JSONEncoder().encode(state) into a URLQueryItem (see RESEARCH.md §7).

export function encodeState(state: GameState): string {
  const json = JSON.stringify(state);
  return Buffer.from(json, "utf8").toString("base64url");
}

export function decodeState(payload: string): GameState {
  const json = Buffer.from(payload, "base64url").toString("utf8");
  return JSON.parse(json) as GameState;
}

// Rough size guard. iMessage URL payloads handle a few KB comfortably; v0 state
// is tiny, but log if it ever grows so we catch it before it bites on-device.
export function payloadByteLength(state: GameState): number {
  return Buffer.byteLength(encodeState(state), "utf8");
}
