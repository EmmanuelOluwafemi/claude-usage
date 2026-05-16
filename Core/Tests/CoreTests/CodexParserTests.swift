import Testing
import Foundation
@testable import Core

@Suite("CodexParser")
struct CodexParserTests {

    @Test func parsesCleanSession() async throws {
        let url = try fixtureURL("clean-session")
        var observations: [CodexObservation] = []
        for try await parsed in CodexParser.parse(file: url) {
            observations.append(parsed.observation)
        }

        #expect(observations.count == 3)

        let first = observations[0]
        #expect(first.primary.usedPercent == 12.5)
        #expect(first.primary.windowMinutes == 300)
        #expect(first.secondary?.usedPercent == 24.0)
        #expect(first.secondary?.windowMinutes == 10080)
        #expect(first.planType == "plus")

        let last = observations.last
        #expect(last?.primary.usedPercent == 48.0)
        #expect(last?.secondary?.usedPercent == 27.0)
    }

    @Test func skipsMalformedLinesButYieldsValidOnes() async throws {
        let url = try fixtureURL("malformed-mixed")
        var observations: [CodexObservation] = []
        for try await parsed in CodexParser.parse(file: url) {
            observations.append(parsed.observation)
        }

        #expect(observations.count == 3)
        #expect(observations[0].primary.usedPercent == 5.0)
        #expect(observations[1].primary.usedPercent == 10.0)
        #expect(observations[2].primary.usedPercent == 15.0)
        #expect(observations.allSatisfy { $0.secondary == nil })
    }

    @Test func returnsNothingForFileWithNoTokenCounts() async throws {
        let url = try fixtureURL("no-token-counts")
        var observations: [CodexObservation] = []
        for try await parsed in CodexParser.parse(file: url) {
            observations.append(parsed.observation)
        }
        #expect(observations.isEmpty)
    }

    @Test func returnsNothingForEmptyFile() async throws {
        let url = try fixtureURL("empty")
        var observations: [CodexObservation] = []
        for try await parsed in CodexParser.parse(file: url) {
            observations.append(parsed.observation)
        }
        #expect(observations.isEmpty)
    }

    @Test func resumesFromLineOffset() async throws {
        let url = try fixtureURL("clean-session")
        var observations: [CodexObservation] = []
        for try await parsed in CodexParser.parse(file: url, fromLine: 5) {
            observations.append(parsed.observation)
        }
        #expect(observations.count == 2)
        #expect(observations[0].primary.usedPercent == 25.0)
        #expect(observations[1].primary.usedPercent == 48.0)
    }

    @Test func extractsSessionIdFromRolloutFilename() {
        let uuid = CodexParser.sessionId(
            fromFilename: "rollout-2026-05-16T03-02-50-019e2e85-a337-7942-82c0-037dab3d527c.jsonl"
        )
        #expect(uuid == "019e2e85-a337-7942-82c0-037dab3d527c")
    }

    @Test func sessionIdFromShortFilenameIsNil() {
        #expect(CodexParser.sessionId(fromFilename: "short.jsonl") == nil)
    }
}

func fixtureURL(_ name: String) throws -> URL {
    guard let url = Bundle.module.url(
        forResource: name,
        withExtension: "jsonl",
        subdirectory: "Fixtures"
    ) else {
        throw NSError(
            domain: "Fixtures",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Fixture \(name).jsonl not found in test bundle"]
        )
    }
    return url
}

func fixturesDirURL() throws -> URL {
    guard let url = Bundle.module.url(forResource: "Fixtures", withExtension: nil) else {
        throw NSError(
            domain: "Fixtures",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Fixtures dir not found in test bundle"]
        )
    }
    return url
}
