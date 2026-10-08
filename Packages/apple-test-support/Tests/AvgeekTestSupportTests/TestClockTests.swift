import Foundation
import XCTest
@testable import AvgeekTestSupport

final class TestClockTests: XCTestCase {
    func testSleepRecordsDelayAndAdvancesImmediately() async throws {
        let start = Date(timeIntervalSince1970: 1000)
        let clock = TestClock(now: start)

        try await clock.sleep(for: 2.5)

        XCTAssertEqual(clock.recordedSleeps, [2.5])
        XCTAssertEqual(clock.now, start.addingTimeInterval(2.5))
    }

    func testRetrySchedulerUsesTheClock() async throws {
        let clock = TestClock(now: Date(timeIntervalSince1970: 100))
        let scheduler = clock.retryScheduler

        XCTAssertEqual(scheduler.now(), Date(timeIntervalSince1970: 100))
        try await scheduler.sleep(4)

        XCTAssertEqual(clock.recordedSleeps, [4])
        XCTAssertEqual(scheduler.now(), Date(timeIntervalSince1970: 104))
    }

    func testNegativeAndNaNDelaysAreBoundedToZero() async throws {
        let clock = TestClock()

        try await clock.sleep(for: -10)
        try await clock.sleep(for: .nan)

        XCTAssertEqual(clock.recordedSleeps, [0, 0])
        XCTAssertEqual(clock.now, Date(timeIntervalSince1970: 0))
    }

    func testConcurrentSleepsDoNotLoseUpdates() async throws {
        let clock = TestClock()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for delay in 1 ... 20 {
                group.addTask {
                    try await clock.sleep(for: TimeInterval(delay))
                }
            }
            try await group.waitForAll()
        }

        XCTAssertEqual(clock.recordedSleeps.sorted(), (1 ... 20).map(TimeInterval.init))
        XCTAssertEqual(clock.now, Date(timeIntervalSince1970: 210))
    }

    func testAdvanceAndResetControlTimeAndHistory() async throws {
        let clock = TestClock()
        clock.advance(by: 3)
        try await clock.sleep(for: 2)

        clock.reset(to: Date(timeIntervalSince1970: 50))

        XCTAssertEqual(clock.now, Date(timeIntervalSince1970: 50))
        XCTAssertEqual(clock.recordedSleeps, [])
    }
}
