#if canImport(XCTest)
import XCTest

public final class MergeManagerTests: XCTestCase {
    
    /// Tests that the newer memory timestamp wins and updates metadata.
    public func testNewerMemoryWins() {
        let id = UUID()
        let url = URL(string: "https://philonet.org/article")!
        let now = Date()
        
        let memoryArticle = Article(
            id: id,
            title: "New Memory Title",
            url: url,
            readingTime: 120,
            lastUpdated: now
        )
        
        let diskArticle = Article(
            id: id,
            title: "Old Disk Title",
            url: url,
            readingTime: 100,
            lastUpdated: now.addingTimeInterval(-10) // 10s older
        )
        
        let result = MergeManager.merge(memoryArticle: memoryArticle, diskArticle: diskArticle)
        
        XCTAssertEqual(result.article.readingTime, 120)
        XCTAssertEqual(result.article.title, "New Memory Title")
        XCTAssertEqual(result.selectedSource, .memory)
        XCTAssertTrue(result.appliedRule.contains("Memory"))
    }
    
    /// Tests that the newer disk timestamp wins.
    public func testNewerDiskWins() {
        let id = UUID()
        let url = URL(string: "https://philonet.org/article")!
        let now = Date()
        
        let memoryArticle = Article(
            id: id,
            title: "Old Memory Title",
            url: url,
            readingTime: 80,
            lastUpdated: now.addingTimeInterval(-15) // 15s older
        )
        
        let diskArticle = Article(
            id: id,
            title: "New Disk Title",
            url: url,
            readingTime: 110,
            lastUpdated: now
        )
        
        let result = MergeManager.merge(memoryArticle: memoryArticle, diskArticle: diskArticle)
        
        XCTAssertEqual(result.article.readingTime, 110)
        XCTAssertEqual(result.article.title, "New Disk Title")
        XCTAssertEqual(result.selectedSource, .disk)
        XCTAssertTrue(result.appliedRule.contains("Disk"))
    }
    
    /// Tests that when timestamps are equal, the maximum reading time is selected.
    public func testEqualTimestampsSelectsMaxTime() {
        let id = UUID()
        let url = URL(string: "https://philonet.org/article")!
        let now = Date()
        
        let memoryArticle = Article(
            id: id,
            title: "Same Title",
            url: url,
            readingTime: 150,
            lastUpdated: now
        )
        
        let diskArticle = Article(
            id: id,
            title: "Same Title",
            url: url,
            readingTime: 130,
            lastUpdated: now
        )
        
        let result = MergeManager.merge(memoryArticle: memoryArticle, diskArticle: diskArticle)
        
        XCTAssertEqual(result.article.readingTime, 150)
        XCTAssertEqual(result.selectedSource, .equal)
        XCTAssertTrue(result.appliedRule.contains("Equal"))
    }
    
    /// Tests that reading time never decreases under any circumstances, even if
    /// a newer timestamp has a smaller duration value.
    public func testReadingTimeNeverDecreases() {
        let id = UUID()
        let url = URL(string: "https://philonet.org/article")!
        let now = Date()
        
        let memoryArticle = Article(
            id: id,
            title: "Newer Memory State",
            url: url,
            readingTime: 90, // regression
            lastUpdated: now
        )
        
        let diskArticle = Article(
            id: id,
            title: "Older Disk State",
            url: url,
            readingTime: 130, // higher duration
            lastUpdated: now.addingTimeInterval(-20) // older
        )
        
        let result = MergeManager.merge(memoryArticle: memoryArticle, diskArticle: diskArticle)
        
        XCTAssertEqual(result.article.readingTime, 130)
        XCTAssertEqual(result.selectedSource, .memory)
        XCTAssertTrue(result.reason.contains("clamped") || result.reason.contains("prevent time regression"))
    }
}
#endif
