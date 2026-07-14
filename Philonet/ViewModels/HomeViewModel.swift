import Foundation
import Combine

@MainActor
public class HomeViewModel: ObservableObject {
    public enum SortOption: String, CaseIterable, Identifiable {
        case recentlyAdded = "Recently Added"
        case readingTime = "Reading Time"
        
        public var id: String { self.rawValue }
    }
    
    @Published public var articles: [Article] = []
    @Published public var searchText: String = ""
    @Published public var sortBy: SortOption = .recentlyAdded
    @Published public var isDebugPanelPresented: Bool = false
    @Published public var isRefreshing: Bool = false
    
    public let persistenceManager: any PersistenceProviding
    
    public init(persistenceManager: any PersistenceProviding) {
        self.persistenceManager = persistenceManager
    }
    
    /// Returns the filtered and sorted list of articles based on search queries and sort options.
    public var filteredArticles: [Article] {
        var result = articles
        
        if !searchText.isEmpty {
            result = result.filter { article in
                article.title.localizedCaseInsensitiveContains(searchText) ||
                article.url.absoluteString.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        switch sortBy {
        case .recentlyAdded:
            result.sort { $0.createdAt > $1.createdAt }
        case .readingTime:
            result.sort { $0.readingTime > $1.readingTime }
        }
        
        return result
    }
    
    /// Reconciles cache and disk files, updating local UI properties.
    public func loadArticles() async {
        isRefreshing = true
        do {
            self.articles = try await persistenceManager.loadArticles()
        } catch {
            print("Error loading articles in ViewModel: \(error.localizedDescription)")
        }
        isRefreshing = false
    }
    
    /// Pull-to-refresh execution.
    public func refresh() async {
        await loadArticles()
    }
    
    /// Deletes selected articles from the persistence layer.
    public func deleteArticle(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { filteredArticles[$0] }
        Task {
            for item in itemsToDelete {
                do {
                    try await persistenceManager.deleteArticle(id: item.id)
                } catch {
                    print("Failed to delete article \(item.id): \(error.localizedDescription)")
                }
            }
            await loadArticles()
        }
    }
}
