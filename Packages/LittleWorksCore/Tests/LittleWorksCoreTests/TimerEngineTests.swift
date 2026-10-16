import Foundation
import Testing
@testable import LittleWorksCore

final class FakeTime: TimeSource {
    var current: Date
    init(_ date: Date) { current = date }
    func now() -> Date { current }
    func advance(_ seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

private let t0 = Date(timeIntervalSince1970: 1_760_000_000)

private func makeEngine() -> (TimerEngine, InMemoryEntryStore, FakeTime) {
    let store = InMemoryEntryStore()
    let time = FakeTime(t0)
    return (TimerEngine(store: store, time: time), store, time)
}

@Suite("TimerEngine")
struct TimerEngineTests {
    let a = UUID()
    let b = UUID()

    @Test func startCreatesActiveEntry() throws {
        let (engine, _, _) = makeEngine()
        let entry = try engine.start(clientId: a)
        #expect(entry.isActive)
        #expect(try engine.activeEntry()?.clientId == a)
    }

    @Test func stopClosesEntryWithExactDuration() throws {
        let (engine, _, time) = makeEngine()
        try engine.start(clientId: a)
        time.advance(900)
        let closed = try engine.stop()
        #expect(closed?.duration(at: time.now()) == 900)
        #expect(try engine.activeEntry() == nil)
    }

    @Test func switchingStopsOldAndStartsNewAtSameInstant() throws {
        let (engine, store, time) = makeEngine()
        let first = try engine.start(clientId: a)
        time.advance(600)
        let second = try engine.start(clientId: b)

        let all = try store.entries(in: DateInterval(start: t0, duration: 10_000))
        #expect(all.count == 2)
        let stored = try #require(all.first { $0.id == first.id })
        #expect(stored.endTime == second.startTime)
        #expect(all.filter(\.isActive).count == 1)
    }

    @Test func startingRunningClientIsNoOp() throws {
        let (engine, store, time) = makeEngine()
        let first = try engine.start(clientId: a)
        time.advance(60)
        let again = try engine.start(clientId: a)
        #expect(again.id == first.id)
        #expect(try store.entries(in: DateInterval(start: t0, duration: 10_000)).count == 1)
    }

    @Test func toggleStartsThenStops() throws {
        let (engine, _, time) = makeEngine()
        try engine.toggle(clientId: a)
        #expect(try engine.activeEntry() != nil)
        time.advance(30)
        try engine.toggle(clientId: a)
        #expect(try engine.activeEntry() == nil)
    }

    @Test func stopWithoutRunningTimerReturnsNil() throws {
        let (engine, _, _) = makeEngine()
        #expect(try engine.stop() == nil)
    }

    @Test func stopAtEarlierMomentCutsOff() throws {
        let (engine, _, time) = makeEngine()
        try engine.start(clientId: a)
        time.advance(7200)
        let closed = try engine.stop(at: t0.addingTimeInterval(600))
        #expect(closed?.endTime == t0.addingTimeInterval(600))
    }

    @Test func stopAtIsClampedToStartAndNow() throws {
        let (engine, _, time) = makeEngine()
        try engine.start(clientId: a)
        time.advance(100)
        let before = try engine.stop(at: t0.addingTimeInterval(-500))
        #expect(before?.endTime == t0)

        try engine.start(clientId: a)
        let startedAt = time.now()
        time.advance(100)
        let after = try engine.stop(at: time.now().addingTimeInterval(5000))
        #expect(after?.endTime == startedAt.addingTimeInterval(100))
    }

    @Test func updateRejectsEndBeforeStart() throws {
        let (engine, _, _) = makeEngine()
        let bad = TimeEntry(clientId: a, startTime: t0, endTime: t0.addingTimeInterval(-60))
        #expect(throws: TimerError.endBeforeStart) { try engine.update(bad) }
    }

    @Test func updateSavesValidEdit() throws {
        let (engine, store, time) = makeEngine()
        let good = TimeEntry(clientId: a, startTime: t0, endTime: t0.addingTimeInterval(3600), note: "Homepage")
        try engine.update(good)
        let found = try store.entries(in: DateInterval(start: t0, duration: 10_000))
        #expect(found.first?.note == "Homepage")
        #expect(found.first?.updatedAt == time.now())
    }
}

@Suite("Totals")
struct TotalsTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Amsterdam")!
        return c
    }

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test func entryWithinOneDayHasOneSegment() {
        let e = TimeEntry(clientId: UUID(), startTime: date(2026, 10, 12, 9, 15), endTime: date(2026, 10, 12, 11, 30))
        let segs = Totals.segments(of: e, now: date(2026, 10, 13, 0), calendar: calendar)
        #expect(segs.count == 1)
        #expect(segs[0].duration == 8100)
    }

    @Test func entryAcrossMidnightIsSplit() {
        let e = TimeEntry(clientId: UUID(), startTime: date(2026, 10, 12, 23, 0), endTime: date(2026, 10, 13, 1, 30))
        let segs = Totals.segments(of: e, now: date(2026, 10, 14, 0), calendar: calendar)
        #expect(segs.count == 2)
        #expect(segs[0].duration == 3600)
        #expect(segs[1].duration == 5400)
    }

    @Test func dstChangeDayHasCorrectLength() {
        // 2026-10-25: clocks go back, the day is 25 hours long in Amsterdam.
        let e = TimeEntry(clientId: UUID(), startTime: date(2026, 10, 24, 22, 0), endTime: date(2026, 10, 26, 2, 0))
        let segs = Totals.segments(of: e, now: date(2026, 10, 27, 0), calendar: calendar)
        #expect(segs.count == 3)
        #expect(segs[1].duration == 25 * 3600)
        #expect(segs.reduce(0) { $0 + $1.duration } == e.duration(at: date(2026, 10, 27, 0)))
    }

    @Test func runningEntryCountsUpToNow() {
        let e = TimeEntry(clientId: UUID(), startTime: date(2026, 10, 12, 9))
        let segs = Totals.segments(of: e, now: date(2026, 10, 12, 10), calendar: calendar)
        #expect(segs.count == 1)
        #expect(segs[0].duration == 3600)
    }

    @Test func secondsPerClientClipsAtIntervalEdges() {
        let client = UUID()
        let e = TimeEntry(clientId: client, startTime: date(2026, 10, 12, 23, 0), endTime: date(2026, 10, 13, 2, 0))
        let day13 = DateInterval(start: date(2026, 10, 13, 0), end: date(2026, 10, 14, 0))
        let totals = Totals.secondsPerClient(entries: [e], in: day13, now: date(2026, 10, 14, 0))
        #expect(totals[client] == 7200)
    }
}
