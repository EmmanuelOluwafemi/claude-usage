import Foundation
import GRDB
import os

public actor Database {
    private static let logger = Logger(
        subsystem: "dev.emmanueloluwafemi.claude-usage",
        category: "db"
    )

    private let queue: DatabaseQueue

    public static let shared: Database = {
        do {
            return try Database()
        } catch {
            fatalError("Database.shared init failed: \(error)")
        }
    }()

    public init(path: String? = nil) throws {
        let resolvedPath = try path ?? Database.defaultDatabasePath()

        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        let queue = try DatabaseQueue(path: resolvedPath, configuration: config)
        self.queue = queue

        try Migrations.makeMigrator().migrate(queue)
        Database.logger.info("opened db at \(resolvedPath, privacy: .public)")
    }

    public static func makeInMemoryForTesting() throws -> Database {
        try Database(path: ":memory:")
    }

    private static func defaultDatabasePath() throws -> String {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("dev.emmanueloluwafemi.claude-usage")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("usage.sqlite").path
    }

    // MARK: - Codex

    public func insertCodexObservation(_ observation: CodexObservation) async throws {
        try await queue.write { db in
            try Database.insertCodex(observation, into: db)
        }
    }

    public func insertCodexObservations(_ observations: [CodexObservation]) async throws {
        try await queue.write { db in
            for observation in observations {
                try Database.insertCodex(observation, into: db)
            }
        }
    }

    public func latestCodexState() async throws -> CodexState? {
        try await queue.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT ts, plan_type,
                       primary_used_percent, primary_window_minutes, primary_resets_at,
                       secondary_used_percent, secondary_window_minutes, secondary_resets_at
                FROM codex_observations
                ORDER BY ts DESC
                LIMIT 1
                """) else {
                return nil
            }

            let primary = RateLimitWindow(
                usedPercent: row["primary_used_percent"],
                windowMinutes: row["primary_window_minutes"],
                resetsAt: Date(timeIntervalSince1970: TimeInterval(row["primary_resets_at"] as Int64))
            )

            let secondary: RateLimitWindow?
            if let usedPct: Double = row["secondary_used_percent"],
               let mins: Int = row["secondary_window_minutes"],
               let resets: Int64 = row["secondary_resets_at"] {
                secondary = RateLimitWindow(
                    usedPercent: usedPct,
                    windowMinutes: mins,
                    resetsAt: Date(timeIntervalSince1970: TimeInterval(resets))
                )
            } else {
                secondary = nil
            }

            return CodexState(
                primary: primary,
                secondary: secondary,
                observedAt: Date(timeIntervalSince1970: TimeInterval(row["ts"] as Int64)),
                planType: row["plan_type"]
            )
        }
    }

    // MARK: - Cursors

    public func cursor(forPath path: String) async throws -> FileCursor? {
        try await queue.read { db in
            guard let row = try Row.fetchOne(db, sql: """
                SELECT jsonl_path, source, last_ingested_line, last_ingested_at, file_size_at_cursor
                FROM file_cursors WHERE jsonl_path = ?
                """, arguments: [path]) else {
                return nil
            }
            guard let sourceRaw: String = row["source"], let source = Source(rawValue: sourceRaw) else {
                return nil
            }
            return FileCursor(
                jsonlPath: row["jsonl_path"],
                source: source,
                lastIngestedLine: row["last_ingested_line"],
                lastIngestedAt: Date(timeIntervalSince1970: TimeInterval(row["last_ingested_at"] as Int64)),
                fileSizeAtCursor: row["file_size_at_cursor"]
            )
        }
    }

    public func upsertCursor(_ cursor: FileCursor) async throws {
        try await queue.write { db in
            try db.execute(sql: """
                INSERT INTO file_cursors (jsonl_path, source, last_ingested_line, last_ingested_at, file_size_at_cursor)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(jsonl_path) DO UPDATE SET
                    source              = excluded.source,
                    last_ingested_line  = excluded.last_ingested_line,
                    last_ingested_at    = excluded.last_ingested_at,
                    file_size_at_cursor = excluded.file_size_at_cursor
                """, arguments: [
                cursor.jsonlPath,
                cursor.source.rawValue,
                cursor.lastIngestedLine,
                Int(cursor.lastIngestedAt.timeIntervalSince1970),
                cursor.fileSizeAtCursor,
            ])
        }
    }

    // MARK: - Private

    private static func insertCodex(_ observation: CodexObservation, into db: GRDB.Database) throws {
        try db.execute(sql: """
            INSERT OR IGNORE INTO codex_observations
                (ts, session_id, cwd, plan_type,
                 primary_used_percent, primary_window_minutes, primary_resets_at,
                 secondary_used_percent, secondary_window_minutes, secondary_resets_at,
                 raw_rate_limits_json, jsonl_path, jsonl_line_no)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
            Int(observation.timestamp.timeIntervalSince1970),
            observation.sessionId,
            observation.cwd,
            observation.planType,
            observation.primary.usedPercent,
            observation.primary.windowMinutes,
            Int(observation.primary.resetsAt.timeIntervalSince1970),
            observation.secondary?.usedPercent,
            observation.secondary?.windowMinutes,
            observation.secondary.map { Int($0.resetsAt.timeIntervalSince1970) },
            observation.rawRateLimitsJSON,
            observation.jsonlPath,
            observation.jsonlLineNo,
        ])
    }
}
