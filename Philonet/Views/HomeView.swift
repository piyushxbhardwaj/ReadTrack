import SwiftUI

public struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    
    // Dependencies
    private let persistenceManager: any PersistenceProviding
    private let timerService: any TimerProviding
    
    // Manual URL Entry state
    @State private var isAddArticlePresented: Bool = false
    @State private var inputTitle: String = ""
    @State private var inputURL: String = ""
    @State private var inputError: String? = nil
    
    public init(
        persistenceManager: any PersistenceProviding,
        timerService: any TimerProviding
    ) {
        self.persistenceManager = persistenceManager
        self.timerService = timerService
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            persistenceManager: persistenceManager
        ))
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $viewModel.searchText)
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                // Segmented sorting control
                Picker("Sort Option", selection: $viewModel.sortBy) {
                    ForEach(HomeViewModel.SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                // Article List / Empty State
                if viewModel.filteredArticles.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.4))
                        
                        Text(viewModel.searchText.isEmpty ? "Your Reading Stack is Empty" : "No Matches Found")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(viewModel.searchText.isEmpty
                             ? "Share links from Safari through the Share Extension or create an entry using the '+' button."
                             : "Double-check your spelling or try another keyword.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Spacer()
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.filteredArticles) { article in
                            ZStack {
                                // Transparent overlay for custom navigation
                                NavigationLink(destination: ReaderView(
                                    article: article,
                                    persistenceManager: persistenceManager,
                                    timerService: timerService
                                )) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                                ArticleRow(article: article)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: viewModel.deleteArticle)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Philonet Timer")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { viewModel.isDebugPanelPresented = true }) {
                        Image(systemName: "cpu")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isAddArticlePresented = true }) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
            }
            // Sheets
            .sheet(isPresented: $viewModel.isDebugPanelPresented) {
                DebugPanelView(
                    persistenceManager: persistenceManager,
                    timerService: timerService
                )
            }
            .sheet(isPresented: $isAddArticlePresented) {
                NavigationView {
                    Form {
                        Section(header: Text("Save Webpage URL")) {
                            TextField("https://example.com/article", text: $inputURL)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            TextField("Optional Title", text: $inputTitle)
                        }
                        
                        if let error = inputError {
                            Section {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .navigationTitle("Add Article")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                clearAddForm()
                                isAddArticlePresented = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                addManualArticle()
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadArticles()
                }
            }
        }
    }
    
    private func clearAddForm() {
        inputURL = ""
        inputTitle = ""
        inputError = nil
    }
    
    private func addManualArticle() {
        // Simple prefix validation
        var cleanURL = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.lowercased().hasPrefix("http://") && !cleanURL.lowercased().hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }
        
        guard let url = URL(string: cleanURL), url.scheme == "http" || url.scheme == "https" else {
            inputError = "Please enter a valid website URL."
            return
        }
        
        Task {
            do {
                _ = try await persistenceManager.addOrUpdateArticle(title: inputTitle, url: url)
                clearAddForm()
                isAddArticlePresented = false
                await viewModel.loadArticles()
            } catch {
                inputError = "Error saving article: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - SearchBar utility
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search title or URL...", text: $text)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
