import SwiftUI

public struct ArticleRow: View {
    public let article: Article
    
    public init(article: Article) {
        self.article = article
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Text(article.url.absoluteString)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .padding(.bottom, 2)
            
            HStack {
                // Reading Time
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(formatReadingTime(article.readingTime))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Date Added
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(article.createdAt.relativeFormatted())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }
    
    private func formatReadingTime(_ seconds: TimeInterval) -> String {
        let secs = Int(seconds)
        let hours = secs / 3600
        let minutes = (secs % 3600) / 60
        let remainingSeconds = secs % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m \(remainingSeconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            return "\(remainingSeconds)s"
        }
    }
}

#Preview {
    ArticleRow(article: Article(
        title: "The Art of Slow Reading in the Digital Age",
        url: URL(string: "https://example.com/slow-reading")!,
        readingTime: 124,
        createdAt: Date().addingTimeInterval(-3600 * 3)
    ))
    .padding()
    .background(Color(.systemGroupedBackground))
}
