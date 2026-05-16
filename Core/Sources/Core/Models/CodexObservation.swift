import Foundation

public struct CodexObservation: Sendable, Equatable {
    public let timestamp: Date
    public let sessionId: String
    public let cwd: String?
    public let planType: String?
    public let primary: RateLimitWindow
    public let secondary: RateLimitWindow?
    public let rawRateLimitsJSON: String
    public let jsonlPath: String
    public let jsonlLineNo: Int

    public init(
        timestamp: Date,
        sessionId: String,
        cwd: String?,
        planType: String?,
        primary: RateLimitWindow,
        secondary: RateLimitWindow?,
        rawRateLimitsJSON: String,
        jsonlPath: String,
        jsonlLineNo: Int
    ) {
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.cwd = cwd
        self.planType = planType
        self.primary = primary
        self.secondary = secondary
        self.rawRateLimitsJSON = rawRateLimitsJSON
        self.jsonlPath = jsonlPath
        self.jsonlLineNo = jsonlLineNo
    }
}
