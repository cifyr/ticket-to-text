import Foundation

// Port of src/rng.ts mulberry32 using UInt32 wrap-around (&+, &*) to mirror
// JS's int32 semantics. Deterministic so a seed reproduces the same deck.
struct Mulberry32 {
    private var a: UInt32
    init(seed: UInt32) { a = seed }

    mutating func next() -> Double {
        a = a &+ 0x6D2B79F5
        var t: UInt32 = a
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        let result = t ^ (t >> 14)
        return Double(result) / 4294967296.0
    }
}

func shuffle<T>(_ items: [T], _ rng: inout Mulberry32) -> [T] {
    var out = items
    var i = out.count - 1
    while i > 0 {
        let j = Int(rng.next() * Double(i + 1))
        out.swapAt(i, j)
        i -= 1
    }
    return out
}
