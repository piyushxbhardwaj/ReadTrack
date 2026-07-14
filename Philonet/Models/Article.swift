import Foundation

public struct Article: Codable, Identifiable, Hashable {
    public let id: UUID
    public var title: String
    public var url: URL
    public var readingTime: TimeInterval
    public var lastUpdated: Date
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        readingTime: TimeInterval = 0,
        lastUpdated: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.readingTime = readingTime
        self.lastUpdated = lastUpdated
        self.createdAt = createdAt
    }
}
