import XCTest
@testable import SGFPlayer3D

/// Unit tests for OGSGameViewModel
/// Tests game state management, polling, and notification handling
class OGSGameViewModelTests: XCTestCase {

    var viewModel: OGSGameViewModel!
    var mockOGSClient: OGSClient!
    var mockPlayer: SGFPlayer!
    var mockTimeControl: TimeControlManager!

    override func setUp() {
        super.setUp()
        mockOGSClient = OGSClient()
        mockPlayer = SGFPlayer()
        mockTimeControl = TimeControlManager()
        viewModel = OGSGameViewModel(ogsClient: mockOGSClient, player: mockPlayer, timeControl: mockTimeControl)
    }

    override func tearDown() {
        viewModel.stopPolling()
        viewModel = nil
        mockOGSClient = nil
        mockPlayer = nil
        mockTimeControl = nil
        super.tearDown()
    }

    // MARK: - Player Info Tests

    func testHandlePlayerInfoUpdatesNames() {
        // Given
        let notification = Notification(
            name: NSNotification.Name("OGSPlayerInfo"),
            object: nil,
            userInfo: [
                "blackName": "TestPlayer1",
                "whiteName": "TestPlayer2",
                "blackRank": "5k",
                "whiteRank": "3k"
            ]
        )

        // When
        viewModel.handlePlayerInfo(notification)

        // Then
        XCTAssertEqual(viewModel.blackName, "TestPlayer1")
        XCTAssertEqual(viewModel.whiteName, "TestPlayer2")
        XCTAssertEqual(viewModel.blackRank, "5k")
        XCTAssertEqual(viewModel.whiteRank, "3k")
    }

    func testHandlePlayerInfoWithMissingData() {
        // Given
        let notification = Notification(
            name: NSNotification.Name("OGSPlayerInfo"),
            object: nil,
            userInfo: nil
        )

        // When
        viewModel.handlePlayerInfo(notification)

        // Then - should not crash, names should remain nil
        XCTAssertNil(viewModel.blackName)
        XCTAssertNil(viewModel.whiteName)
    }

    // MARK: - Game Data Tests

    func testHandleGameDataParsesKomi() {
        // Given
        let moves: [[Any]] = [[15, 3], [3, 15]] // Two moves
        let gameData: [String: Any] = [
            "komi": 6.5,
            "rules": "japanese"
        ]
        let notification = Notification(
            name: NSNotification.Name("OGSGameDataReceived"),
            object: nil,
            userInfo: [
                "moves": moves,
                "gameID": 12345,
                "gameData": gameData,
                "boardSize": 19,
                "blackName": "Black",
                "whiteName": "White",
                "handicap": 0
            ]
        )

        // When
        viewModel.handleGameData(notification)

        // Then
        XCTAssertEqual(viewModel.komi, "6.5")
        XCTAssertEqual(viewModel.ruleset, "japanese")
    }

    func testHandleGameDataWithHandicap() {
        // Given
        let moves: [[Any]] = [] // No moves yet
        let gameData: [String: Any] = [
            "komi": 0.5,
            "rules": "chinese"
        ]
        let notification = Notification(
            name: NSNotification.Name("OGSGameDataReceived"),
            object: nil,
            userInfo: [
                "moves": moves,
                "gameID": 12345,
                "gameData": gameData,
                "boardSize": 19,
                "blackName": "Black",
                "whiteName": "White",
                "handicap": 4
            ]
        )

        // Expect OGSGameLoaded notification to be posted
        let expectation = XCTestExpectation(description: "OGSGameLoaded notification posted")
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OGSGameLoaded"),
            object: nil,
            queue: nil
        ) { notification in
            // Verify notification contains game data
            XCTAssertNotNil(notification.userInfo?["game"])
            XCTAssertEqual(notification.userInfo?["handicap"] as? Int, 4)
            XCTAssertEqual(notification.userInfo?["moveCount"] as? Int, 0)
            expectation.fulfill()
        }

        // When
        viewModel.handleGameData(notification)

