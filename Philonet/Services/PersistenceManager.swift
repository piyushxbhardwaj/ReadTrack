import Foundation

/// Protocol defining the interface for thread-safe persistent operations.
public protocol PersistenceProviding: Actor {
    func loadArticles() async throws -> [Article]
    func saveArticles(_ articles: [Article]) async throws
    func updateArticle(_ article: Article) async throws -> MergeResult?
    func deleteArticle(id: UUID) async throws
    func addOrUpdateArticle(title: String, url: URL) async throws -> Article
    func getMergeHistory() async -> [MergeResult]
    func clearMergeHistory() async
    func getCachedArticle(id: UUID) async -> Article?
}

/// Actor responsible for persistent operations, ensuring serial execution to avoid concurrent write issues.
public actor PersistenceManager: PersistenceProviding {
    private let fileURL: URL
    private var memoryCache: [UUID: Article] = [:]
    private var mergeHistory: [MergeResult] = []
    
    public init() {
        // Look for the shared App Group container first (to communicate with Share Extension)
        let containerURL: URL
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.philonet.ReadingTimer") {
            containerURL = appGroupURL
        } else {
            // Fallback to Application Support inside the sandbox
            let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            containerURL = paths[0]
        }
        
        // Ensure the directory exists
        try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true, attributes: nil)
        self.fileURL = containerURL.appendingPathComponent("articles.json")
    }
    
    /// Loads articles from disk and reconciles them with the in-memory cache.
    public func loadArticles() async throws -> [Article] {
        let diskArticles: [Article]
        do {
            diskArticles = try await loadFromDisk()
        } catch {
            // Handle disk read failure/corruption: fallback to empty and propagate or keep memory
            diskArticles = []
            // We can also report a merge log for failure recovery
            let errorArticle = Article(title: "Read Error Fallback", url: URL(string: "about:blank")!)
            mergeHistory.append(MergeResult(
                article: errorArticle,
                selectedSource: .memory,
                appliedRule: "Error Fallback",
                reason: "Disk read failed or JSON corrupted: \(error.localizedDescription)"
            ))
        }
        
        var reconciled: [UUID: Article] = [:]
        
        // Match disk articles with memory
        for diskArticle in diskArticles {
            if let memoryArticle = memoryCache[diskArticle.id] {
                // Discrepancy exists: perform reconciliation
                let result = MergeManager.merge(memoryArticle: memoryArticle, diskArticle: diskArticle)
                // Only log if they actually differ to prevent cluttering history
                if memoryArticle.readingTime != diskArticle.readingTime || memoryArticle.lastUpdated != diskArticle.lastUpdated {
                    mergeHistory.append(result)
                }
                reconciled[diskArticle.id] = result.article
            } else {
                // New disk article (e.g. written by Share Extension)
                reconciled[diskArticle.id] = diskArticle
            }
        }
        
        // Include any memory-only articles that haven't been written to disk yet
        for (id, memoryArticle) in memoryCache {
            if reconciled[id] == nil {
                reconciled[id] = memoryArticle
            }
        }
        
        self.memoryCache = reconciled
        
        // Save the clean merged state back to disk
        try? await saveToDisk(Array(self.memoryCache.values))
        return Array(self.memoryCache.values)
    }
    
    /// Overwrites/saves list of articles.
    public func saveArticles(_ articles: [Article]) async throws {
        for article in articles {
            memoryCache[article.id] = article
        }
        try await saveToDisk(Array(memoryCache.values))
    }
    
    /// Updates a single article, performing merge resolution.
    public func updateArticle(_ article: Article) async throws -> MergeResult? {
        let diskArticles = (try? await loadFromDisk()) ?? []
        let diskArticle = diskArticles.first(where: { $0.id == article.id })
        
        let finalArticle: Article
        var result: MergeResult? = nil
        
        if let disk = diskArticle {
            let mergeResult = MergeManager.merge(memoryArticle: article, diskArticle: disk)
            mergeHistory.append(mergeResult)
            finalArticle = mergeResult.article
            result = mergeResult
        } else {
            finalArticle = article
        }
        
        memoryCache[article.id] = finalArticle
        try await saveToDisk(Array(memoryCache.values))
        return result
    }
    
    /// Deletes an article by UUID.
    public func deleteArticle(id: UUID) async throws {
        memoryCache.removeValue(forKey: id)
        var diskArticles = (try? await loadFromDisk()) ?? []
        diskArticles.removeAll(where: { $0.id == id })
        try await saveToDisk(diskArticles)
    }
    
    /// Checks for duplicate URLs. If found, updates the metadata while preserving accumulated time. Otherwise, creates a new record.
    public func addOrUpdateArticle(title: String, url: URL) async throws -> Article {
        // Sync cache with disk first to discover other processes' writes (Share Extension)
        _ = try? await loadArticles()
        
        // Case-insensitive URL match
        if let existing = memoryCache.values.first(where: { $0.url.absoluteString.caseInsensitiveCompare(url.absoluteString) == .orderedSame }) {
            var updated = existing
            updated.title = title.isEmpty ? existing.title : title
            updated.lastUpdated = Date() // Updates timestamp as requested
            
            _ = try await updateArticle(updated)
            return memoryCache[existing.id] ?? updated
        } else {
            let newArticle = Article(
                title: title.isEmpty ? "Untitled Webpage" : title,
                url: url
            )
            memoryCache[newArticle.id] = newArticle
            try await saveToDisk(Array(memoryCache.values))
            return newArticle
        }
    }
    
    public func getCachedArticle(id: UUID) async -> Article? {
        return memoryCache[id]
    }
    
    public func getMergeHistory() async -> [MergeResult] {
        return mergeHistory
    }
    
    public func clearMergeHistory() async {
        mergeHistory.removeAll()
    }
    
    // MARK: - Private Disk IO Helpers
    
    private func loadFromDisk() async throws -> [Article] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([Article].self, from: data)
    }
    
    private func saveToDisk(_ articles: [Article]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(articles)
        try data.write(to: fileURL, options: [.atomic])
    }
}
