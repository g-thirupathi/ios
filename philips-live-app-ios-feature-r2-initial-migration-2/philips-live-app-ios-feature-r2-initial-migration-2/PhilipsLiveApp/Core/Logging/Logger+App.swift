import OSLog

extension Logger {
    nonisolated init(category: String) {
        self.init(subsystem: "PhilipsLiveApp", category: category)
    }
}