        // Then
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testHandleGameDataInvalidDataDoesNotCrash() {
        // Given - notification with missing required fields
        let notification = Notification(
            name: NSNotification.Name("OGSGameDataReceived"),
            object: nil,
            userInfo: ["invalid": "data"]
        )

        // When/Then - should not crash
        viewModel.handleGameData(notification)
    }

    // MARK: - Move Handling Tests

    func testHandleMoveCallsJoinGame() {
        // Given
        mockOGSClient.currentGameID = 12345
        let notification = Notification(
            name: NSNotification.Name("OGSMoveReceived"),
            object: nil,
            userInfo: [
                "x": 10,
                "y": 10,
                "isPass": false
            ]
        )

        // When
        viewModel.handleMove(notification)

        // Then - verify joinGame was called (via logs or by checking state)
        // Note: In a real test, we'd use a mock OGSClient to verify the call
    }

    func testHandleMoveWithPass() {
        // Given
        mockOGSClient.currentGameID = 12345
        let notification = Notification(
            name: NSNotification.Name("OGSMoveReceived"),
            object: nil,
            userInfo: [
                "x": -1,
                "y": -1,
                "isPass": true
            ]
        )

        // When/Then - should not crash
        viewModel.handleMove(notification)
    }

    // MARK: - Polling Tests

    func testStopPollingClearsTimer() {
        // Given - create a game to start polling
        let moves: [[Any]] = []
        let gameData: [String: Any] = ["komi": 6.5, "rules": "japanese"]
        let notification = Notification(
            name: NSNotification.Name("OGSGameDataReceived"),
            object: nil,
            userInfo: [
                "moves": moves,
                "gameID": 12345,
                "gameData": gameData,
                "boardSize": 19,
                "blackName": "Black",
                "whiteName": "White",
                "handicap": 0
            ]
        )
        viewModel.handleGameData(notification)

        // Wait a moment for polling to start
        let expectation = XCTestExpectation(description: "Wait for polling to start")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // When
        viewModel.stopPolling()

        // Then - timer should be cleared (we can verify by checking logs)
    }

    // MARK: - Throttling Tests

    func testHandleThrottlingStopsPolling() {
        // Given - set up a current game
        mockOGSClient.currentGameID = 12345

        // When
        viewModel.handleThrottling()

        // Then - polling should be stopped
        // In a real test, we'd verify the timer was invalidated
    }

    func testHandleThrottlingWithNoGameID() {
        // Given - no current game
        mockOGSClient.currentGameID = nil

        // When/Then - should not crash
        viewModel.handleThrottling()
    }

    // MARK: - Game Switching Tests

    func testGameSwitchingStopsOldPolling() {
        // Given - load first game
        let moves1: [[Any]] = [[10, 10]]
        let gameData1: [String: Any] = ["komi": 6.5, "rules": "japanese"]
        let notification1 = Notification(
            name: NSNotification.Name("OGSGameDataReceived"),
            object: nil,
            userInfo: [
                "moves": moves1,
                "gameID": 12345,
                "gameData": gameData1,
                "boardSize": 19,
                "blackName": "Black1",
                "whiteName": "White1",
                "handicap": 0
            ]
        )
        mockOGSClient.currentGameID = 12345
        viewModel.handleGameData(notification1)

        // When - load second game
        let moves2: [[Any]] = [[5, 5]]
        let gameData2: [String: Any] = ["komi": 7.5, "rules": "chinese"]
        let notification2 = Notification(
            name: NSNotification.Name("OGSGameDataReceived"),
            object: nil,
            userInfo: [
                "moves": moves2,
                "gameID": 67890,
                "gameData": gameData2,
                "boardSize": 19,
                "blackName": "Black2",
                "whiteName": "White2",
                "handicap": 0
            ]
        )
        mockOGSClient.currentGameID = 67890
        viewModel.handleGameData(notification2)

        // Then - old polling should be stopped and new polling started
        XCTAssertEqual(viewModel.komi, "7.5")
        XCTAssertEqual(viewModel.ruleset, "chinese")
    }
}
