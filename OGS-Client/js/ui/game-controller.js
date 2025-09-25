/**
 * Game Controller - Manages active game view with your beautiful board rendering
 */

class GameController {
    constructor(gameEngine, ogsClient, meetIntegration) {
        this.gameEngine = gameEngine;
        this.ogsClient = ogsClient;
        this.meetIntegration = meetIntegration;

        // Game state
        this.currentGameId = null;
        this.gameData = null;
        this.boardRenderer = null;
        this.isMyTurn = false;
        this.myColor = null;

        // UI elements
        this.elements = {};

        // Chat
        this.gameChatMessages = [];
    }

    initialize() {
        this.initializeElements();
        this.setupEventListeners();
        this.initializeBoardRenderer();

        Logger.info('GameController initialized');
    }

    initializeElements() {
        this.elements = {
            // Player info
            blackPlayerName: document.getElementById('black-player-name'),
            blackPlayerRank: document.getElementById('black-player-rank'),
            blackCaptured: document.getElementById('black-captured'),

            whitePlayerName: document.getElementById('white-player-name'),
            whitePlayerRank: document.getElementById('white-player-rank'),
            whiteCaptured: document.getElementById('white-captured'),

            // Game status
            turnIndicator: document.getElementById('turn-indicator'),
            timeRemaining: document.getElementById('time-remaining'),

            // Game controls
            passBtn: document.getElementById('pass-btn'),
            resignBtn: document.getElementById('resign-btn'),
            meetBtn: document.getElementById('meet-btn'),

            // Board
            goBoard: document.getElementById('go-board'),
            bowlOverlay: document.getElementById('bowl-overlay'),
            blackBowl: document.getElementById('black-bowl'),
            whiteBowl: document.getElementById('white-bowl'),

            // Chat
            gameChatMessages: document.getElementById('game-chat-messages'),
            gameChatInput: document.getElementById('game-chat-input'),
            gameChatSend: document.getElementById('game-chat-send')
        };
    }

