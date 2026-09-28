import AppKit
import Observation
import Updater

/// Sprawdza wydania Calcy na GitHubie, pobiera instalator i podmienia aplikację.
@MainActor
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading(Double)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var lastCheck: Date?

    /// Wydanie nowsze od zainstalowanego, o ile nie zostało odłożone przyciskiem „Później”.
    var availableRelease: Release? {
        guard case .available(let release) = state, release.version.description != dismissedVersion else { return nil }
        return release
    }

    var automaticChecks: Bool {
        get { UserDefaults.standard.object(forKey: Keys.automatic) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Keys.automatic) }
    }

    let currentVersion: AppVersion

    private enum Keys {
        static let automatic = "updatesAutomatic"
        static let lastCheck = "updateLastCheck"
        static let blockedUntil = "updateBlockedUntil"
        static let etag = "updateETag"
        static let dismissed = "updateDismissedVersion"
        static let lastRelease = "updateLastRelease"
    }

    private static let owner = "adaTomaszewsk"
    private static let repository = "calcy"

    private var schedule: CheckSchedule
    private var dismissedVersion: String? {
        get { UserDefaults.standard.string(forKey: Keys.dismissed) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.dismissed) }
    }

    private init() {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        currentVersion = short.flatMap(AppVersion.init) ?? AppVersion("0.0.0")!
        let defaults = UserDefaults.standard
        schedule = CheckSchedule(
            lastCheck: defaults.object(forKey: Keys.lastCheck) as? Date,
            blockedUntil: defaults.object(forKey: Keys.blockedUntil) as? Date
        )
        lastCheck = schedule.lastCheck

        // Wydanie zapamiętane przy poprzednim sprawdzeniu – dzięki temu informacja
        // o aktualizacji jest widoczna od razu po starcie.
        if let release = Self.cachedRelease(), release.version > currentVersion {
            state = .available(release)
        }
    }

    private static func cachedRelease() -> Release? {
        guard let data = UserDefaults.standard.data(forKey: Keys.lastRelease) else { return nil }
        return try? JSONDecoder().decode(Release.self, from: data)
    }

    private static func cache(_ release: Release) {
        UserDefaults.standard.set(try? JSONEncoder().encode(release), forKey: Keys.lastRelease)
    }

    // MARK: - Sprawdzanie

    /// Pętla w tle: sprawdza zgodnie z harmonogramem (domyślnie co 6 godzin).
    func runPeriodically() async {
        while !Task.isCancelled {
            if automaticChecks {
                await check()
            }
            let wait = max(schedule.nextCheck(now: Date()).timeIntervalSinceNow, 900)
            try? await Task.sleep(for: .seconds(wait))
        }
    }

    func check(manual: Bool = false) async {
        guard schedule.allowsCheck(now: Date(), manual: manual) else { return }
        if case .downloading = state { return }
        state = .checking

        var request = URLRequest(url: GitHubReleases.latestURL(owner: Self.owner, repository: Self.repository))
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Calcy/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        if let etag = UserDefaults.standard.string(forKey: Keys.etag) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

            switch http.statusCode {
            case 200:
                UserDefaults.standard.set(http.value(forHTTPHeaderField: "ETag"), forKey: Keys.etag)
                let release = try GitHubReleases.parseLatest(data)
                Self.cache(release)
                state = release.version > currentVersion ? .available(release) : .upToDate
                finish(.success)
            case 304:
                // Bez zmian na serwerze – bierzemy wydanie zapamiętane wcześniej.
                if let release = Self.cachedRelease(), release.version > currentVersion {
                    state = .available(release)
                } else {
                    state = .upToDate
                }
                finish(.success)
            case 404:
                // Nie ma jeszcze żadnego wydania.
                state = .upToDate
                finish(.success)
            case 403, 429:
                finish(.rateLimited(reset: Self.resetDate(from: http), retryAfter: Self.retryAfter(from: http)))
                state = .upToDate
            default:
                throw URLError(.badServerResponse)
            }
        } catch {
            state = .failed("Nie udało się sprawdzić aktualizacji")
            finish(.failure)
            NSLog("Calcy: sprawdzanie aktualizacji nie powiodło się: \(error)")
        }
        AppController.shared.updateStatusItem(release: availableRelease)
    }

    private enum Outcome {
        case success
        case failure
        case rateLimited(reset: Date?, retryAfter: TimeInterval?)
    }

    private func finish(_ outcome: Outcome) {
        let now = Date()
        switch outcome {
        case .success: schedule.recordSuccess(now: now)
        case .failure: schedule.recordFailure(now: now)
        case .rateLimited(let reset, let retryAfter): schedule.recordRateLimit(now: now, resetAt: reset, retryAfter: retryAfter)
        }
        lastCheck = schedule.lastCheck
        UserDefaults.standard.set(schedule.lastCheck, forKey: Keys.lastCheck)
        UserDefaults.standard.set(schedule.blockedUntil, forKey: Keys.blockedUntil)
    }

    private static func resetDate(from response: HTTPURLResponse) -> Date? {
        guard let value = response.value(forHTTPHeaderField: "X-RateLimit-Reset"), let seconds = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
    }

    // MARK: - Aktualizacja

    /// Ukrywa informację o tej wersji do czasu kolejnego wydania.
    func dismissCurrentRelease() {
        guard case .available(let release) = state else { return }
        dismissedVersion = release.version.description
        AppController.shared.updateStatusItem(release: nil)
    }

    /// Pobiera instalator, podmienia aplikację i uruchamia ją ponownie.
    func install() async {
        guard case .available(let release) = state else { return }
        guard let url = release.downloadURL else {
            NSWorkspace.shared.open(release.pageURL)
            return
        }

        state = .downloading(0)
        do {
            let (file, _) = try await URLSession.shared.download(from: url)
            state = .downloading(0.9)
            try replaceApplication(withDiskImageAt: file)
        } catch {
            state = .failed("Nie udało się zainstalować aktualizacji")
            NSLog("Calcy: aktualizacja nie powiodła się: \(error)")
        }
    }

    /// Montuje .dmg, a podmianę i restart wykonuje skrypt – aplikacja musi się najpierw zamknąć.
    private func replaceApplication(withDiskImageAt image: URL) throws {
        let mountPoint = URL.temporaryDirectory.appending(path: "Calcy-update-\(UUID().uuidString)")
        let dmg = image.appendingPathExtension("dmg")
        try? FileManager.default.removeItem(at: dmg)
        try FileManager.default.moveItem(at: image, to: dmg)

        let attach = Process()
        attach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        attach.arguments = ["attach", dmg.path, "-nobrowse", "-quiet", "-mountpoint", mountPoint.path]
        try attach.run()
        attach.waitUntilExit()
        guard attach.terminationStatus == 0 else { throw URLError(.cannotOpenFile) }

        let source = mountPoint.appending(path: "Calcy.app")
        let destination = Bundle.main.bundleURL
        let script = """
        #!/bin/sh
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        rm -rf "\(destination.path)"
        /usr/bin/ditto "\(source.path)" "\(destination.path)"
        /usr/bin/xattr -dr com.apple.quarantine "\(destination.path)"
        /usr/bin/hdiutil detach "\(mountPoint.path)" -quiet
        rm -f "\(dmg.path)"
        open "\(destination.path)"
        """
        let scriptURL = URL.temporaryDirectory.appending(path: "calcy-update-\(UUID().uuidString).sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let runner = Process()
        runner.executableURL = URL(fileURLWithPath: "/bin/sh")
        runner.arguments = [scriptURL.path]
        try runner.run()

        NSApp.terminate(nil)
    }
}
