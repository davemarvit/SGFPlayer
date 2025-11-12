import XCTest
@testable import SGFPlayer3D

/// Unit tests for TimeControlManager
/// Tests clock countdown, player switching, and time updates
class TimeControlManagerTests: XCTestCase {

    var timeControl: TimeControlManager!

    override func setUp() {
        super.setUp()
        timeControl = TimeControlManager()
    }

    override func tearDown() {
        timeControl.stopClock()
        timeControl = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertNil(timeControl.blackTimeRemaining)
        XCTAssertNil(timeControl.whiteTimeRemaining)
        XCTAssertNil(timeControl.blackPeriodsRemaining)
        XCTAssertNil(timeControl.whitePeriodsRemaining)
        XCTAssertEqual(timeControl.currentPlayerColor, .black)
        XCTAssertFalse(timeControl.isClockRunning)
    }

    // MARK: - Update From OGS Tests

    func testUpdateFromOGSSetsTime() {
        // When
        timeControl.updateFromOGS(
            blackTime: 300.0,  // 5 minutes
            whiteTime: 250.0,  // 4:10
            blackPeriods: 5,
            whitePeriods: 5,
            blackPeriod: 30.0,
            whitePeriod: 30.0
        )

        // Then
        XCTAssertEqual(timeControl.blackTimeRemaining, 300.0)
        XCTAssertEqual(timeControl.whiteTimeRemaining, 250.0)
        XCTAssertEqual(timeControl.blackPeriodsRemaining, 5)
        XCTAssertEqual(timeControl.whitePeriodsRemaining, 5)
    }

    func testUpdateFromOGSWithNilValues() {
        // When
        timeControl.updateFromOGS(
            blackTime: nil,
            whiteTime: nil,
            blackPeriods: nil,
            whitePeriods: nil,
            blackPeriod: nil,
            whitePeriod: nil
        )

        // Then
        XCTAssertNil(timeControl.blackTimeRemaining)
        XCTAssertNil(timeControl.whiteTimeRemaining)
    }

    // MARK: - Player Switching Tests

    func testSwitchToPlayerChangesCurrentPlayer() {
        // Given
        XCTAssertEqual(timeControl.currentPlayerColor, .black)

        // When
        timeControl.switchToPlayer(.white)

        // Then
        XCTAssertEqual(timeControl.currentPlayerColor, .white)
    }

    func testSwitchToPlayerStopsAndStartsClock() {
        // Given
        timeControl.updateFromOGS(
            blackTime: 300.0,
            whiteTime: 300.0,
            blackPeriods: nil,
            whitePeriods: nil,
            blackPeriod: nil,
            whitePeriod: nil
        )
        timeControl.startClock()
        XCTAssertTrue(timeControl.isClockRunning)

        // When
        timeControl.switchToPlayer(.white)

        // Then
        XCTAssertTrue(timeControl.isClockRunning)
        XCTAssertEqual(timeControl.currentPlayerColor, .white)
    }

    // MARK: - Clock Start/Stop Tests

    func testStartClockSetsRunningFlag() {
        // Given
        timeControl.updateFromOGS(
            blackTime: 300.0,
            whiteTime: 300.0,
            blackPeriods: nil,
            whitePeriods: nil,
            blackPeriod: nil,
            whitePeriod: nil
        )
        XCTAssertFalse(timeControl.isClockRunning)

        // When
        timeControl.startClock()

        // Then
        XCTAssertTrue(timeControl.isClockRunning)
    }

    func testStopClockClearsRunningFlag() {
        // Given
        timeControl.updateFromOGS(
            blackTime: 300.0,
            whiteTime: 300.0,
            blackPeriods: nil,
            whitePeriods: nil,
            blackPeriod: nil,
            whitePeriod: nil
        )
        timeControl.startClock()
        XCTAssertTrue(timeControl.isClockRunning)

        // When
        timeControl.stopClock()

        // Then
        XCTAssertFalse(timeControl.isClockRunning)
    }

    func testClockCountdownForBlack() {
        // Given
        timeControl.updateFromOGS(
            blackTime: 10.0,
            whiteTime: 300.0,
            blackPeriods: nil,
            whitePeriods: nil,
            blackPeriod: nil,
            whitePeriod: nil
        )
        timeControl.switchToPlayer(.black)

        // When
        timeControl.startClock()

        // Wait for clock to tick
        let expectation = XCTestExpectation(description: "Wait for clock tick")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // Then - black time should have decreased
        XCTAssertLessThan(timeControl.blackTimeRemaining ?? 0, 10.0)
        // White time should be unchanged
        XCTAssertEqual(timeControl.whiteTimeRemaining, 300.0)
    }

    func testClockCountdownForWhite() {
        // Given
        timeControl.updateFromOGS(
            blackTime: 300.0,
            whiteTime: 10.0,
            blackPeriods: nil,
            whitePeriods: nil,
            blackPeriod: nil,
            whitePeriod: nil
        )
        timeControl.switchToPlayer(.white)

        // When
        timeControl.startClock()

        // Wait for clock to tick
        let expectation = XCTestExpectation(description: "Wait for clock tick")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        // Then - white time should have decreased
        XCTAssertLessThan(timeControl.whiteTimeRemaining ?? 0, 10.0)
        // Black time should be unchanged
        XCTAssertEqual(timeControl.blackTimeRemaining, 300.0)
    }

    // MARK: - Reset Tests

    func testResetClearsAllState() {
        // Given
        timeControl.updateFromOGS(
            blackTime: 300.0,
            whiteTime: 250.0,
            blackPeriods: 5,
            whitePeriods: 4,
            blackPeriod: 30.0,
            whitePeriod: 30.0
        )
        timeControl.startClock()

        // When
        timeControl.reset()

        // Then
        XCTAssertNil(timeControl.blackTimeRemaining)
        XCTAssertNil(timeControl.whiteTimeRemaining)
        XCTAssertNil(timeControl.blackPeriodsRemaining)
        XCTAssertNil(timeControl.whitePeriodsRemaining)
        XCTAssertEqual(timeControl.currentPlayerColor, .black)
        XCTAssertFalse(timeControl.isClockRunning)
    }

    // MARK: - Byo-yomi Tests

    func testByoYomiPeriodsDisplay() {
        // Given
        timeControl.updateFromOGS(
            blackTime: 30.0,
            whiteTime: 30.0,
            blackPeriods: 3,
            whitePeriods: 1,  // Sudden death
            blackPeriod: 30.0,
            whitePeriod: 30.0
        )

        // Then
        XCTAssertEqual(timeControl.blackPeriodsRemaining, 3)
        XCTAssertEqual(timeControl.whitePeriodsRemaining, 1)  // Should show SD in UI
    }
}
