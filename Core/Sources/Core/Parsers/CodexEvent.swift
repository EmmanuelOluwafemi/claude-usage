import Foundation

struct TokenCountLine: Decodable {
    let timestamp: String
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let type: String
        let rateLimits: RateLimits?
    }

    struct RateLimits: Decodable {
        let limitId: String?
        let primary: WindowSnapshot?
        let secondary: WindowSnapshot?
        let planType: String?
    }

    struct WindowSnapshot: Decodable {
        let usedPercent: Double
        let windowMinutes: Int
        let resetsAt: Int64
    }
}
