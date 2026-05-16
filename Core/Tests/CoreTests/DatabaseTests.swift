import Testing
import Foundation
@testable import Core

@Suite("Database")
struct DatabaseTests {

    @Test func insertAndRetrieveCodexObservation() async throws {
        let db = try Database.makeInMemoryForTesting()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        try await db.insertCodexObservation(.sample(
            timestamp: now, primary: 50.0, secondary: 60.0,
            path: "/tmp/test.jsonl", lineNo: 1
        ))

        let state = try await db.latestCodexState()
        #expect(state?.primary.usedPercent == 50.0)
        #expect(state?.secondary?.usedPercent == 60.0)
        #expect(state?.planType == "plus")
    }

    @Test func latestCodexStateReturnsHighestTimestamp() async throws {
        let db = try Database.makeInMemoryForTesting()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        try await db.insertCodexObservation(.sample(
            timestamp: base, primary: 10, secondary: nil,
            path: "/tmp/a.jsonl", lineNo: 0
        ))
        try await db.insertCodexObservation(.sample(
            timestamp: base.addingTimeInterval(3600), primary: 50, secondary: nil,
            path: "/tmp/a.jsonl", lineNo: 1
        ))
        try await db.insertCodexObservation(.sample(
            timestamp: base.addingTimeInterval(1800), primary: 30, secondary: nil,
            path: "/tmp/a.jsonl", lineNo: 2
        ))

        let state = try await db.latestCodexState()
        #expect(state?.primary.usedPercent == 50)
    }

    @Test func uniqueConstraintDedupesReInserts() async throws {
        let db = try Database.makeInMemoryForTesting()
        let observation = CodexObservation.sample(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            primary: 42, secondary: nil,
            path: "/tmp/dupe.jsonl", lineNo: 1
        )

        try await db.insertCodexObservation(observation)
        try await db.insertCodexObservation(observation)
        try await db.insertCodexObservation(observation)

        try await db.insertCodexObservation(.sample(
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            primary: 99, secondary: nil,
            path: "/tmp/dupe.jsonl", lineNo: 2
        ))

        let state = try await db.latestCodexState()
        #expect(state?.primary.usedPercent == 99)
    }

    @Test func cursorUpsertRoundtrips() async throws {
        let db = try Database.makeInMemoryForTesting()
        let path = "/tmp/sample.jsonl"

        try await db.upsertCursor(FileCursor(
            jsonlPath: path,
            source: .codex,
            lastIngestedLine: 5,
            lastIngestedAt: Date(timeIntervalSince1970: 1_700_000_000),
            fileSizeAtCursor: 1000
        ))

        let retrieved = try await db.cursor(forPath: path)
        #expect(retrieved?.lastIngestedLine == 5)
        #expect(retrieved?.fileSizeAtCursor == 1000)
        #expect(retrieved?.source == .codex)

        try await db.upsertCursor(FileCursor(
            jsonlPath: path,
            source: .codex,
            lastIngestedLine: 12,
            lastIngestedAt: Date(timeIntervalSince1970: 1_700_000_100),
            fileSizeAtCursor: 2500
        ))

        let updated = try await db.cursor(forPath: path)
        #expect(updated?.lastIngestedLine == 12)
        #expect(updated?.fileSizeAtCursor == 2500)
    }

    @Test func cursorForMissingPathReturnsNil() async throws {
        let db = try Database.makeInMemoryForTesting()
        let result = try await db.cursor(forPath: "/path/that/was/never/seen.jsonl")
        #expect(result == nil)
    }

    @Test func nullSecondaryRoundtrips() async throws {
        let db = try Database.makeInMemoryForTesting()

        try await db.insertCodexObservation(.sample(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            primary: 33, secondary: nil,
            path: "/tmp/nosec.jsonl", lineNo: 1
        ))

        let state = try await db.latestCodexState()
        #expect(state?.primary.usedPercent == 33)
        #expect(state?.secondary == nil)
    }
}

extension CodexObservation {
    static func sample(
        timestamp: Date,
        primary: Double,
        secondary: Double?,
        path: String,
        lineNo: Int
    ) -> CodexObservation {
        CodexObservation(
            timestamp: timestamp,
            sessionId: "test-session",
            cwd: nil,
            planType: "plus",
            primary: RateLimitWindow(
                usedPercent: primary,
                windowMinutes: 300,
                resetsAt: timestamp.addingTimeInterval(5 * 60 * 60)
            ),
            secondary: secondary.map { pct in
                RateLimitWindow(
                    usedPercent: pct,
                    windowMinutes: 10080,
                    resetsAt: timestamp.addingTimeInterval(7 * 24 * 60 * 60)
                )
            },
            rawRateLimitsJSON: "{}",
            jsonlPath: path,
            jsonlLineNo: lineNo
        )
    }
}
