import Foundation

enum DeliveryState: String, Equatable {
    case idle = "Idle"
    case sending = "Sending"
    case sent = "Sent"
    case failed = "Error"

    private static let failurePrefixes = ["Error", "Failed", "NotSent", "Undelivered", "Rejected"]

    /// R1 stored SDK states via `String(describing:)`, e.g. `Error(code=..., message=...)`.
    init(storedValue: String) {
        if let state = DeliveryState(rawValue: storedValue) {
            self = state
        } else if Self.failurePrefixes.contains(where: storedValue.hasPrefix) {
            self = .failed
        } else {
            self = .sent
        }
    }
}
