import Foundation
import Testing
@testable import LittleWorksCore

private let t0 = Date(timeIntervalSince1970: 1_760_000_000)
private let everything = DateInterval(start: .distantPast, end: .distantFuture)

@Suite("Projects")
struct ProjectTests {
    let client = UUID()

    @Test func secondsPerProjectIgnoresEntriesWithoutProject() {
        let p1 = UUID(), p2 = UUID()
        let entries = [
            TimeEntry(clientId: client, projectId: p1, startTime: t0, endTime: t0.addingTimeInterval(3600)),
            TimeEntry(clientId: client, projectId: p1, startTime: t0.addingTimeInterval(7200), endTime: t0.addingTimeInterval(9000)),
            TimeEntry(clientId: client, projectId: p2, startTime: t0, endTime: t0.addingTimeInterval(600)),
            TimeEntry(clientId: client, projectId: nil, startTime: t0, endTime: t0.addingTimeInterval(999)),
        ]
        let totals = Totals.secondsPerProject(entries: entries, in: everything, now: t0)
        #expect(totals == [p1: 5400, p2: 600])
    }

    @Test func secondsPerProjectClipsAtIntervalAndCountsRunningEntry() {
        let p = UUID()
        let entries = [TimeEntry(clientId: client, projectId: p, startTime: t0, endTime: nil)]
        let window = DateInterval(start: t0.addingTimeInterval(600), end: t0.addingTimeInterval(10_000))
        let totals = Totals.secondsPerProject(entries: entries, in: window, now: t0.addingTimeInterval(1800))
        #expect(totals[p] == 1200)
    }

    @Test func fixedPriceEffectiveRateFallsAsHoursGrow() {
        let project = Project(clientId: client, name: "Website", kind: .fixed, price: 1000)
        let at10 = ProjectMath.stats(for: project, clientRate: nil, seconds: 10 * 3600)
        let at20 = ProjectMath.stats(for: project, clientRate: nil, seconds: 20 * 3600)
        #expect(at10.effectiveRate == 100)
        #expect(at20.effectiveRate == 50)
        #expect(at20.revenue == 1000)
    }

    @Test func fixedPriceWithoutHoursHasNoEffectiveRate() {
        let project = Project(clientId: client, name: "Website", kind: .fixed, price: 1000)
        let stats = ProjectMath.stats(for: project, clientRate: nil, seconds: 0)
        #expect(stats.effectiveRate == nil)
        #expect(stats.revenue == 1000)
    }

    @Test func fixedProjectWithoutPriceHasNoRevenue() {
        let project = Project(clientId: client, name: "Website", kind: .fixed)
        let stats = ProjectMath.stats(for: project, clientRate: 80, seconds: 3600)
        #expect(stats.revenue == nil)
        #expect(stats.effectiveRate == nil)
    }

    @Test func hourlyProjectUsesOwnRateThenClientRate() {
        let own = Project(clientId: client, name: "A", kind: .hourly, price: 90)
        let inherit = Project(clientId: client, name: "B", kind: .hourly)
        #expect(ProjectMath.stats(for: own, clientRate: 75, seconds: 7200).revenue == 180)
        #expect(ProjectMath.stats(for: inherit, clientRate: 75, seconds: 7200).revenue == 150)
        #expect(ProjectMath.stats(for: inherit, clientRate: nil, seconds: 7200).revenue == nil)
    }

    @Test func progressAndRemainingAgainstEstimate() {
        let project = Project(clientId: client, name: "X", estimatedHours: 40)
        let half = ProjectMath.stats(for: project, clientRate: nil, seconds: 20 * 3600)
        #expect(half.progress == 0.5)
        #expect(half.hoursRemaining == 20)
        let over = ProjectMath.stats(for: project, clientRate: nil, seconds: 50 * 3600)
        #expect(over.progress == 1.25)
        #expect(over.hoursRemaining == -10)
    }

    @Test func missingOrZeroEstimateGivesNoProgress() {
        let none = Project(clientId: client, name: "X")
        let zero = Project(clientId: client, name: "Y", estimatedHours: 0)
        #expect(ProjectMath.stats(for: none, clientRate: nil, seconds: 3600).progress == nil)
        #expect(ProjectMath.stats(for: zero, clientRate: nil, seconds: 3600).progress == nil)
        #expect(ProjectMath.stats(for: zero, clientRate: nil, seconds: 3600).hoursRemaining == nil)
    }

    @Test func projectSurvivesJSONRoundTrip() throws {
        let p = Project(clientId: client, name: "Rond", kind: .fixed, price: 1234.5, estimatedHours: 12.5)
        let back = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        #expect(back == p)
    }

    @Test func expectedIncomeMixesGeneralHourlyAndSkipsFixed() {
        let own = Project(clientId: client, name: "A", kind: .hourly, price: 100)
        let inherit = Project(clientId: client, name: "B", kind: .hourly)
        let fixed = Project(clientId: client, name: "C", kind: .fixed, price: 5000)
        // 10h total: 2h on A (100/u), 1h on B (client 50/u), 3h on fixed, 4h general (50/u)
        let income = ProjectMath.expectedIncome(
            clientRate: 50, clientSeconds: 10 * 3600,
            projects: [(own, 2 * 3600), (inherit, 3600), (fixed, 3 * 3600)])
        #expect(income == Decimal(200 + 50 + 200))
    }

    @Test func expectedIncomeWithoutAnyRateIsNil() {
        let p = Project(clientId: client, name: "A", kind: .hourly)
        #expect(ProjectMath.expectedIncome(clientRate: nil, clientSeconds: 3600, projects: [(p, 3600)]) == nil)
        #expect(ProjectMath.expectedIncome(clientRate: nil, clientSeconds: 3600, projects: []) == nil)
    }

    @Test func expectedIncomeFromProjectRateWorksWithoutClientRate() {
        let own = Project(clientId: client, name: "A", kind: .hourly, price: 80)
        #expect(ProjectMath.expectedIncome(clientRate: nil, clientSeconds: 3 * 3600, projects: [(own, 2 * 3600)]) == 160)
    }

    @Test func alertLevelsStartAt80And100Percent() {
        #expect(ProjectMath.alertLevel(progress: 0.79) == nil)
        #expect(ProjectMath.alertLevel(progress: 0.8) == 80)
        #expect(ProjectMath.alertLevel(progress: 0.99) == 80)
        #expect(ProjectMath.alertLevel(progress: 1) == 100)
        #expect(ProjectMath.alertLevel(progress: 1.6) == 100)
    }
}
