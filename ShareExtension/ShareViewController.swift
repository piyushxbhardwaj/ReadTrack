import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

public class ShareViewController: UIViewController {
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupBackgroundOverlay()
        processSharedContent()
    }
    
    private func setupBackgroundOverlay() {
        // Subtle visual indicator sheet to notify the user saving is in progress
        self.view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
        
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.1
        container.layer.shadowRadius = 8
        container.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.view.addSubview(container)
        
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .systemBlue
        spinner.startAnimating()
        container.addSubview(spinner)
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Saving to Philonet..."
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 220),
            container.heightAnchor.constraint(equalToConstant: 140),
            
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -20),
            
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 14),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])
    }
    
    private func processSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            dismissWithFeedback(success: false, errorDescription: "No items shared.")
            return
        }
        
        let urlType = UTType.url.identifier
        let textType = UTType.text.identifier
        
        var sharedURL: URL? = nil
        var sharedTitle: String? = nil
        
        let group = DispatchGroup()
        
        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(urlType) {
                group.enter()
                provider.loadItem(forTypeIdentifier: urlType, options: nil) { (item, error) in
                    DispatchQueue.main.async {
                        if let url = item as? URL {
                            sharedURL = url
                        }
                        group.leave()
                    }
                }
            }
            if provider.hasItemConformingToTypeIdentifier(textType) {
                group.enter()
                provider.loadItem(forTypeIdentifier: textType, options: nil) { (item, error) in
                    DispatchQueue.main.async {
                        if let text = item as? String {
                            sharedTitle = text
                        }
                        group.leave()
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            guard let url = sharedURL else {
                self.dismissWithFeedback(success: false, errorDescription: "No valid link found.")
                return
            }
            
            // Clean/Extract title
            let finalTitle: String
            if let titleText = sharedTitle, !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                finalTitle = titleText
            } else {
                // Fallback: parse domain/components from URL
                let host = url.host ?? ""
                let pageName = url.deletingPathExtension().lastPathComponent
                if !pageName.isEmpty && pageName != "/" {
                    finalTitle = pageName.replacingOccurrences(of: "-", with: " ").capitalized
                } else if !host.isEmpty {
                    finalTitle = host.replacingOccurrences(of: "www.", with: "").capitalized
                } else {
                    finalTitle = "Shared Webpage"
                }
            }
            
            Task {
                // Use shared PersistenceManager actor (which defaults to App Group container)
                let persistenceManager = PersistenceManager()
                do {
                    _ = try await persistenceManager.addOrUpdateArticle(title: finalTitle, url: url)
                    self.dismissWithFeedback(success: true, errorDescription: nil)
                } catch {
                    self.dismissWithFeedback(success: false, errorDescription: "Failed to save: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func dismissWithFeedback(success: Bool, errorDescription: String?) {
        if success {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        } else {
            let alert = UIAlertController(
                title: "Philonet Error",
                message: errorDescription ?? "An error occurred during saving.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.extensionContext?.cancelRequest(withError: NSError(domain: "PhilonetShare", code: -1, userInfo: nil))
            })
            self.present(alert, animated: true)
        }
    }
}
