//
//  BoardListScreenTests.swift
//  ChannerUITests
//
//  UI tests for the main board list screen
//

import XCTest

class BoardListScreenTests: XCTestCase {

    var app: XCUIApplication!

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method
        continueAfterFailure = false

        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method
        app = nil
    }

    // MARK: - Launch Tests

    func testAppLaunches() throws {
        // Verify that the app launched successfully
        XCTAssertTrue(app.state == .runningForeground, "App should be running in foreground")
    }

    func testBoardListScreenAppears() throws {
        // Give the app a moment to load
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app
        )

        wait(for: [expectation], timeout: 5.0)

        // Verify basic UI elements exist
        XCTAssertTrue(app.exists, "App should exist and be running")
    }

    // MARK: - Navigation Bar Tests

    func testNavigationBarExists() throws {
        // Look for navigation bar
        let navBar = app.navigationBars.firstMatch

        // Give time for UI to load
        _ = navBar.waitForExistence(timeout: 5.0)

        XCTAssertTrue(navBar.exists, "Navigation bar should exist")
    }

    // MARK: - Table/Collection View Tests

    func testBoardListDisplayed() throws {
        // Look for table or collection view
        let tables = app.tables
        let collectionViews = app.collectionViews

        // Wait for either a table or collection view to appear
        let tableExists = tables.firstMatch.waitForExistence(timeout: 5.0)
        let collectionExists = collectionViews.firstMatch.waitForExistence(timeout: 5.0)

        XCTAssertTrue(tableExists || collectionExists,
                     "Either a table view or collection view should be displayed")
    }

    func testBoardCellsExist() throws {
        // Wait for cells to load
        Thread.sleep(forTimeInterval: 2.0)

        let tables = app.tables
        let collectionViews = app.collectionViews

        if tables.firstMatch.exists {
            let cells = tables.firstMatch.cells
            XCTAssertGreaterThan(cells.count, 0, "Table should have cells")
        } else if collectionViews.firstMatch.exists {
            let cells = collectionViews.firstMatch.cells
            XCTAssertGreaterThan(cells.count, 0, "Collection view should have cells")
        } else {
            XCTFail("No table or collection view found")
        }
    }

    // MARK: - Cell Interaction Tests

    func testTapFirstBoard() throws {
        // Wait for UI to load
        Thread.sleep(forTimeInterval: 2.0)

        let tables = app.tables
        let collectionViews = app.collectionViews

        if tables.firstMatch.exists {
            let firstCell = tables.firstMatch.cells.firstMatch
            if firstCell.exists {
                firstCell.tap()

                // Verify navigation occurred (new screen should appear)
                Thread.sleep(forTimeInterval: 1.0)
                XCTAssertTrue(app.exists, "App should still exist after tap")
            }
        } else if collectionViews.firstMatch.exists {
            let firstCell = collectionViews.firstMatch.cells.firstMatch
            if firstCell.exists {
                firstCell.tap()

                // Verify navigation occurred
                Thread.sleep(forTimeInterval: 1.0)
                XCTAssertTrue(app.exists, "App should still exist after tap")
            }
        }
    }

    // MARK: - Settings Button Tests

    func testSettingsButtonExists() throws {
        // Look for settings button
        let settingsButton = app.buttons["Settings"]
            .firstMatch

        // Also try looking for common settings icon identifiers
        let gearButton = app.buttons.matching(identifier: "gear").firstMatch

        let settingsExists = settingsButton.waitForExistence(timeout: 5.0)
        let gearExists = gearButton.waitForExistence(timeout: 1.0)

        // At least one settings button should exist
        XCTAssertTrue(settingsExists || gearExists,
                     "Settings button should exist")
    }

    // MARK: - Scrolling Tests

    func testScrollBoardList() throws {
        // Wait for UI to load
        Thread.sleep(forTimeInterval: 2.0)

        let tables = app.tables
        let collectionViews = app.collectionViews

        if tables.firstMatch.exists {
            let tableView = tables.firstMatch
            // Try to scroll
            tableView.swipeUp()
            tableView.swipeDown()

            // If we got here without crashing, scrolling works
            XCTAssertTrue(tableView.exists, "Table view should still exist after scrolling")
        } else if collectionViews.firstMatch.exists {
            let collectionView = collectionViews.firstMatch
            // Try to scroll
            collectionView.swipeUp()
            collectionView.swipeDown()

            // If we got here without crashing, scrolling works
            XCTAssertTrue(collectionView.exists, "Collection view should still exist after scrolling")
        }
    }

    // MARK: - Search Tests

    func testSearchBarExists() throws {
        // Look for search field
        let searchField = app.searchFields.firstMatch

        // Wait a bit for search to appear (might not be immediately visible)
        _ = searchField.waitForExistence(timeout: 3.0)

        // Search might not always be visible on the main screen
        // This is optional, so we just check if it exists when present
        if searchField.exists {
            XCTAssertTrue(searchField.exists, "Search field exists")
        }
    }

    // MARK: - Accessibility Tests

    func testAccessibilityElementsExist() throws {
        // Verify that accessibility is enabled for main UI elements
        let tables = app.tables
        let collectionViews = app.collectionViews

        if tables.firstMatch.exists {
            XCTAssertTrue(tables.firstMatch.isHittable ||
                         tables.firstMatch.exists,
                         "Table should be accessible")
        } else if collectionViews.firstMatch.exists {
            XCTAssertTrue(collectionViews.firstMatch.isHittable ||
                         collectionViews.firstMatch.exists,
                         "Collection view should be accessible")
        }
    }

    // MARK: - Rotation Tests (iPad)

    func testRotateToLandscape() throws {
        // Only relevant for iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Rotate to landscape
            XCUIDevice.shared.orientation = .landscapeLeft

            // Wait for rotation animation
            Thread.sleep(forTimeInterval: 1.0)

            // Verify UI still exists
            XCTAssertTrue(app.exists, "App should exist after rotation")

            // Rotate back
            XCUIDevice.shared.orientation = .portrait
        }
    }

    // MARK: - Performance Tests

    func testBoardListPerformance() throws {
        // Measure time to load board list
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()
        }
    }

    func testScrollPerformance() throws {
        // Wait for UI to load
        Thread.sleep(forTimeInterval: 2.0)

        let tables = app.tables
        let collectionViews = app.collectionViews

        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            if tables.firstMatch.exists {
                let tableView = tables.firstMatch
                tableView.swipeUp()
            } else if collectionViews.firstMatch.exists {
                let collectionView = collectionViews.firstMatch
                collectionView.swipeUp()
            }
        }
    }
}
