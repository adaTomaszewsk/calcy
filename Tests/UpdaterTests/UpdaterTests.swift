import Foundation
import Testing
@testable import Updater

@Suite("Wersje")
struct AppVersionTests {
    @Test(arguments: [
        ("0.1.7", "0.1.8", true),
        ("0.1.7", "0.2.0", true),
        ("0.9.9", "1.0.0", true),
        ("1.0", "1.0.0", false),
        ("0.1.10", "0.1.9", false),
        ("v0.1.2", "0.1.3", true),
    ])
    func comparison(older: String, newer: String, isOlder: Bool) throws {
        let a = try #require(AppVersion(older))
        let b = try #require(AppVersion(newer))
        #expect((a < b) == isOlder)
    }

    @Test func parsesAndPrints() throws {
        #expect(AppVersion("v1.2.3")?.description == "1.2.3")
        #expect(AppVersion("1.2.3-beta")?.description == "1.2.3")
        #expect(AppVersion("wersja") == nil)
        #expect(AppVersion("") == nil)
    }
}

@Suite("Wydania z GitHuba")
struct ReleaseTests {
    private let json = """
    {
      "tag_name": "v0.1.7",
      "name": "Calcy 0.1.7",
      "body": "Poprawki",
      "html_url": "https://github.com/adaTomaszewsk/calcy/releases/tag/v0.1.7",
      "draft": false,
      "prerelease": false,
      "assets": [
        {"name": "notatki.txt", "browser_download_url": "https://example.com/notatki.txt"},
        {"name": "Calcy.dmg", "browser_download_url": "https://example.com/Calcy.dmg"}
      ]
    }
    """

    @Test func parsesRelease() throws {
        let release = try GitHubReleases.parseLatest(Data(json.utf8))
        #expect(release.version == AppVersion("0.1.7"))
        #expect(release.title == "Calcy 0.1.7")
        #expect(release.downloadURL?.lastPathComponent == "Calcy.dmg")
    }

    @Test func rejectsDrafts() throws {
        let draft = json.replacingOccurrences(of: "\"draft\": false", with: "\"draft\": true")
        #expect(throws: GitHubReleases.ParseError.draftOrPrerelease) {
            try GitHubReleases.parseLatest(Data(draft.utf8))
        }
    }

    @Test func buildsLatestURL() {
        #expect(GitHubReleases.latestURL(owner: "adaTomaszewsk", repository: "calcy").absoluteString
            == "https://api.github.com/repos/adaTomaszewsk/calcy/releases/latest")
    }
}

@Suite("Częstotliwość sprawdzania")
struct CheckScheduleTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func firstCheckIsAllowed() {
        #expect(CheckSchedule().allowsCheck(now: now))
    }

    @Test func waitsForInterval() {
        var schedule = CheckSchedule()
        schedule.recordSuccess(now: now)
        #expect(!schedule.allowsCheck(now: now.addingTimeInterval(3600)))
        #expect(schedule.allowsCheck(now: now.addingTimeInterval(6 * 3600)))
        // Ręczne sprawdzenie omija odstęp.
        #expect(schedule.allowsCheck(now: now.addingTimeInterval(60), manual: true))
    }

    @Test func rateLimitBlocksEvenManualChecks() {
        var schedule = CheckSchedule()
        let reset = now.addingTimeInterval(1800)
        schedule.recordRateLimit(now: now, resetAt: reset, retryAfter: nil)
        #expect(!schedule.allowsCheck(now: now.addingTimeInterval(60), manual: true))
        // Po wygaśnięciu limitu ręczne sprawdzenie znów działa; automatyczne czeka na swój odstęp.
        #expect(schedule.allowsCheck(now: reset.addingTimeInterval(1), manual: true))
        #expect(!schedule.allowsCheck(now: reset.addingTimeInterval(1)))
    }

    @Test func retryAfterHeaderIsUsed() {
        var schedule = CheckSchedule()
        schedule.recordRateLimit(now: now, resetAt: nil, retryAfter: 120)
        #expect(schedule.blockedUntil == now.addingTimeInterval(120))
    }

    @Test func failuresBackOffExponentially() {
        var schedule = CheckSchedule()
        schedule.recordFailure(now: now)
        #expect(schedule.blockedUntil == now.addingTimeInterval(60))
        schedule.recordFailure(now: now)
        #expect(schedule.blockedUntil == now.addingTimeInterval(120))
        for _ in 0..<20 { schedule.recordFailure(now: now) }
        #expect(schedule.blockedUntil == now.addingTimeInterval(CheckSchedule.maximumBackoff))
    }

    @Test func successResetsBackoff() {
        var schedule = CheckSchedule()
        schedule.recordFailure(now: now)
        schedule.recordSuccess(now: now)
        #expect(schedule.blockedUntil == nil)
        #expect(schedule.failureCount == 0)
    }
}

@Suite("Zapamiętane wydanie")
struct ReleaseCodingTests {
    @Test func roundTrip() throws {
        let release = Release(
            version: AppVersion("0.1.7")!,
            title: "Calcy 0.1.7",
            notes: "Poprawki",
            pageURL: URL(string: "https://example.com/tag")!,
            downloadURL: URL(string: "https://example.com/Calcy.dmg")!
        )
        let data = try JSONEncoder().encode(release)
        #expect(try JSONDecoder().decode(Release.self, from: data) == release)
    }
}
