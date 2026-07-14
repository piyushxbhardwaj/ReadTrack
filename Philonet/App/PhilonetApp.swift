import SwiftUI

@main
struct PhilonetApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    // Core long-lived services
    private let persistenceManager: any PersistenceProviding
    private let timerService: any TimerProviding
    
    public init() {
        let persistence = PersistenceManager()
        self.persistenceManager = persistence
        self.timerService = TimerService(persistenceManager: persistence)
    }
    
    public var body: some Scene {
        WindowGroup {
            HomeView(
                persistenceManager: persistenceManager,
                timerService: timerService
            )
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                // Application returned to foreground: Reconcile memory and disk articles immediately
                Task {
                    _ = try? await persistenceManager.loadArticles()
                }
            case .inactive:
                // Application became inactive (e.g. interruption): TimerService handles pausing
                break
            case .background:
                // Application backgrounded: TimerService pauses and forces save.
                // We also trigger a top-level actor save request just to be safe.
                break
            @unknown default:
                break
            }
        }
    }
}
