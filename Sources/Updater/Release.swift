import Foundation

/// Wydanie z GitHuba – tylko to, czego potrzebuje aktualizacja.
public struct Release: Sendable, Equatable, Codable {
    public let version: AppVersion
    public let title: String
    public let notes: String
    public let pageURL: URL
    /// Plik instalatora (.dmg) dołączony do wydania.
    public let downloadURL: URL?

    public init(version: AppVersion, title: String, notes: String, pageURL: URL, downloadURL: URL?) {
        self.version = version
        self.title = title
        self.notes = notes
        self.pageURL = pageURL
        self.downloadURL = downloadURL
    }
}

public enum GitHubReleases {
    public static func latestURL(owner: String, repository: String) -> URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repository)/releases/latest")!
    }

    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let name: String?
        let body: String?
        let html_url: URL
        let draft: Bool?
        let prerelease: Bool?
        let assets: [Asset]
    }

    public enum ParseError: Error, Equatable {
        case badVersion(String)
        case draftOrPrerelease
    }

    public static func parseLatest(_ data: Data) throws -> Release {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.draft != true, payload.prerelease != true else { throw ParseError.draftOrPrerelease }
        guard let version = AppVersion(payload.tag_name) else { throw ParseError.badVersion(payload.tag_name) }
        let installer = payload.assets.first { $0.name.lowercased().hasSuffix(".dmg") }
        return Release(
            version: version,
            title: payload.name ?? payload.tag_name,
            notes: payload.body ?? "",
            pageURL: payload.html_url,
            downloadURL: installer?.browser_download_url
        )
    }
}
