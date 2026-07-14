import Foundation

public struct ReadingSession: Codable, Hashable {
    public let articleId: UUID
    public let startedAt: Date
    public var accumulatedSeconds: TimeInterval
    
    public init(
        articleId: UUID,
        startedAt: Date = Date(),
        accumulatedSeconds: TimeInterval = 0
    ) {
        self.articleId = articleId
        self.startedAt = startedAt
        self.accumulatedSeconds = accumulatedSeconds
    }
}
