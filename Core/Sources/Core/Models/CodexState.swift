import Foundation

public struct CodexState: Sendable, Equatable {
    public let primary: RateLimitWindow
    public let secondary: RateLimitWindow?
    public let observedAt: Date
    public let planType: String?

    public init(
        primary: RateLimitWindow,
        secondary: RateLimitWindow?,
        observedAt: Date,
        planType: String?
    ) {
        self.primary = primary
        self.secondary = secondary
        self.observedAt = observedAt
        self.planType = planType
    }
}
