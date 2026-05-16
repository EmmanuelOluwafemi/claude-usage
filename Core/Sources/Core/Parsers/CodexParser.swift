import Foundation
import os

public enum CodexParser {
    private static let logger = Logger(
        subsystem: "dev.emmanueloluwafemi.claude-usage",
        category: "parser.codex"
    )

    public struct ParsedLine: Sendable {
        public let lineNo: Int
        public let observation: CodexObservation
    }

    public static func parse(
        file: URL,
        fromLine startLine: Int = 0
    ) -> AsyncThrowingStream<ParsedLine, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await parseInner(
                        file: file,
                        fromLine: startLine,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func parseInner(
        file: URL,
        fromLine startLine: Int,
        continuation: AsyncThrowingStream<ParsedLine, Error>.Continuation
    ) async throws {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let sessionId = sessionId(fromFilename: file.lastPathComponent)
            ?? file.deletingPathExtension().lastPathComponent

        var lineNo = 0
        for try await line in handle.bytes.lines {
            try Task.checkCancellation()
            let currentLine = lineNo
            lineNo += 1

            if currentLine < startLine { continue }
            if !line.contains("\"token_count\"") { continue }

            guard let data = line.data(using: .utf8) else {
                logger.warning("non-utf8 line \(currentLine, privacy: .public) in \(file.path, privacy: .public)")
                continue
            }

            do {
                let parsed = try decoder.decode(TokenCountLine.self, from: data)
                guard let rl = parsed.payload.rateLimits, let primary = rl.primary else {
                    continue
                }

                let primaryWindow = RateLimitWindow(
                    usedPercent: primary.usedPercent,
                    windowMinutes: primary.windowMinutes,
                    resetsAt: Date(timeIntervalSince1970: TimeInterval(primary.resetsAt))
                )
                let secondaryWindow = rl.secondary.map { snapshot in
                    RateLimitWindow(
                        usedPercent: snapshot.usedPercent,
                        windowMinutes: snapshot.windowMinutes,
                        resetsAt: Date(timeIntervalSince1970: TimeInterval(snapshot.resetsAt))
                    )
                }

                let timestamp = iso8601.date(from: parsed.timestamp) ?? Date()

                let observation = CodexObservation(
                    timestamp: timestamp,
                    sessionId: sessionId,
                    cwd: nil,
                    planType: rl.planType,
                    primary: primaryWindow,
                    secondary: secondaryWindow,
                    rawRateLimitsJSON: line,
                    jsonlPath: file.path,
                    jsonlLineNo: currentLine
                )
                continuation.yield(ParsedLine(lineNo: currentLine, observation: observation))
            } catch {
                logger.warning(
                    "malformed line \(currentLine, privacy: .public) in \(file.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                continue
            }
        }
    }

    // Codex session UUID is the last 5 hyphen-separated segments of
    // `rollout-YYYY-MM-DDTHH-MM-SS-{8}-{4}-{4}-{4}-{12}.jsonl`.
    static func sessionId(fromFilename name: String) -> String? {
        let stem = name.hasSuffix(".jsonl") ? String(name.dropLast(6)) : name
        let parts = stem.split(separator: "-")
        guard parts.count >= 5 else { return nil }
        return parts.suffix(5).joined(separator: "-")
    }
}
