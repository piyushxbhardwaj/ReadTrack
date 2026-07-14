import SwiftUI

public struct DebugPanelView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    
    // Dependencies
    private let persistenceManager: any PersistenceProviding
    private let timerService: any TimerProviding
    
    // App states
    @State private var mergeHistory: [MergeResult] = []
    @State private var currentSessionDuration: String = "0s"
    
    // Interactive Playground State
    @State private var playMemoryTime: String = "120"
    @State private var playDiskTime: String = "100"
    @State private var playMemoryUpdatedOffset: Double = 0.0 // Newer by default
    @State private var playDiskUpdatedOffset: Double = -10.0 // 10s older
    @State private var playgroundResult: MergeResult? = nil
    
    public init(
        persistenceManager: any PersistenceProviding,
        timerService: any TimerProviding
    ) {
        self.persistenceManager = persistenceManager
        self.timerService = timerService
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Core Engine State").font(.caption).bold()) {
                    HStack {
                        Label("App Phase", systemImage: "app.badge.fill")
                        Spacer()
                        Text("\(scenePhaseText)")
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Label("Timer Running", systemImage: "play.circle.fill")
                        Spacer()
                        Text(timerService.isRunning ? "Active" : "Paused")
                            .foregroundColor(timerService.isRunning ? .green : .orange)
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Label("Active Article ID", systemImage: "doc.text.fill")
                        Spacer()
                        Text(timerService.activeArticleId?.uuidString.prefix(8) ?? "None")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Current Session Uptime", systemImage: "timer")
                        Spacer()
                        Text(currentSessionDuration)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                    }
                }
                
                Section(header: Text("Reconciliation Evaluator Playground").font(.caption).bold()) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Simulate memory vs disk scenarios to view live MergeManager results.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Memory Reading Time (s)")
                            Spacer()
                            TextField("Memory seconds", text: $playMemoryTime)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        HStack {
                            Text("Disk Reading Time (s)")
                            Spacer()
                            TextField("Disk seconds", text: $playDiskTime)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Memory Timestamp Relative Offset")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Picker("Memory Offset", selection: $playMemoryUpdatedOffset) {
                                Text("Newest (0s delay)").tag(0.0)
                                Text("10s ago").tag(-10.0)
                                Text("60s ago").tag(-60.0)
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Disk Timestamp Relative Offset")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Picker("Disk Offset", selection: $playDiskUpdatedOffset) {
                                Text("Newest (0s delay)").tag(0.0)
                                Text("10s ago").tag(-10.0)
                                Text("60s ago").tag(-60.0)
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        Button(action: executeSimulationMerge) {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.triangle.merge")
                                Text("Reconcile States")
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding(.top, 4)
                        
                        if let result = playgroundResult {
                            VStack(alignment: .leading, spacing: 6) {
                                Divider()
                                    .padding(.vertical, 4)
                                
                                Text("MERGE VERDICT")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text("Reading Time:")
                                    Spacer()
                                    Text("\(Int(result.article.readingTime))s")
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.bold)
                                }
                                
                                HStack {
                                    Text("Selected Source:")
                                    Spacer()
                                    Text(result.selectedSource.rawValue)
                                        .fontWeight(.semibold)
                                        .foregroundColor(sourceColor(result.selectedSource))
                                }
                                
                                HStack {
                                    Text("Rule Applied:")
                                    Spacer()
                                    Text(result.appliedRule)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                
                                Text(result.reason)
                                    .font(.caption2)
                                    .italic()
                                    .foregroundColor(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Historical Merge Log Audit").font(.caption).bold()) {
                    if mergeHistory.isEmpty {
                        Text("No data conflicts or merges registered in this session.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(mergeHistory.reversed(), id: \.timestamp) { log in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(log.timestamp.formattedPrecise())
                                        .font(.system(.caption, design: .monospaced))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(log.selectedSource.rawValue)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(sourceColor(log.selectedSource))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                                Text("Rule: \(log.appliedRule)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text("Final Time: \(Int(log.article.readingTime))s (baseline was memory:\(Int(log.article.readingTime))s)")
                                    .font(.caption)
                                Text(log.reason)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        
                        Button(role: .destructive, action: clearSessionLogs) {
                            HStack {
                                Spacer()
                                Text("Clear History Logs")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Engine Debug Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear(perform: startPanelUpdates)
        }
    }
    
    private var scenePhaseText: String {
        switch scenePhase {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .background: return "Background"
        @unknown default: return "Unknown"
        }
    }
    
    private func sourceColor(_ source: MergeSource) -> Color {
        switch source {
        case .memory: return .purple
        case .disk: return .orange
        case .equal: return .gray
        }
    }
    
    private func startPanelUpdates() {
        currentSessionDuration = String(format: "%.1fs", timerService.currentSessionSeconds)
        
        timerService.onTick = { duration in
            currentSessionDuration = String(format: "%.1fs", duration)
        }
        
        Task {
            let history = await persistenceManager.getMergeHistory()
            await MainActor.run {
                self.mergeHistory = history
            }
        }
    }
    
    private func executeSimulationMerge() {
        let memTime = Double(playMemoryTime) ?? 0.0
        let diskTime = Double(playDiskTime) ?? 0.0
        
        let memDate = Date().addingTimeInterval(playMemoryUpdatedOffset)
        let diskDate = Date().addingTimeInterval(playDiskUpdatedOffset)
        
        let mockId = UUID()
        let mockURL = URL(string: "https://philonet.org/playground")!
        
        let memoryArticle = Article(
            id: mockId,
            title: "Playground Simulated Memory",
            url: mockURL,
            readingTime: memTime,
            lastUpdated: memDate
        )
        
        let diskArticle = Article(
            id: mockId,
            title: "Playground Simulated Disk",
            url: mockURL,
            readingTime: diskTime,
            lastUpdated: diskDate
        )
        
        playgroundResult = MergeManager.merge(memoryArticle: memoryArticle, diskArticle: diskArticle)
    }
    
    private func clearSessionLogs() {
        Task {
            await persistenceManager.clearMergeHistory()
            let history = await persistenceManager.getMergeHistory()
            await MainActor.run {
                self.mergeHistory = history
            }
        }
    }
}
