import CoreGraphics

/// Marks events AntiIdle posts so the idle detector can tell them apart
/// from real user input. Stored in the event's eventSourceUserData field.
enum SyntheticEventTag {
    /// "ANTI" in ASCII.
    private static let value: Int64 = 0x414E_5449

    static func apply(to event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: value)
    }

    static func isTagged(_ event: CGEvent) -> Bool {
        return event.getIntegerValueField(.eventSourceUserData) == value
    }
}
