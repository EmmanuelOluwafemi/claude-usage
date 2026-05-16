import Foundation
import os

public struct Ingestor: Sendable {
    private static let logger = Logger(
        subsystem: "dev.emmanueloluwafemi.claude-usage",
        category: "ingest"
    )

    public let codexSessionsDir: URL
    public let lookbackDays: Int

    public init(
        codexSessionsDir: URL? = nil,
        lookbackDays: Int = 7
    ) {
        self.codexSessionsDir = codexSessionsDir ?? Self.defaultCodexSessionsDir
        self.lookbackDays = lookbackDays
    }

    public static var defaultCodexSessionsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions")
    }

    public struct Result: Sendable, Equatable {
        public let filesConsidered: Int
        public let filesScanned: Int
        public let observationsInserted: Int

        public init(filesConsidered: Int, filesScanned: Int, observationsInserted: Int) {
            self.filesConsidered = filesConsidered
            self.filesScanned = filesScanned
            self.observationsInserted = observationsInserted
        }
    }

    public func runColdStartScan(
        now: Date = Date(),
        database: Database = .shared
    ) async throws -> Result {
        guard FileManager.default.fileExists(atPath: codexSessionsDir.path) else {
            Self.logger.info("codex sessions dir not present: \(codexSessionsDir.path, privacy: .public)")
            return Result(filesConsidered: 0, filesScanned: 0, observationsInserted: 0)
        }

        let cutoff = now.addingTimeInterval(-TimeInterval(lookbackDays) * 86_400)
        let candidates = try recentJSONLFiles(under: codexSessionsDir, modifiedAfter: cutoff)
        Self.logger.info(
            "cold-start scan: \(candidates.count, privacy: .public) candidate files (lookback=\(lookbackDays, privacy: .public)d)"
        )

        var filesScanned = 0
        var totalInserted = 0

        for fileURL in candidates {
            try Task.checkCancellation()
            let inserted = try await ingestFile(at: fileURL, database: database)
            if inserted > 0 { filesScanned += 1 }
            totalInserted += inserted
        }

        Self.logger.info(
            "cold-start complete: \(filesScanned, privacy: .public) files / \(totalInserted, privacy: .public) observations"
        )
        return Result(
            filesConsidered: candidates.count,
            filesScanned: filesScanned,
            observationsInserted: totalInserted
        )
    }

    func ingestFile(at file: URL, database: Database) async throws -> Int {
        let fileSize = Int64(
            (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        )

        if let existing = try await database.cursor(forPath: file.path),
           fileSize == existing.fileSizeAtCursor {
            return 0
        }

        var batch: [CodexObservation] = []
        var insertedCount = 0
        var lastLineNo = -1
        let batchSize = 100

        for try await parsed in CodexParser.parse(file: file, fromLine: 0) {
            batch.append(parsed.observation)
            lastLineNo = parsed.lineNo
            if batch.count >= batchSize {
                try await database.insertCodexObservations(batch)
                insertedCount += batch.count
                batch.removeAll(keepingCapacity: true)
            }
        }
        if !batch.isEmpty {
            try await database.insertCodexObservations(batch)
            insertedCount += batch.count
        }

        let cursor = FileCursor(
            jsonlPath: file.path,
            source: .codex,
            lastIngestedLine: lastLineNo,
            lastIngestedAt: Date(),
            fileSizeAtCursor: fileSize
        )
        try await database.upsertCursor(cursor)
        return insertedCount
    }

    private func recentJSONLFiles(under root: URL, modifiedAfter cutoff: Date) throws -> [URL] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var matches: [(url: URL, mtime: Date)] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: resourceKeys)
            guard values.isRegularFile == true,
                  url.pathExtension == "jsonl",
                  let mtime = values.contentModificationDate,
                  mtime >= cutoff
            else { continue }
            matches.append((url, mtime))
        }

        return matches.sorted { $0.mtime < $1.mtime }.map(\.url)
    }
}
