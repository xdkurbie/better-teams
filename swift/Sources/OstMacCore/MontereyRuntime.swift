// MontereyRuntime.swift — small stand-ins for standard-library and
// Foundation APIs that the macOS 26 SDK marks as macOS 13+.
// `Task.sleep(nanoseconds:)` and `NSLock` exist on macOS 12.
import Foundation

public enum BTSleep {
    static func seconds(_ value: Double) async throws {
        let ns = UInt64((max(0, value) * 1_000_000_000).rounded())
        try await Task.sleep(nanoseconds: ns)
    }
}

/// `OSAllocatedUnfairLock` (macOS 13+) with the `withLock` shape this app uses.
public final class LockedBox<State>: @unchecked Sendable {
    private let lock = NSLock()
    private var state: State

    public init(_ initial: State) { state = initial }

    public func withLock<T>(_ body: (inout State) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(&state)
    }
}
