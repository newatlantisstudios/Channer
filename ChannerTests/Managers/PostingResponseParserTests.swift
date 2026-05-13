import XCTest
@testable import Channer

final class PostingResponseParserTests: XCTestCase {
    func testParsesModernSuccessfulReplyResponse() {
        let html = """
        <!doctype html>
        <html>
        <head><title>Post successful!</title></head>
        <body><h1>Post successful!</h1>thread:123456,no:123999</body>
        </html>
        """

        let result = PostingResponseParser.success(from: html)

        XCTAssertEqual(result, ParsedPostingSuccess(threadNumber: 123456, postNumber: 123999))
        XCTAssertEqual(result?.isNewThread, false)
    }

    func testParsesModernSuccessfulThreadResponse() {
        let html = """
        <!doctype html>
        <html>
        <head><title>Post successful!</title></head>
        <body><h1>Post successful!</h1>thread:234567,no:234567</body>
        </html>
        """

        let result = PostingResponseParser.success(from: html)

        XCTAssertEqual(result, ParsedPostingSuccess(threadNumber: 234567, postNumber: 234567))
        XCTAssertEqual(result?.isNewThread, true)
    }

    func testParsesRedirectReplyResponse() {
        let html = """
        <meta http-equiv="refresh" content="1;URL=https://boards.4chan.org/g/thread/345678#p345999">
        """

        let result = PostingResponseParser.success(from: html)

        XCTAssertEqual(result, ParsedPostingSuccess(threadNumber: 345678, postNumber: 345999))
    }

    func testExtractsAndDecodesErrmsg() {
        let html = """
        <html><body><span id="errmsg">Error: You can&#039;t reply to this thread anymore.<br><a href="/banned">More</a></span></body></html>
        """

        let result = PostingResponseParser.errorMessage(from: html)

        XCTAssertEqual(result, "Error: You can't reply to this thread anymore. More")
    }

    func testIdentifiesErrorPage() {
        let html = """
        <script>var is_error = "true";</script>
        """

        XCTAssertTrue(PostingResponseParser.isErrorPage(html))
    }
}
