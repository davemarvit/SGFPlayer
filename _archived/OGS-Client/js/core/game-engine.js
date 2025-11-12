/**
 * Game Engine - Adapted from SGFPlayerEngine.swift
 * Handles board state, move validation, captures, and territory calculation
 */

class BoardSnapshot {
    constructor(size, grid) {
        this.size = size;
        this.grid = grid || Array(size).fill().map(() => Array(size).fill(null));
    }

    clone() {
        const newGrid = this.grid.map(row => [...row]);
        return new BoardSnapshot(this.size, newGrid);
    }

    getStone(x, y) {
        if (x < 0 || x >= this.size || y < 0 || y >= this.size) return null;
        return this.grid[y][x];
    }

    setStone(x, y, stone) {
        if (x >= 0 && x < this.size && y >= 0 && y < this.size) {
            this.grid[y][x] = stone;
        }
    }

    isEmpty(x, y) {
        return this.getStone(x, y) === null;
    }

    // Get all adjacent points
    getAdjacent(x, y) {
        const adjacent = [];
        const directions = [[0, 1], [1, 0], [0, -1], [-1, 0]];

        for (const [dx, dy] of directions) {
            const nx = x + dx;
            const ny = y + dy;
            if (nx >= 0 && nx < this.size && ny >= 0 && ny < this.size) {
                adjacent.push({x: nx, y: ny});
            }
        }
        return adjacent;
    }

    // Find connected group of stones
    getGroup(x, y) {
        const stone = this.getStone(x, y);
        if (!stone) return [];

        const group = [];
        const visited = new Set();
        const stack = [{x, y}];

        while (stack.length > 0) {
            const {x: cx, y: cy} = stack.pop();
            const key = `${cx},${cy}`;

            if (visited.has(key)) continue;
            visited.add(key);

            if (this.getStone(cx, cy) === stone) {
                group.push({x: cx, y: cy});

                for (const {x: nx, y: ny} of this.getAdjacent(cx, cy)) {
                    if (!visited.has(`${nx},${ny}`)) {
                        stack.push({x: nx, y: ny});
                    }
                }
            }
        }

        return group;
    }

    // Check if a group has liberties (empty adjacent points)
    hasLiberties(group) {
        const liberties = new Set();

        for (const {x, y} of group) {
            for (const {x: nx, y: ny} of this.getAdjacent(x, y)) {
                if (this.isEmpty(nx, ny)) {
                    liberties.add(`${nx},${ny}`);
                }
            }
        }

        return liberties.size > 0;
    }

    // Find captured groups after a move
    findCaptures(x, y, stone) {
        const captures = [];
        const opponentStone = stone === Stone.BLACK ? Stone.WHITE : Stone.BLACK;

        for (const {x: nx, y: ny} of this.getAdjacent(x, y)) {
            if (this.getStone(nx, ny) === opponentStone) {
                const group = this.getGroup(nx, ny);
                if (!this.hasLiberties(group)) {
                    captures.push(...group);
                }
            }
        }

        return captures;
    }

    // Check if a move would be suicide
    isSuicide(x, y, stone) {
        if (!this.isEmpty(x, y)) return false;

        // Temporarily place the stone
        const testBoard = this.clone();
        testBoard.setStone(x, y, stone);

        // Check if this move captures any opponent stones
        const captures = testBoard.findCaptures(x, y, stone);
        if (captures.length > 0) return false; // Capture, so not suicide

        // Check if the placed stone's group has liberties
        const group = testBoard.getGroup(x, y);
        return !testBoard.hasLiberties(group);
    }

    // Count stones on the board
    countStones() {
        let black = 0, white = 0;
        for (let y = 0; y < this.size; y++) {
            for (let x = 0; x < this.size; x++) {
                const stone = this.getStone(x, y);
                if (stone === Stone.BLACK) black++;
                else if (stone === Stone.WHITE) white++;
            }
        }
        return { black, white };
    }
}

class MoveRef {
    constructor(color, x, y) {
        this.color = color;
        this.x = x;
        this.y = y;
    }

    equals(other) {
        return other &&
               this.color === other.color &&
               this.x === other.x &&
               this.y === other.y;
    }
}

/**
 * SGF Player Engine - Adapted from Swift version
 */
