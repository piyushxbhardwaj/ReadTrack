import Foundation
import Combine

@MainActor
public class ReaderViewModel: ObservableObject {
    private let persistenceManager: any PersistenceProviding
    private let timerService: any TimerProviding
    
    @Published public var article: Article
    @Published public var sessionDuration: TimeInterval = 0
    @Published public var accumulatedReadingTime: TimeInterval = 0
    @Published public var isLoading: Bool = true
    @Published public var loadError: Error? = nil
    @Published public var isReaderActive: Bool = false
    
    public init(
        article: Article,
        persistenceManager: any PersistenceProviding,
        timerService: any TimerProviding
    ) {
        self.article = article
        self.persistenceManager = persistenceManager
        self.timerService = timerService
        self.accumulatedReadingTime = article.readingTime
        
        setupTimerCallbacks()
    }
    
    private func setupTimerCallbacks() {
        // Handle tick increments
        timerService.onTick = { [weak self] duration in
            guard let self = self else { return }
            Task { @MainActor in
                self.sessionDuration = duration
                // Accumulated is baseline plus current session duration
                self.accumulatedReadingTime = self.article.readingTime + duration
            }
        }
        
        // Handle autosave completions
        timerService.onAutosave = { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                if let updated = await self.persistenceManager.getCachedArticle(id: self.article.id) {
                    self.article = updated
                    // Re-calculate based on updated baseline and current leftover session duration
                    self.accumulatedReadingTime = updated.readingTime + self.timerService.currentSessionSeconds
                }
            }
        }
    }
    
    /// Starts the timing session when the reading interface is visible.
    public func viewDidAppear() {
        isReaderActive = true
        sessionDuration = 0
        accumulatedReadingTime = article.readingTime
        timerService.startSession(for: article.id)
    }
    
    /// Ends the timing session and forces a final save when the user leaves the reader.
    public func viewDidDisappear() {
        isReaderActive = false
        Task {
            await timerService.endSession()
            // Sync final state back to view
            if let updated = await self.persistenceManager.getCachedArticle(id: self.article.id) {
                self.article = updated
                self.accumulatedReadingTime = updated.readingTime
            }
        }
    }
    
    /// Updates loading states from the WKWebView representable.
    public func setWebViewLoading(_ loading: Bool) {
        self.isLoading = loading
    }
    
    /// Registers loading errors if the WKWebView encounters networking issues.
    public func setWebViewError(_ error: Error) {
        self.loadError = error
        self.isLoading = false
    }
}
