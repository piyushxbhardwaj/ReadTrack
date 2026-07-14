import Foundation
import UIKit

/// Protocol defining the interface for the active reading session timer.
public protocol TimerProviding: AnyObject {
    var isRunning: Bool { get }
    var currentSessionSeconds: TimeInterval { get }
    var activeArticleId: UUID? { get }
    var onTick: ((TimeInterval) -> Void)? { get set }
    var onAutosave: (() async -> Void)? { get set }
    
    func startSession(for articleId: UUID)
    func pauseSession()
    func resumeSession()
    func endSession() async
}

/// Service that manages the reading timer using a monotonic system clock,
/// handling interruptions and backgrounding state transitions.
@MainActor
public class TimerService: TimerProviding {
    private let persistenceManager: any PersistenceProviding
    
    public private(set) var isRunning: Bool = false
    public private(set) var currentSession: ReadingSession?
    
    public var onTick: ((TimeInterval) -> Void)?
    public var onAutosave: (() async -> Void)?
    
    private var timer: Timer?
    private var lastTickUptime: TimeInterval?
    private var autosaveCounter: Int = 0
    
    public var activeArticleId: UUID? {
        currentSession?.articleId
    }
    
    public var currentSessionSeconds: TimeInterval {
        currentSession?.accumulatedSeconds ?? 0
    }
    
    public init(persistenceManager: any PersistenceProviding) {
        self.persistenceManager = persistenceManager
        setupNotificationObservers()
    }
    
    deinit {
        // NotificationCenter removal and timer invalidation
        // Note: deinit cannot run async, but we can safely remove observers
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }
    
    private func setupNotificationObservers() {
        // UIApplication lifecycle notifications handle phone calls, lock screen, and control center immediately
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appWillResignActive() {
        if isRunning {
            pauseSession()
            // Force an immediate save when resigning active
            Task {
                await forceAutosave()
            }
        }
    }
    
    @objc private func appDidBecomeActive() {
        // App resumed. If we have a current session (ReaderView was open), resume timing
        if currentSession != nil {
            resumeSession()
        }
    }
    
    @objc private func appWillTerminate() {
        if currentSession != nil {
            pauseSession()
            // Active time has already been saved during the active -> inactive transition (willResignActive).
            // We clean up references to prevent leaks upon process shutdown.
            currentSession = nil
        }
    }
    
    public func startSession(for articleId: UUID) {
        timer?.invalidate()
        currentSession = ReadingSession(articleId: articleId)
        isRunning = true
        lastTickUptime = ProcessInfo.processInfo.systemUptime
        autosaveCounter = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    public func pauseSession() {
        guard isRunning else { return }
        isRunning = false
        timer?.invalidate()
        timer = nil
        updateAccumulatedSeconds()
        lastTickUptime = nil
    }
    
    public func resumeSession() {
        guard !isRunning, currentSession != nil else { return }
        isRunning = true
        lastTickUptime = ProcessInfo.processInfo.systemUptime
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    public func endSession() async {
        pauseSession()
        guard let session = currentSession else { return }
        
        let seconds = session.accumulatedSeconds
        if seconds > 0 {
            if var article = await persistenceManager.getCachedArticle(id: session.articleId) {
                article.readingTime += seconds
                article.lastUpdated = Date()
                _ = try? await persistenceManager.updateArticle(article)
            }
        }
        currentSession = nil
    }
    
    private func tick() {
        updateAccumulatedSeconds()
        
        if let seconds = currentSession?.accumulatedSeconds {
            onTick?(seconds)
        }
        
        autosaveCounter += 1
        if autosaveCounter >= 5 {
            autosaveCounter = 0
            Task {
                await forceAutosave()
            }
        }
    }
    
    private func updateAccumulatedSeconds() {
        guard isRunning, let lastUptime = lastTickUptime else { return }
        let currentUptime = ProcessInfo.processInfo.systemUptime
        let delta = currentUptime - lastUptime
        if delta > 0 {
            currentSession?.accumulatedSeconds += delta
            lastTickUptime = currentUptime
        }
    }
    
    private func forceAutosave() async {
        guard let session = currentSession else { return }
        let secondsToSave = session.accumulatedSeconds
        guard secondsToSave > 0 else { return }
        
        if var article = await persistenceManager.getCachedArticle(id: session.articleId) {
            article.readingTime += secondsToSave
            article.lastUpdated = Date()
            
            do {
                _ = try await persistenceManager.updateArticle(article)
                
                // Reset session accumulated counter only for the saved portion
                if self.currentSession?.articleId == session.articleId {
                    self.currentSession?.accumulatedSeconds -= secondsToSave
                }
                
                // Notify subscribers of autosave
                await onAutosave?()
            } catch {
                // If write fails, we do NOT subtract the seconds.
                // They will be retained in the session and retried at the next tick/save opportunity.
                print("Autosave failed: \(error.localizedDescription)")
            }
        }
    }
}
