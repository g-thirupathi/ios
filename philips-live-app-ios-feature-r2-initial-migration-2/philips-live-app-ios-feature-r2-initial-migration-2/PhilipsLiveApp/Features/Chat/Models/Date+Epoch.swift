import Foundation

extension Date {
    private static let millisecondsPerSecond = 1000.0
    private static let secondsBoundary = 1_000_000_000_000.0
    private static let latestEpochMilliseconds = 253_402_300_799_999.0

    /// Accepts milliseconds, or seconds for values below 10^12, as R1 stored both. A value that is not a real point in
    /// time, e.g. from damaged saved data, is rejected: it would crash `epochMilliseconds` when saved again.
    init?(epochValue: Double) {
        guard epochValue.isFinite, abs(epochValue) <= Self.latestEpochMilliseconds else { return nil }
        let seconds = epochValue > Self.secondsBoundary ? epochValue / Self.millisecondsPerSecond : epochValue
        self.init(timeIntervalSince1970: seconds)
    }

    var epochMilliseconds: String {
        String(Int64(timeIntervalSince1970 * Self.millisecondsPerSecond))
    }
}
