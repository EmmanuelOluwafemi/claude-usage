import Testing
import Foundation
@testable import Core

@Suite("Ingestor")
struct IngestorTests {

    @Test func coldStartIngestsObservationsFromFixtures() async throws {
        let fixturesDir = try fixturesDirURL()
        let db = try Database.makeInMemoryForTesting()
        let ingestor = Ingestor(codexSessionsDir: fixturesDir, lookbackDays: 365 * 100)

        let result = try await ingestor.runColdStartScan(database: db)

        // clean-session.jsonl → 3 token_counts
        // malformed-mixed.jsonl → 3 valid (lines 0, 2, 4)
        // no-token-counts.jsonl → 0
        // empty.jsonl → 0
        #expect(result.observationsInserted == 6)
        #expect(result.filesConsidered == 4)
        #expect(result.filesScanned == 2)
    }

    @Test func rerunningIngestIsIdempotent() async throws {
        let fixturesDir = try fixturesDirURL()
        let db = try Database.makeInMemoryForTesting()
        let ingestor = Ingestor(codexSessionsDir: fixturesDir, lookbackDays: 365 * 100)

        let first = try await ingestor.runColdStartScan(database: db)
        let second = try await ingestor.runColdStartScan(database: db)

        #expect(first.observationsInserted == 6)
        #expect(second.observationsInserted == 0)
    }

    @Test func missingSessionsDirReturnsEmptyResult() async throws {
        let bogus = URL(fileURLWithPath: "/this/path/should/not/exist/anywhere/at/all")
        let db = try Database.makeInMemoryForTesting()
        let ingestor = Ingestor(codexSessionsDir: bogus, lookbackDays: 7)

        let result = try await ingestor.runColdStartScan(database: db)
        #expect(result.filesConsidered == 0)
        #expect(result.observationsInserted == 0)
    }

    @Test func ingestRecordsLatestStatePostScan() async throws {
        let fixturesDir = try fixturesDirURL()
        let db = try Database.makeInMemoryForTesting()
        let ingestor = Ingestor(codexSessionsDir: fixturesDir, lookbackDays: 365 * 100)

        _ = try await ingestor.runColdStartScan(database: db)
        let state = try await db.latestCodexState()
        #expect(state != nil)
        // The chronologically latest event in our fixtures is in clean-session.jsonl
        // at 2026-05-16T03:00:00 — primary 48%, secondary 27%.
        #expect(state?.primary.usedPercent == 48.0)
        #expect(state?.secondary?.usedPercent == 27.0)
    }
}
