import Foundation

public struct FileCursor: Sendable, Equatable {
    public let jsonlPath: String
    public let source: Source
    public let lastIngestedLine: Int
    public let lastIngestedAt: Date
    public let fileSizeAtCursor: Int64

    public init(
        jsonlPath: String,
        source: Source,
        lastIngestedLine: Int,
        lastIngestedAt: Date,
        fileSizeAtCursor: Int64
    ) {
        self.jsonlPath = jsonlPath
        self.source = source
        self.lastIngestedLine = lastIngestedLine
        self.lastIngestedAt = lastIngestedAt
        self.fileSizeAtCursor = fileSizeAtCursor
    }
}
