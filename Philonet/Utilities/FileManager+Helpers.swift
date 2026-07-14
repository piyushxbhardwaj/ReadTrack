import Foundation

extension FileManager {
    /// Checks if a file exists at the specified URL.
    public func fileExists(at url: URL) -> Bool {
        return fileExists(atPath: url.path)
    }
}
