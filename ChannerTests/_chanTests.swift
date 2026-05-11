//
//  _chanTests.swift
//  ChannerTests
//
//  Created by x on 3/23/19.
//  Copyright © 2019 x. All rights reserved.
//

import XCTest
@testable import Channer

class _chanTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testImageboardSiteAliasesResolveToCanonicalSites() {
        XCTAssertEqual(ImageboardSite.site(for: "erischan.org").id, "nukechan.net")
        XCTAssertEqual(ImageboardSite.site(for: "2ch.hk").id, "2ch.org")
        XCTAssertEqual(ImageboardSite.site(for: "8chan.se").id, "8chan.moe")
        XCTAssertEqual(ImageboardSite.site(for: "endchan.org").id, "endchan.net")
        XCTAssertEqual(ImageboardSite.site(for: "9-chan.eu").id, "9ch.site")
        XCTAssertEqual(ImageboardSite.site(for: "9ch.moe").id, "9ch.site")
        XCTAssertFalse(ImageboardSite.supportedSites.contains { $0.id == "1chan.us" })
        XCTAssertFalse(ImageboardSite.supportedSites.contains { $0.id == "hispachan.in" })
        XCTAssertTrue(ImageboardSite.fourChan.supportsPosting)
        XCTAssertFalse(ImageboardSite.site(for: "8chan.moe").supportsPosting)
    }

    func testSupportedImageboardSitesAreAlphabetizedByDisplayName() {
        let displayNames = ImageboardSite.supportedSites.map { $0.displayName }
        let sortedDisplayNames = displayNames.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        XCTAssertEqual(displayNames, sortedDisplayNames)
    }

    func testTopImageboardURLConstruction() {
        let service = BoardsService.shared

        service.setSelectedSiteForTesting(ImageboardSite.site(for: "28chan.org"))
        XCTAssertEqual(service.threadListURLs(for: "m", totalPages: 10).first?.absoluteString, "https://28chan.org/board/m/catalog.json")
        XCTAssertEqual(service.threadJSONURL(board: "m", threadNumber: "1").absoluteString, "https://28chan.org/board/m/res/1.json")

        service.setSelectedSiteForTesting(ImageboardSite.site(for: "endchan.net"))
        XCTAssertEqual(service.threadListURLs(for: "b", totalPages: 10).first?.absoluteString, "https://endchan.net/b/catalog.json")
        XCTAssertEqual(service.threadJSONURL(board: "b", threadNumber: "77440").absoluteString, "https://endchan.net/b/res/77440.json")
        XCTAssertEqual(service.imageURL(board: "b", timestamp: "/.media/t_file-imagepng", extension: ""), "https://endchan.net/.media/t_file-imagepng")

        service.setSelectedSiteForTesting(ImageboardSite.site(for: "2ch.hk"))
        XCTAssertEqual(service.threadListURLs(for: "b", totalPages: 10).first?.absoluteString, "https://2ch.org/b/catalog.json")
        XCTAssertEqual(service.threadJSONURL(board: "b", threadNumber: "123").absoluteString, "https://2ch.org/b/res/123.json")

        service.setSelectedSiteForTesting(ImageboardSite.site(for: "crystal.cafe"))
        XCTAssertEqual(service.threadListURLs(for: "meta", totalPages: 10).first?.absoluteString, "https://crystal.cafe/meta/catalog")
        XCTAssertEqual(service.threadJSONURL(board: "meta", threadNumber: "99").absoluteString, "https://crystal.cafe/meta/res/99.html")

        service.setSelectedSiteForTesting(ImageboardSite.site(for: "9-chan.eu"))
        XCTAssertEqual(service.threadListURLs(for: "b", totalPages: 10).first?.absoluteString, "https://9ch.site/b/catalog.json")
        XCTAssertEqual(service.threadJSONURL(board: "b", threadNumber: "123").absoluteString, "https://9ch.site/b/res/123.json")
    }

    func testBoardParsersForNewAdapterFamilies() throws {
        let lynxHTML = """
        <a class="linkBoard" href="/polru/">/polru/ - pol - Russian Edition</a>
        <a class="linkBoard" href="/b/">/b/ - Random</a>
        """
        let lynxBoards = try BoardsService.parseBoards(from: Data(lynxHTML.utf8), for: ImageboardSite.site(for: "endchan.net"))
        XCTAssertEqual(lynxBoards.map { $0.code }, ["polru", "b"])
        XCTAssertEqual(lynxBoards.first?.title, "pol - Russian Edition")

        let makabaJSON = """
        {"boards":[{"id":"b","name":"Бред"},{"id":"pr","name":"Программирование"}]}
        """
        let makabaBoards = try BoardsService.parseBoards(from: Data(makabaJSON.utf8), for: ImageboardSite.site(for: "2ch.org"))
        XCTAssertEqual(makabaBoards.map { $0.code }, ["b", "pr"])

        let vichanHTML = """
        <a href="/leek" class="board-item"><span class="board-title">Vocaloid Lounge</span></a>
        <a href="/g/">/g/ - General Discussion</a>
        <a href="o/">/o/ - Auto</a>
        <a href="/boards/a/" class="boardlink">Anime</a>
        <a href="/b/" title="Базгранина">b</a>
        """
        let vichanBoards = try BoardsService.parseBoards(from: Data(vichanHTML.utf8), for: ImageboardSite.site(for: "39chan.moe"))
        XCTAssertTrue(vichanBoards.contains { $0.code == "leek" && $0.title == "Vocaloid Lounge" })
        XCTAssertTrue(vichanBoards.contains { $0.code == "g" && $0.title == "General Discussion" })
        XCTAssertTrue(vichanBoards.contains { $0.code == "o" && $0.title == "Auto" })
        XCTAssertTrue(vichanBoards.contains { $0.code == "a" && $0.title == "Anime" })
        XCTAssertTrue(vichanBoards.contains { $0.code == "b" && $0.title == "Базгранина" })

        let makabaHTML = """
        <li><a href="/au/">Автомобили</a></li>
        <li><a href="/b/">Бред</a></li>
        """
        let makabaHTMLBoards = try BoardsService.parseBoards(from: Data(makabaHTML.utf8), for: ImageboardSite.site(for: "2ch.org"))
        XCTAssertTrue(makabaHTMLBoards.contains { $0.code == "au" && $0.title == "Автомобили" })
        XCTAssertTrue(makabaHTMLBoards.contains { $0.code == "b" && $0.title == "Бред" })

    }

    func testThreadParsersForNewAdapterFamilies() throws {
        BoardsService.shared.setSelectedSiteForTesting(ImageboardSite.site(for: "endchan.net"))
        let lynxCatalog = """
        [{"threadId":77440,"postCount":6,"fileCount":10,"subject":"groups","message":"hello","creation":"2026-05-10T17:48:00.000Z","lastBump":"2026-05-10T20:37:03.629Z","thumb":"/.media/t_file-imagepng"}]
        """
        let lynxThreads = try ThreadData.parseThreadList(from: Data(lynxCatalog.utf8), boardAbv: "b")
        XCTAssertEqual(lynxThreads.first?.number, "77440")
        XCTAssertEqual(lynxThreads.first?.stats, "5/10")
        XCTAssertEqual(lynxThreads.first?.imageUrl, "https://endchan.net/.media/t_file-imagepng")

        let lynxThread = """
        {"threadId":77440,"postCount":3,"subject":"OP","message":"hello","creation":"2026-05-10T17:48:00.000Z","files":[{"path":"/.media/op.png"}],"posts":[{"postId":77441,"message":"reply one","creation":"2026-05-10T17:49:00.000Z"},{"postId":77442,"message":"reply two","creation":"2026-05-10T17:50:00.000Z"}]}
        """
        let lynxNormalized = try ThreadData.parseThreadResponse(from: Data(lynxThread.utf8), boardAbv: "b")
        let lynxPosts = ThreadData.postsArray(from: lynxNormalized)
        XCTAssertEqual(lynxPosts.count, 3)
        XCTAssertEqual(ThreadData.postNumber(from: lynxPosts[0]), "77440")
        XCTAssertEqual(ThreadData.postNumber(from: lynxPosts[1]), "77441")
        XCTAssertEqual(ThreadData.postImageURL(from: lynxPosts[0], boardAbv: "b"), "https://endchan.net/.media/op.png")
        let lynxThreadData = ThreadData(from: lynxNormalized, boardAbv: "b")
        XCTAssertEqual(lynxThreadData.number, "77440")
        XCTAssertEqual(lynxThreadData.title, "OP")
        XCTAssertEqual(lynxThreadData.replies, 2)

        BoardsService.shared.setSelectedSiteForTesting(ImageboardSite.site(for: "2ch.org"))
        let makabaThread = """
        {"threads":[{"posts":[{"num":"123","subject":"OP","comment":"text","timestamp":1778447479,"files":[{"path":"/b/src/file.jpg"}]},{"num":"124","comment":"reply"}]}]}
        """
        let normalized = try ThreadData.parseThreadResponse(from: Data(makabaThread.utf8), boardAbv: "b")
        let posts = ThreadData.postsArray(from: normalized)
        XCTAssertEqual(posts.count, 2)
        XCTAssertEqual(ThreadData.postNumber(from: posts[0]), "123")
        XCTAssertEqual(ThreadData.postImageURL(from: posts[0], boardAbv: "b"), "https://2ch.org/b/src/file.jpg")

        let htmlCatalog = """
        <a href="/meta/res/99.html">A public thread</a>
        """
        let htmlThreads = try ThreadData.parseThreadList(from: Data(htmlCatalog.utf8), boardAbv: "meta")
        XCTAssertEqual(htmlThreads.first?.number, "99")
        XCTAssertEqual(htmlThreads.first?.title, "A public thread")
    }

    func testEightChanPOWBlockChallengeParsingAndSolving() throws {
        let challengeHTML = """
        <html>
          <body>
            <pre id="c">abc</pre>
            <pre id="d">8</pre>
            <pre id="h">256</pre>
          </body>
        </html>
        """

        let challenge = try XCTUnwrap(EightChanMoePOWBlock.parseChallenge(from: Data(challengeHTML.utf8)))
        XCTAssertEqual(challenge.token, "abc")
        XCTAssertEqual(challenge.difficulty, 8)
        XCTAssertEqual(challenge.algorithm, 256)

        XCTAssertNotNil(EightChanMoePOWBlock.solve(challenge: challenge, maxIterations: 10_000))
    }

    func testEightChanPOWBlockParsesUnquotedLiveChallengeFields() throws {
        let challengeHTML = """
        <html>
          <body>
            <pre id=c style=display:none>dGvtkeYkP7TUiU68Bg3e2dfqYz73XEKO8C1Iv0U+ubA=</pre>
            <pre id=d style=display:none>18</pre>
            <pre id=h style=display:none>256</pre>
          </body>
        </html>
        """

        let challenge = try XCTUnwrap(EightChanMoePOWBlock.parseChallenge(from: Data(challengeHTML.utf8)))
        XCTAssertEqual(challenge.token, "dGvtkeYkP7TUiU68Bg3e2dfqYz73XEKO8C1Iv0U+ubA=")
        XCTAssertEqual(challenge.difficulty, 18)
        XCTAssertEqual(challenge.algorithm, 256)
    }

    func testEightChanPOWBlockDetectsPlainPBResponse() throws {
        let url = try XCTUnwrap(URL(string: "https://8chan.moe/boards.js"))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: url,
            statusCode: 403,
            httpVersion: nil,
            headerFields: ["Server": "Varnish"]
        ))

        XCTAssertTrue(BoardsService.requiresEightChanPOWBlockSolve(response))
    }

    func testEightChanPOWBlockSubmitURLKeepsRawBase64Token() throws {
        let token = "abc+def/ghi="
        let url = try XCTUnwrap(EightChanMoePOWBlock.submitURL(solution: 42, token: token))

        XCTAssertEqual(url.absoluteString, "https://8chan.moe/?pow=42&t=abc+def/ghi=")
    }

}