class SGFPlayerEngine extends EventTarget {
    constructor() {
        super();

        // Public, read-only state the UI renders
        this._board = new BoardSnapshot(19);
        this._lastMove = null;
        this._isPlaying = false;
        this._currentIndex = 0;
        this._playInterval = 0.75; // seconds per move

        // Internal model snapshot for the current game
        this._moves = []; // [{stone: Stone, coord: {x, y} | null}] (null = pass)
        this._baseSize = 19;
        this._baseSetup = []; // [{stone: Stone, x, y}]
        this._timer = null;

        // Capture tracking
        this._capturedStones = { black: [], white: [] };

        Logger.info('SGFPlayerEngine initialized');
    }

    // Getters
    get board() { return this._board; }
    get lastMove() { return this._lastMove; }
    get isPlaying() { return this._isPlaying; }
    get currentIndex() { return this._currentIndex; }
    get playInterval() { return this._playInterval; }
    get maxIndex() { return Math.max(0, this._moves.length); }
    get moves() { return this._moves; }
    get baseSetup() { return this._baseSetup; }
    get capturedStones() { return this._capturedStones; }

    set playInterval(value) {
        this._playInterval = value;
        if (this._isPlaying) {
            this.pause();
            this.play();
        }
    }

    // Load a new SGF game
    load(game) {
        Logger.info(`Loading game with board size ${game.boardSize}, ${game.moves.length} moves`);
        this._baseSize = game.boardSize;
        this._baseSetup = game.setup.map(s => ({stone: s.stone, x: s.x, y: s.y}));
        this._moves = game.moves.map(m => ({stone: m.stone, coord: m.coord}));
        Logger.debug(`First 5 moves:`, this._moves.slice(0, 5));
        this.reset();
    }

    // Reset to initial position (before first move)
    reset() {
        this.pause();
        this._currentIndex = 0;

        const grid = Array(this._baseSize).fill().map(() => Array(this._baseSize).fill(null));

        // Apply base setup
        for (const {stone, x, y} of this._baseSetup) {
            if (x < this._baseSize && y < this._baseSize) {
                grid[y][x] = stone;
            }
        }

        this._board = new BoardSnapshot(this._baseSize, grid);
        this._lastMove = null;
        this._capturedStones = { black: [], white: [] };

        this.dispatchEvent(new CustomEvent('boardChanged', { detail: this._board }));
        this.dispatchEvent(new CustomEvent('indexChanged', { detail: this._currentIndex }));
    }

    // Playback controls
    togglePlay() {
        this._isPlaying ? this.pause() : this.play();
    }

    play() {
        if (this._isPlaying) return;

        this._isPlaying = true;
        this.dispatchEvent(new CustomEvent('playStateChanged', { detail: this._isPlaying }));

        this._timer = setInterval(() => {
            this.stepForward();
        }, this._playInterval * 1000);
    }

    pause() {
        this._isPlaying = false;
        if (this._timer) {
            clearInterval(this._timer);
            this._timer = null;
        }
        this.dispatchEvent(new CustomEvent('playStateChanged', { detail: this._isPlaying }));
    }

    stepForward() {
        if (this._currentIndex >= this._moves.length) {
            this.pause();
            this.dispatchEvent(new CustomEvent('gameFinished'));
            return;
        }

        this._applyMove(this._currentIndex);
        this._currentIndex++;
        this.dispatchEvent(new CustomEvent('indexChanged', { detail: this._currentIndex }));
    }

    stepBack() {
        if (this._currentIndex <= 0) return;

        // Recompute from the initial position (simple + robust)
        const target = this._currentIndex - 1;
        this.reset();

        if (target > 0) {
            for (let i = 0; i < target; i++) {
                this._applyMove(i);
            }
        }

        this._currentIndex = target;
        this.dispatchEvent(new CustomEvent('indexChanged', { detail: this._currentIndex }));
    }

    seek(idx) {
        const clamped = Math.max(0, Math.min(idx, this._moves.length));
        Logger.info(`Seeking to move ${idx}, clamped to ${clamped}, total moves: ${this._moves.length}`);

        this.reset();

        if (clamped > 0) {
            for (let i = 0; i < clamped; i++) {
                this._applyMove(i);
            }
        }

        this._currentIndex = clamped;
        this.dispatchEvent(new CustomEvent('indexChanged', { detail: this._currentIndex }));
    }

