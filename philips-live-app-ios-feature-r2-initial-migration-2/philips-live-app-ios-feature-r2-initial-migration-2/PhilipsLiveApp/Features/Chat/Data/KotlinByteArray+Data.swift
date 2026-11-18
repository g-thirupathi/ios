import Foundation
@preconcurrency import MessengerTransport

extension KotlinByteArray {
    /// Carries a byte array back to the caller's actor. It is filled before it is handed over and only read after.
    nonisolated struct Handoff: @unchecked Sendable {
        let value: KotlinByteArray
    }

    /// Copies the files concurrently, off the main actor, and returns them in order.
    @concurrent
    static func copies(of files: [Data]) async -> [Handoff] {
        await withTaskGroup(of: (Int, Handoff).self) { group in
            for (index, data) in files.enumerated() {
                group.addTask(priority: .utility) { await (index, copy(of: data)) }
            }
            var copies = [Handoff?](repeating: nil, count: files.count)
            for await (index, bytes) in group {
                copies[index] = bytes
            }
            return copies.compactMap(\.self)
        }
    }

    /// Uses the SDK's bulk copy: a byte-by-byte loop across the bridge is far too slow for a large file. It still runs
    /// off the main actor.
    @concurrent
    private static func copy(of data: Data) async -> Handoff {
        Handoff(value: TransportUtil().nsDataToKotlinByteArray(data: data))
    }
}
