import AvgeekNetworking
import Foundation

/// A deterministic clock that records sleeps and advances immediately.
public final class TestClock: @unchecked Sendable {
    private static let maximumSleep = TimeInterval(UInt64.max / 1_000_000_000)

    private struct State {
        var now: Date
        var recordedSleeps: [TimeInterval] = []
    }

    private let state: Locked<State>

    public init(now: Date = Date(timeIntervalSince1970: 0)) {
        state = Locked(State(now: now))
    }

    public var now: Date {
        state.withValue(\.now)
    }

    public var recordedSleeps: [TimeInterval] {
        state.withValue(\.recordedSleeps)
    }

    public var retryScheduler: RetryScheduler {
        RetryScheduler(
            now: { [self] in now },
            sleep: { [self] duration in try await sleep(for: duration) }
        )
    }

    public func advance(by duration: TimeInterval) {
        let bounded = Self.bounded(duration)
        state.withValue { state in
            state.now = state.now.addingTimeInterval(bounded)
        }
    }

    public func sleep(for duration: TimeInterval) async throws {
        try Task.checkCancellation()
        let bounded = Self.bounded(duration)
        state.withValue { state in
            state.recordedSleeps.append(bounded)
            state.now = state.now.addingTimeInterval(bounded)
        }
    }

    public func reset(to date: Date = Date(timeIntervalSince1970: 0)) {
        state.withValue { state in
            state.now = date
            state.recordedSleeps.removeAll(keepingCapacity: true)
        }
    }

    private static func bounded(_ duration: TimeInterval) -> TimeInterval {
        guard !duration.isNaN else { return 0 }
        return min(max(0, duration), maximumSleep)
    }
}
