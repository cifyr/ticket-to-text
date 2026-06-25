import Foundation

#if DEBUG
// Test-only identity override. The server keys every player solely by their
// participantId (the device's localParticipantIdentifier UUID). By swapping in a
// stable synthetic UUID + name we make this one device act as a different player,
// so you can drive a multi-player game solo: create a lobby as "You", switch to
// "Alt A" to join and ready up, switch back to "You" to start, etc.
enum DebugIdentity {
    private static let slotKey = "debugIdentitySlot"

    // Slot 0 is your real device identity; the rest are synthetic alts.
    static let slotNames = ["You", "Alt A", "Alt B"]

    static var slot: Int {
        get { min(max(UserDefaults.standard.integer(forKey: slotKey), 0), slotNames.count - 1) }
        set { UserDefaults.standard.set(newValue, forKey: slotKey) }
    }

    static var label: String { slotNames[slot] }

    static func cycle() { slot = (slot + 1) % slotNames.count }

    // nil = real identity (slot 0). Otherwise a per-slot UUID persisted once so
    // the server recognizes the same alt across launches.
    static func overrideID() -> String? {
        guard slot > 0 else { return nil }
        let key = "debugAltUUID\(slot)"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }

    static func overrideName() -> String? {
        guard slot > 0 else { return nil }
        return slotNames[slot]
    }
}
#endif
