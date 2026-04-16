import Foundation

struct ProjectFolderReference: Equatable, Codable {
    var path: String
    var bookmarkData: Data?

    var resolvedURL: URL {
        URL(filePath: path)
    }

    static func make(from url: URL) -> ProjectFolderReference {
        let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return ProjectFolderReference(
            path: url.path(percentEncoded: false),
            bookmarkData: bookmarkData
        )
    }

    func resolveBookmark() -> BookmarkResolution {
        guard let bookmarkData else {
            return BookmarkResolution(url: resolvedURL, didRefreshBookmark: false)
        }

        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return BookmarkResolution(url: url ?? resolvedURL, didRefreshBookmark: isStale)
    }
}

struct BookmarkResolution {
    var url: URL?
    var didRefreshBookmark: Bool
}
