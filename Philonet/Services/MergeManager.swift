import Foundation

public enum MergeSource: String, Codable {
    case memory = "Memory"
    case disk = "Disk"
    case equal = "Equal"
}

public struct MergeResult: Codable, Identifiable {
    public var id: UUID { article.id }
    public let article: Article
    public let selectedSource: MergeSource
    public let appliedRule: String
    public let reason: String
    public let timestamp: Date
    
    public init(
        article: Article,
        selectedSource: MergeSource,
        appliedRule: String,
        reason: String,
        timestamp: Date = Date()
    ) {
        self.article = article
        self.selectedSource = selectedSource
        self.appliedRule = appliedRule
        self.reason = reason
        self.timestamp = timestamp
    }
}

public struct MergeManager {
    /// Merges memory state of an article with its disk state based on strict reconciliation rules.
    ///
    /// Rules applied:
    /// 1. Compare `lastUpdated` timestamps.
    /// 2. If one is newer, use it.
    /// 3. If timestamps are equal, use the maximum readingTime.
    /// 4. Never allow reading time to decrease.
    /// 5. Never double count (never add memory + disk).
    /// 6. Record applied rules and reasons.
    public static func merge(memoryArticle: Article, diskArticle: Article) -> MergeResult {
        // Rule 4: Never allow reading time to decrease
        let maxReadingTime = max(memoryArticle.readingTime, diskArticle.readingTime)
        
        if memoryArticle.lastUpdated > diskArticle.lastUpdated {
            let merged = Article(
                id: memoryArticle.id,
                title: memoryArticle.title,
                url: memoryArticle.url,
                readingTime: maxReadingTime,
                lastUpdated: memoryArticle.lastUpdated,
                createdAt: memoryArticle.createdAt
            )
            let reason: String
            if memoryArticle.readingTime < diskArticle.readingTime {
                reason = "Memory timestamp is newer, but disk reading time was higher (\(diskArticle.readingTime)s vs \(memoryArticle.readingTime)s). Clamped to disk value to prevent time regression."
            } else {
                reason = "Memory state is newer than disk (\(memoryArticle.lastUpdated) vs \(diskArticle.lastUpdated))."
            }
            return MergeResult(
                article: merged,
                selectedSource: .memory,
                appliedRule: "Newer Timestamp (Memory Wins)",
                reason: reason
            )
        } else if diskArticle.lastUpdated > memoryArticle.lastUpdated {
            let merged = Article(
                id: diskArticle.id,
                title: diskArticle.title,
                url: diskArticle.url,
                readingTime: maxReadingTime,
                lastUpdated: diskArticle.lastUpdated,
                createdAt: diskArticle.createdAt
            )
            let reason: String
            if diskArticle.readingTime < memoryArticle.readingTime {
                reason = "Disk timestamp is newer, but memory reading time was higher (\(memoryArticle.readingTime)s vs \(diskArticle.readingTime)s). Clamped to memory value to prevent time regression."
            } else {
                reason = "Disk state is newer than memory (\(diskArticle.lastUpdated) vs \(memoryArticle.lastUpdated))."
            }
            return MergeResult(
                article: merged,
                selectedSource: .disk,
                appliedRule: "Newer Timestamp (Disk Wins)",
                reason: reason
            )
        } else {
            // Equal timestamps
            let merged = Article(
                id: memoryArticle.id,
                title: memoryArticle.title,
                url: memoryArticle.url,
                readingTime: maxReadingTime,
                lastUpdated: memoryArticle.lastUpdated,
                createdAt: memoryArticle.createdAt
            )
            let reason = "Timestamps are equal. Selected the maximum reading time of \(maxReadingTime)s."
            return MergeResult(
                article: merged,
                selectedSource: .equal,
                appliedRule: "Equal Timestamps (Max Wins)",
                reason: reason
            )
        }
    }
}