    // Apply a single move
    _applyMove(idx) {
        if (idx >= this._moves.length) return;

        const move = this._moves[idx];
        Logger.debug(`Applying move ${idx}: ${move.stone} at`, move.coord);

        if (!move.coord) {
            // Pass move
            this._lastMove = null;
            Logger.debug(`Move ${idx}: Pass by ${move.stone}`);
            return;
        }

        const { x, y } = move.coord;
        const stone = move.stone;

        // Validate move
        if (!this._board.isEmpty(x, y)) {
            Logger.warning(`Move ${idx}: Position (${x},${y}) not empty`);
            return;
        }

        // Create new board state
        const newBoard = this._board.clone();
        newBoard.setStone(x, y, stone);

        // Handle captures
        const captures = newBoard.findCaptures(x, y, stone);
        const opponentColor = stone === Stone.BLACK ? Stone.WHITE : Stone.BLACK;

        for (const capture of captures) {
            newBoard.setStone(capture.x, capture.y, null);

            // Track captured stones
            if (stone === Stone.BLACK) {
                this._capturedStones.white.push(capture);
            } else {
                this._capturedStones.black.push(capture);
            }
        }

        this._board = newBoard;
        this._lastMove = new MoveRef(stone, x, y);

        Logger.debug(`Move ${idx}: ${stone} at (${x},${y}), captured ${captures.length} stones`);

        this.dispatchEvent(new CustomEvent('boardChanged', { detail: this._board }));
        this.dispatchEvent(new CustomEvent('moveApplied', {
            detail: { move, captures, lastMove: this._lastMove }
        }));
    }

    // Live game functionality (for OGS integration)

    /**
     * Make a move in a live game
     */
    makeMove(x, y) {
        const stone = this.getCurrentPlayer();

        // Validate move
        if (!this._board.isEmpty(x, y)) {
            Logger.warning(`Cannot place stone at (${x},${y}) - position occupied`);
            return false;
        }

        if (this._board.isSuicide(x, y, stone)) {
            Logger.warning(`Cannot place stone at (${x},${y}) - suicide move`);
            return false;
        }

        // Apply move immediately for live play
        const newBoard = this._board.clone();
        newBoard.setStone(x, y, stone);

        // Handle captures
        const captures = newBoard.findCaptures(x, y, stone);
        for (const capture of captures) {
            newBoard.setStone(capture.x, capture.y, null);
        }

        this._board = newBoard;
        this._lastMove = new MoveRef(stone, x, y);

        this.dispatchEvent(new CustomEvent('boardChanged', { detail: this._board }));
        this.dispatchEvent(new CustomEvent('liveMove', {
            detail: { stone, x, y, captures }
        }));

        Logger.info(`Live move: ${stone} at (${x},${y}), captured ${captures.length} stones`);
        return true;
    }

    /**
     * Get current player (alternates based on move count)
     */
    getCurrentPlayer() {
        const moveCount = this._moves.length;
        return moveCount % 2 === 0 ? Stone.BLACK : Stone.WHITE;
    }

    /**
     * Pass in a live game
     */
    pass() {
        const stone = this.getCurrentPlayer();
        this._lastMove = null;

        this.dispatchEvent(new CustomEvent('liveMove', {
            detail: { stone, pass: true }
        }));

        Logger.info(`Live pass: ${stone}`);
    }

    /**
     * Set board state from OGS game data
     */
    setBoardFromOGS(ogsGameData) {
        const { width, height, board } = ogsGameData;

        this._baseSize = width;
        const grid = Array(height).fill().map(() => Array(width).fill(null));

        // Parse OGS board format
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                const idx = y * width + x;
                const value = board[idx];

                if (value === 1) grid[y][x] = Stone.BLACK;
                else if (value === 2) grid[y][x] = Stone.WHITE;
            }
        }

        this._board = new BoardSnapshot(this._baseSize, grid);
        this.dispatchEvent(new CustomEvent('boardChanged', { detail: this._board }));

        Logger.info(`Board set from OGS: ${width}x${height}`);
    }
}

// Export for web usage
window.SGFPlayerEngine = SGFPlayerEngine;
window.BoardSnapshot = BoardSnapshot;
window.MoveRef = MoveRef;