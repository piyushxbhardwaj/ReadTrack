import Foundation

extension Date {
    /// Formats the date using a relative description (e.g. "2 hours ago").
    public func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Formats the date to a localized short string (e.g., "Jul 14, 2026 at 6:45 PM").
    public func formattedCompact() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Formats the date with precise seconds for the debugging log.
    public func formattedPrecise() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: self)
    }
}
