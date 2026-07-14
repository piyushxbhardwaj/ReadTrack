import SwiftUI
import WebKit

public struct ReaderView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: ReaderViewModel
    
    public init(
        article: Article,
        persistenceManager: any PersistenceProviding,
        timerService: any TimerProviding
    ) {
        _viewModel = StateObject(wrappedValue: ReaderViewModel(
            article: article,
            persistenceManager: persistenceManager,
            timerService: timerService
        ))
    }
    
    public var body: some View {
        ZStack {
            // Main Web View
            WebViewRepresentable(
                url: viewModel.article.url,
                isLoading: Binding(
                    get: { viewModel.isLoading },
                    set: { viewModel.setWebViewLoading($0) }
                ),
                onError: { error in
                    viewModel.setWebViewError(error)
                }
            )
            .edgesIgnoringSafeArea(.bottom)
            
            // Loading Overlay
            if viewModel.isLoading {
                VStack {
                    ProgressView("Loading article...")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground).opacity(0.85))
                        )
                        .shadow(radius: 10)
                }
            }
            
            // Networking Error Overlay
            if let error = viewModel.loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Failed to load webpage")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle(viewModel.article.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            // Premium Glassmorphic Control Bar
            HStack {
                // Session metrics
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT SESSION")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass.badge.plus")
                            .foregroundColor(.blue)
                        Text(formatDuration(viewModel.sessionDuration))
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
                
                Divider()
                    .frame(height: 30)
                    .padding(.horizontal)
                
                Spacer()
                
                // Total accumulated metrics
                VStack(alignment: .trailing, spacing: 4) {
                    Text("TOTAL READING TIME")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.green)
                        Text(formatDuration(viewModel.accumulatedReadingTime))
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(.systemBackground).opacity(0.8))
                    .background(.ultraThinMaterial)
            )
            .overlay(
                Divider(), alignment: .top
            )
        }
        .onAppear {
            viewModel.viewDidAppear()
        }
        .onDisappear {
            viewModel.viewDidDisappear()
        }
        .onChange(of: scenePhase) { newPhase in
            viewModel.handleScenePhaseChange(isActive: newPhase == .active)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let secs = Int(seconds)
        let hours = secs / 3600
        let minutes = (secs % 3600) / 60
        let remainingSeconds = secs % 60
        
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, remainingSeconds)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, remainingSeconds)
        } else {
            return String(format: "%ds", remainingSeconds)
        }
    }
}

// MARK: - WKWebView UIViewRepresentable implementation
struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var onError: ((Error) -> Void)?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.onError?(error)
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.onError?(error)
            }
        }
    }
}