    setupEventListeners() {
        // Game controls
        this.elements.passBtn.addEventListener('click', () => {
            this.pass();
        });

        this.elements.resignBtn.addEventListener('click', () => {
            this.resign();
        });

        this.elements.meetBtn.addEventListener('click', () => {
            this.handleMeetButton();
        });

        // Chat
        this.elements.gameChatSend.addEventListener('click', () => {
            this.sendGameChat();
        });

        this.elements.gameChatInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.sendGameChat();
            }
        });

        // Game engine events
        this.gameEngine.addEventListener('liveMove', (e) => {
            this.handleLocalMove(e.detail);
        });
    }

    initializeBoardRenderer() {
        console.log('Trying to initialize BoardRenderer...');
        console.log('Canvas element:', this.elements.goBoard);

        if (!this.elements.goBoard) {
            Logger.error('Go board canvas not found');
            console.error('Canvas element with id "go-board" not found!');
            return;
        }

        console.log('Creating BoardRenderer...');
        // Initialize board renderer with your beautiful rendering
        this.boardRenderer = new BoardRenderer(this.elements.goBoard, {
            boardSize: 19,
            jitterMultiplier: 0.3
        });

        console.log('BoardRenderer created:', this.boardRenderer);

        // Connect to game engine
        this.boardRenderer.setEngine(this.gameEngine);

        // Set up click handler for moves
        this.boardRenderer.setClickHandler((x, y) => {
            this.handleBoardClick(x, y);
        });

        Logger.info('Board renderer initialized');
    }

    // Game Management

    setGame(gameId) {
        this.currentGameId = gameId;
        Logger.info(`Setting current game to ${gameId}`);

        // Reset state
        this.gameData = null;
        this.gameChatMessages = [];

        // Update meet button
        this.updateMeetButton();
    }

    updateGame(gameData) {
        this.gameData = gameData;

        // Update player information
        this.updatePlayerInfo();

        // Update game status
        this.updateGameStatus();

        // Update board from OGS game data
        if (gameData.board) {
            this.gameEngine.setBoardFromOGS(gameData);
        }

        // Determine my color
        this.determineMyColor();

        // Update turn indicator
        this.updateTurnIndicator();

        Logger.info('Game updated:', gameData);
    }

    updatePlayerInfo() {
        if (!this.gameData) return;

        const { players } = this.gameData;

        // Black player
        if (players?.black) {
            this.elements.blackPlayerName.textContent = players.black.username;
            this.elements.blackPlayerRank.textContent = players.black.rank || '?k';
        }

        // White player
        if (players?.white) {
            this.elements.whitePlayerName.textContent = players.white.username;
            this.elements.whitePlayerRank.textContent = players.white.rank || '?k';
        }

        // Captured stones
        this.updateCapturedStones();
    }

    updateCapturedStones() {
        const captured = this.gameEngine.capturedStones;
        this.elements.blackCaptured.textContent = `Captured: ${captured.black.length}`;
        this.elements.whiteCaptured.textContent = `Captured: ${captured.white.length}`;
    }

    updateGameStatus() {
        if (!this.gameData) return;

        // Update time remaining
        this.updateTimeDisplay();

        // Update game phase
        if (this.gameData.phase === 'finished') {
            this.handleGameFinished();
        }
    }

    updateTimeDisplay() {
        if (!this.gameData?.clock) {
            this.elements.timeRemaining.textContent = '--:--';
            return;
        }

        const clock = this.gameData.clock;
        const currentPlayer = this.gameData.current_player;

        let timeLeft;
        if (currentPlayer === 'black') {
            timeLeft = clock.black_time;
        } else {
            timeLeft = clock.white_time;
        }

        this.elements.timeRemaining.textContent = this.formatTime(timeLeft);

        // Start countdown if it's live game
        if (this.gameData.time_control?.system === 'byoyomi') {
            this.startTimeCountdown(timeLeft);
        }
    }

    startTimeCountdown(initialTime) {
        // Clear existing countdown
        if (this.timeCountdownInterval) {
            clearInterval(this.timeCountdownInterval);
        }

        let timeLeft = initialTime;

        this.timeCountdownInterval = setInterval(() => {
            timeLeft -= 1000; // Decrease by 1 second

            if (timeLeft <= 0) {
                timeLeft = 0;
                clearInterval(this.timeCountdownInterval);
            }

            this.elements.timeRemaining.textContent = this.formatTime(timeLeft);
        }, 1000);
    }

    determineMyColor() {
        if (!this.gameData || !this.ogsClient.userInfo) return;

        const myId = this.ogsClient.userInfo.id;
        const { players } = this.gameData;

        if (players?.black?.id === myId) {
            this.myColor = Stone.BLACK;
        } else if (players?.white?.id === myId) {
            this.myColor = Stone.WHITE;
        } else {
            this.myColor = null; // Observer
        }

        Logger.info(`My color: ${this.myColor || 'Observer'}`);
    }

    updateTurnIndicator() {
        if (!this.gameData) return;

        const currentPlayer = this.gameData.current_player;
        this.isMyTurn = currentPlayer === this.myColor;

        // Update indicator text
        if (currentPlayer === Stone.BLACK) {
            this.elements.turnIndicator.textContent = 'Black to play';
        } else if (currentPlayer === Stone.WHITE) {
            this.elements.turnIndicator.textContent = 'White to play';
        } else {
            this.elements.turnIndicator.textContent = 'Game finished';
        }

        // Highlight current player
        document.querySelectorAll('.player').forEach(el => {
            el.classList.remove('active');
        });

        if (currentPlayer === Stone.BLACK) {
            document.querySelector('.player.black').classList.add('active');
        } else if (currentPlayer === Stone.WHITE) {
            document.querySelector('.player.white').classList.add('active');
        }

        // Update board renderer current player
        if (this.boardRenderer) {
            this.boardRenderer.setCurrentPlayer(currentPlayer);
        }
    }

    // Game Actions

    handleBoardClick(x, y) {
        if (!this.isMyTurn) {
            Logger.warning('Not your turn');
            return;
        }

        if (!this.gameData || this.gameData.phase !== 'play') {
            Logger.warning('Game is not in play phase');
            return;
        }

        // Validate move locally first
        if (!this.gameEngine.board.isEmpty(x, y)) {
            Logger.warning(`Position (${x},${y}) is not empty`);
            return;
        }

        // Make move via OGS
        this.ogsClient.makeMove(this.currentGameId, x, y);

        Logger.info(`Move attempted: ${x}, ${y}`);
    }

    pass() {
        if (!this.isMyTurn) {
            Logger.warning('Not your turn');
            return;
        }

        if (confirm('Are you sure you want to pass?')) {
            this.ogsClient.pass(this.currentGameId);
            Logger.info('Pass move submitted');
        }
    }

    resign() {
        if (!this.gameData || this.gameData.phase === 'finished') {
            Logger.warning('Game is already finished');
            return;
        }

        if (confirm('Are you sure you want to resign this game?')) {
            this.ogsClient.resign(this.currentGameId);
            Logger.info('Resignation submitted');
        }
    }

    handleLocalMove(moveData) {
        // This handles moves made through the local game engine
        // Update captured stones display
        this.updateCapturedStones();
    }

    // Move Handling from OGS

    handleMove(data) {
        const { move, gameId } = data;

        if (gameId !== this.currentGameId) return;

        Logger.info('Received move from OGS:', move);

        // Update game engine with the move
        if (move.x !== undefined && move.y !== undefined) {
            // Regular move
            this.gameEngine.makeMove(move.x, move.y);
        } else {
            // Pass move
            this.gameEngine.pass();
        }

        // Update turn indicator
        this.updateTurnIndicator();
    }

    handleGameFinished() {
        // Clear countdown
        if (this.timeCountdownInterval) {
            clearInterval(this.timeCountdownInterval);
        }

        // Show game result
        this.showGameResult();
    }

    showGameResult() {
        if (!this.gameData?.outcome) return;

        const result = this.gameData.outcome;
        let message = 'Game finished';

        if (result.winner) {
            const winnerColor = result.winner === 'black' ? 'Black' : 'White';
            message = `${winnerColor} wins`;

            if (result.by) {
                switch (result.by) {
                    case 'resignation':
                        message += ' by resignation';
                        break;
                    case 'timeout':
                        message += ' by timeout';
                        break;
                    case 'points':
                        message += ` by ${result.margin} points`;
                        break;
                }
            }
        } else {
            message = 'Game ended in a draw';
        }

        // Show result modal or notification
        this.showNotification(message, 'info', 10000);
    }

    // Google Meet Integration

    handleMeetButton() {
        const buttonState = this.meetIntegration.getMeetingButtonState(this.currentGameId);

        if (buttonState.action === 'create') {
            this.startMeetSession();
        } else if (buttonState.action === 'join') {
            this.joinMeetSession();
        }
    }

    async startMeetSession() {
        try {
            Logger.info('Starting Google Meet session...');

            // Create meeting
            const meetingInfo = await this.meetIntegration.createMeetingWithFallback(this.currentGameId);

            // Send invite to opponent
            const opponentId = this.getOpponentId();
            if (opponentId) {
                await this.meetIntegration.inviteOpponent(this.currentGameId, this.ogsClient, opponentId);
            }

            // Update button
            this.updateMeetButton();

            this.showNotification('Video call invite sent to opponent!', 'success');

        } catch (error) {
            Logger.error('Failed to start meet session:', error);
            this.showNotification('Failed to start video call', 'error');
        }
    }

    joinMeetSession() {
        try {
            this.meetIntegration.joinMeeting(this.currentGameId);
            this.showNotification('Joining video call...', 'info');
        } catch (error) {
            this.showNotification(error.message, 'warning');
        }
    }

    updateMeetButton() {
        const buttonState = this.meetIntegration.getMeetingButtonState(this.currentGameId);
        this.elements.meetBtn.textContent = buttonState.text;
        this.elements.meetBtn.disabled = buttonState.disabled;
    }

    getOpponentId() {
        if (!this.gameData?.players || !this.myColor) return null;

        const opponentColor = this.myColor === Stone.BLACK ? 'white' : 'black';
        return this.gameData.players[opponentColor]?.id;
    }

    // Chat

    handleGameChat(message) {
        this.gameChatMessages.push({
            id: Date.now(),
            username: message.username,
            message: message.message,
            timestamp: new Date()
        });

        this.renderGameChat();

        // Check for meet invitations in chat
        const meetInvite = this.meetIntegration.parseMeetingInvite(message.message);
        if (meetInvite) {
            this.handleMeetInviteReceived(meetInvite, message.username);
        }
    }

    renderGameChat() {
        const container = this.elements.gameChatMessages;

        container.innerHTML = this.gameChatMessages.map(msg => `
            <div class="chat-message">
                <span class="chat-username">${msg.username}:</span>
                ${this.escapeHtml(msg.message)}
                <span class="chat-timestamp">${this.formatTime(msg.timestamp)}</span>
            </div>
        `).join('');

        container.scrollTop = container.scrollHeight;
    }

    sendGameChat() {
        const input = this.elements.gameChatInput;
        const message = input.value.trim();

        if (!message) return;

        this.ogsClient.sendGameChat(this.currentGameId, message);
        input.value = '';
    }

    handleMeetInviteReceived(invite, fromUser) {
        // Show notification about meet invite
        const notification = document.createElement('div');
        notification.className = 'meet-invite-notification';
        notification.innerHTML = `
            <div class="notification-content">
                <h4>Video Call Invitation</h4>
                <p>${fromUser} has invited you to a Google Meet call!</p>
                <div class="meet-actions">
                    <button class="btn btn-secondary" onclick="this.parentElement.parentElement.parentElement.remove()">Ignore</button>
                    <button class="btn btn-primary" onclick="gameController.joinMeetFromInvite('${invite.meetingUri}')">Join Call</button>
                </div>
            </div>
        `;

        document.body.appendChild(notification);

        // Auto-remove after 30 seconds
        setTimeout(() => {
            if (notification.parentElement) {
                notification.remove();
            }
        }, 30000);
    }

    joinMeetFromInvite(meetingUri) {
        window.open(meetingUri, '_blank');
        document.querySelectorAll('.meet-invite-notification').forEach(el => el.remove());
    }

    // Utility Methods

    formatTime(milliseconds) {
        const seconds = Math.floor(milliseconds / 1000);
        const minutes = Math.floor(seconds / 60);
        const remainingSeconds = seconds % 60;

        return `${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    showNotification(message, type = 'info', duration = 5000) {
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.textContent = message;

        document.body.appendChild(notification);

        setTimeout(() => {
            notification.remove();
        }, duration);
    }

    // Cleanup

    cleanup() {
        if (this.timeCountdownInterval) {
            clearInterval(this.timeCountdownInterval);
        }

        if (this.currentGameId) {
            this.meetIntegration.endMeeting(this.currentGameId);
        }
    }

    setupDemoBoard() {
        Logger.info('Setting up demo board to showcase your assets');

        // Setup demo game info
        this.elements.blackPlayerName.textContent = 'Your Black Stones';
        this.elements.blackPlayerRank.textContent = '5k';
        this.elements.blackCaptured.textContent = 'Captured: 3';

        this.elements.whitePlayerName.textContent = 'Your White Stones';
        this.elements.whitePlayerRank.textContent = '3k';
        this.elements.whiteCaptured.textContent = 'Captured: 2';

        this.elements.turnIndicator.textContent = 'Demo Mode - Click to place stones';
        this.elements.timeRemaining.textContent = '∞';

        // Create a new board with some demo stones to showcase your assets
        if (this.boardRenderer) {
            // Add some demo stones to show off your beautiful assets
            const demoStones = [
                { x: 3, y: 3, stone: Stone.BLACK },
                { x: 15, y: 15, stone: Stone.WHITE },
                { x: 3, y: 15, stone: Stone.BLACK },
                { x: 15, y: 3, stone: Stone.WHITE },
                { x: 9, y: 9, stone: Stone.BLACK },
                { x: 9, y: 10, stone: Stone.WHITE },
                { x: 10, y: 9, stone: Stone.WHITE },
                { x: 10, y: 10, stone: Stone.BLACK },
                // Add a few more to show variations
                { x: 5, y: 5, stone: Stone.WHITE },
                { x: 13, y: 13, stone: Stone.BLACK },
                { x: 5, y: 13, stone: Stone.WHITE },
                { x: 13, y: 5, stone: Stone.BLACK }
            ];

            // Create a mock board state
            const mockBoard = {
                size: 19,
                stones: new Map(),
                getStone: function(x, y) {
                    return this.stones.get(`${x},${y}`) || null;
                },
                isEmpty: function(x, y) {
                    return !this.stones.has(`${x},${y}`);
                }
            };

            // Add demo stones to mock board
            demoStones.forEach(({ x, y, stone }) => {
                mockBoard.stones.set(`${x},${y}`, stone);
            });

            this.boardRenderer.updateBoard(mockBoard);

            // Add alternating stone counter and capture tracking
            this.demoMoveCount = demoStones.length;
            this.demoCapturedStones = { black: 3, white: 2 }; // Initial captured counts

            // Set initial cursor color to show the next player's stone
            const initialNextStone = (this.demoMoveCount % 2 === 0) ? Stone.BLACK : Stone.WHITE;
            this.boardRenderer.setCurrentPlayer(initialNextStone);

            // Enable clicking to add stones in demo mode with proper Go capture logic
            this.boardRenderer.setClickHandler((x, y) => {
                if (mockBoard.isEmpty(x, y)) {
                    // Proper alternating: Black plays first (move 0), then White (move 1), etc.
                    const newStone = (this.demoMoveCount % 2 === 0) ? Stone.BLACK : Stone.WHITE;
                    mockBoard.stones.set(`${x},${y}`, newStone);
                    this.demoMoveCount++;

                    // Update board renderer with the new board state first
                    this.boardRenderer.updateBoard(mockBoard);

                    // Update current player for cursor preview - show NEXT player's stone
                    const nextStone = (this.demoMoveCount % 2 === 0) ? Stone.BLACK : Stone.WHITE;
                    this.boardRenderer.setCurrentPlayer(nextStone);

                    // Check for captures after placing the stone
                    const capturedStones = this.checkForCaptures(mockBoard, x, y, newStone);
                    if (capturedStones.length > 0) {
                        // Create capture data for bowl rendering
                        const captures = [];

                        // Remove captured stones from board
                        capturedStones.forEach(pos => {
                            const [cx, cy] = pos.split(',').map(Number);
                            const capturedStone = mockBoard.stones.get(pos);
                            mockBoard.stones.delete(pos);

                            // Add to captures for bowl animation
                            captures.push({
                                stone: capturedStone,
                                position: { x: cx, y: cy }
                            });

                            // Update capture counts
                            if (capturedStone === Stone.BLACK) {
                                this.demoCapturedStones.white++;
                                this.elements.whiteCaptured.textContent = `Captured: ${this.demoCapturedStones.white}`;
                            } else {
                                this.demoCapturedStones.black++;
                                this.elements.blackCaptured.textContent = `Captured: ${this.demoCapturedStones.black}`;
                            }
                        });

                        // Add captured stones to bowls visually
                        this.boardRenderer.updateBowlStones(captures);
                        // Update board again after captures
                        this.boardRenderer.updateBoard(mockBoard);
                        Logger.info(`Captured ${capturedStones.length} stone(s)!`);
                    }

                    Logger.info(`Move ${this.demoMoveCount - 1}: Added ${newStone === Stone.BLACK ? 'black' : 'white'} stone at ${x},${y}`);
                }
            });
        }
    }

    // Go capture logic
    checkForCaptures(board, lastX, lastY, lastStone) {
        const capturedStones = [];
        const oppositeStone = lastStone === Stone.BLACK ? Stone.WHITE : Stone.BLACK;

        // Check all adjacent positions for opponent stones to capture
        const directions = [[0, 1], [1, 0], [0, -1], [-1, 0]]; // up, right, down, left

        for (const [dx, dy] of directions) {
            const adjX = lastX + dx;
            const adjY = lastY + dy;

            if (this.isInBounds(adjX, adjY, board.size) &&
                board.getStone(adjX, adjY) === oppositeStone) {

                // Found an opponent stone, check if its group is captured
                const group = this.getGroup(board, adjX, adjY);
                if (this.hasNoLiberties(board, group)) {
                    // This group is captured, add all stones to captured list
                    group.forEach(pos => capturedStones.push(pos));
                }
            }
        }

        return capturedStones;
    }

    isInBounds(x, y, boardSize) {
        return x >= 0 && x < boardSize && y >= 0 && y < boardSize;
    }

    getGroup(board, startX, startY) {
        const group = new Set();
        const stone = board.getStone(startX, startY);
        if (!stone) return group;

        const stack = [`${startX},${startY}`];
        group.add(`${startX},${startY}`);

        while (stack.length > 0) {
            const current = stack.pop();
            const [x, y] = current.split(',').map(Number);

            // Check all adjacent positions
            const directions = [[0, 1], [1, 0], [0, -1], [-1, 0]];
            for (const [dx, dy] of directions) {
                const nx = x + dx;
                const ny = y + dy;
                const pos = `${nx},${ny}`;

                if (this.isInBounds(nx, ny, board.size) &&
                    !group.has(pos) &&
                    board.getStone(nx, ny) === stone) {

                    group.add(pos);
                    stack.push(pos);
                }
            }
        }

        return group;
    }

    hasNoLiberties(board, group) {
        // Check if any stone in the group has a liberty (empty adjacent space)
        for (const pos of group) {
            const [x, y] = pos.split(',').map(Number);
            const directions = [[0, 1], [1, 0], [0, -1], [-1, 0]];

            for (const [dx, dy] of directions) {
                const nx = x + dx;
                const ny = y + dy;

                if (this.isInBounds(nx, ny, board.size) && board.isEmpty(nx, ny)) {
                    return false; // Found a liberty
                }
            }
        }

        return true; // No liberties found
    }
}

// Export for web usage
window.GameController = GameController;