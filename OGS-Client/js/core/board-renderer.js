/**
 * Board Renderer - Adapted from SGFPlayer SimpleBoardView.swift
 * Beautiful Go board rendering with stones, bowls, and jitter effects
 */

class BoardRenderer {
    constructor(canvas, options = {}) {
        console.log('BoardRenderer constructor called');
        console.log('Canvas element:', canvas);
        console.log('Canvas tagName:', canvas?.tagName);
        console.log('Canvas id:', canvas?.id);

        if (!canvas) {
            throw new Error('BoardRenderer: Canvas element is required');
        }

        this.canvas = canvas;

        console.log('Trying to get 2D context...');
        try {
            this.ctx = canvas.getContext('2d');
            console.log('2D context obtained:', this.ctx);
        } catch (error) {
            console.error('Failed to get 2D context:', error);
            throw error;
        }

        this.engine = null;

        // Configuration
        this.boardSize = options.boardSize || 19;
        this.cellRatio = 15.0 / 14.0; // Traditional Go board ratio
        this.jitterMultiplier = options.jitterMultiplier || 0.3;

        // State
        this.stones = new Map(); // position -> {stone, element, jitter}
        // Bowl stone management with SGFPlayer-style UUID tracking
        this.bowlStones = { black: [], white: [] };
        // Track individual stone positions by UUID like SGFPlayer - each stone maintains its position
        this.stoneLayout = { black: new Map(), white: new Map() };
        // Track next stone ID for each color
        this.nextStoneId = { black: 0, white: 0 };
        this.hoverPreview = null;
        this.currentPlayer = Stone.BLACK;

        // Elements
        this.bowlOverlay = null;
        this.blackBowl = null;
        this.whiteBowl = null;

        // Physics for jitter
        this.jitterCache = new Map();

        // Ko rule tracking
        this.boardHistory = [];
        this.koPosition = null;

        // Event handlers
        this.clickHandler = null;
        this.hoverHandler = null;

        // Asset images
        this.images = {
            boardTexture: null,
            blackStone: null,
            whiteStones: [], // Array of 5 clam variations
            bowlLids: [] // Array of 2 lid variations
        };
        this.imagesLoaded = false;

        this.setupCanvas();
        this.setupBowls();
        this.loadAssets();

        // Initial render with fallback graphics
        this.render();

        Logger.debug('BoardRenderer initialized');
    }

    setupCanvas() {
        console.log('setupCanvas() called');

        // Make canvas responsive
        console.log('Calling resizeCanvas...');
        this.resizeCanvas();
        window.addEventListener('resize', () => this.resizeCanvas());

        // Set up event listeners
        console.log('Setting up canvas event listeners...');
        this.canvas.addEventListener('click', (e) => this.handleClick(e));
        this.canvas.addEventListener('mousemove', (e) => this.handleMouseMove(e));
        this.canvas.addEventListener('mouseleave', () => this.clearHoverPreview());

        console.log('setupCanvas() completed');
    }

    setupBowls() {
        console.log('setupBowls() called');

        const container = this.canvas.parentElement;
        console.log('Canvas parent element:', container);
        console.log('Container className:', container?.className);

        if (!container) {
            console.error('No canvas parent container found for bowls!');
            return;
        }

        console.log('Setting up bowls in container:', container);

        // Create bowl overlay
        this.bowlOverlay = document.createElement('div');
        this.bowlOverlay.className = 'bowl-overlay';
        container.appendChild(this.bowlOverlay);

        // Create black bowl (upper left)
        this.blackBowl = document.createElement('div');
        this.blackBowl.className = 'bowl black-bowl';
        this.blackBowl.innerHTML = '<div class="bowl-stones"></div>';
        this.bowlOverlay.appendChild(this.blackBowl);

        // Create white bowl (lower right)
        this.whiteBowl = document.createElement('div');
        this.whiteBowl.className = 'bowl white-bowl';
        this.whiteBowl.innerHTML = '<div class="bowl-stones"></div>';
        this.bowlOverlay.appendChild(this.whiteBowl);

        console.log('Bowls created:', this.blackBowl, this.whiteBowl);
    }

    updateBowlImages() {
        // Update bowl backgrounds with loaded images if available
        if (this.images.bowlLids.length > 0 && this.imagesLoaded) {
            if (this.images.bowlLids[0] && this.blackBowl) {
                this.blackBowl.style.backgroundImage = `url('${this.images.bowlLids[0].src}')`;
            }
            if (this.images.bowlLids[1] && this.whiteBowl) {
                this.whiteBowl.style.backgroundImage = `url('${this.images.bowlLids[1].src}')`;
            }
        }
    }

    resizeCanvas() {
        const container = this.canvas.parentElement;
        if (!container) {
            console.log('No canvas parent container found!');
            return;
        }

        const containerRect = container.getBoundingClientRect();

        // Debug logging
        console.log('Container dimensions:', containerRect.width, 'x', containerRect.height);

        // More aggressive sizing - use more of available space
        const availableWidth = Math.max(containerRect.width - 300, 400); // Account for sidebar, minimum space
        const availableHeight = Math.max(containerRect.height - 100, 400); // Account for padding, minimum space

        const size = Math.min(
            availableWidth * 0.85, // Use 85% of available width
            availableHeight * 0.9 // Use 90% of available height
            // Removed maximum size cap to allow unlimited scaling
        );

        console.log('Calculated board size:', size);

        this.canvas.width = size;
        this.canvas.height = size;
        this.canvas.style.width = `${size}px`;
        this.canvas.style.height = `${size}px`;

        // Update class for responsive styling
        this.canvas.className = `go-board board-${this.boardSize}x${this.boardSize}`;

        // Position bowls relative to canvas
        this.positionBowls();
        // Only clear layout cache if bowl dimensions have changed by more than 50px
        // This preserves stone stability like SGFPlayer - very conservative threshold
        const newBowlSize = Math.max(Math.max(this.canvas.width, this.canvas.height) / 3, 80);
        if (Math.abs(newBowlSize - (this.lastBowlSize || 0)) > 50) {
            console.log('Bowl size changed significantly, clearing layout cache');
            this.stoneLayout.white.clear();
            this.stoneLayout.black.clear();
            this.lastBowlSize = newBowlSize;
        }
        this.renderBowlStones();

        this.render();
    }

    positionBowls() {
        if (!this.blackBowl || !this.whiteBowl) {
            console.log('Bowls not created yet!');
            return;
        }

        const canvasRect = this.canvas.getBoundingClientRect();
        const containerRect = this.canvas.parentElement.getBoundingClientRect();

        console.log('Canvas rect:', canvasRect);
        console.log('Container rect:', containerRect);

        // Position relative to canvas, not window
        const canvasX = canvasRect.left - containerRect.left;
        const canvasY = canvasRect.top - containerRect.top;

        // Scale bowl size to be proportional to board - 1/3 of board long side as requested
        const boardSize = Math.min(canvasRect.width, canvasRect.height);
        const bowlSize = Math.max(boardSize / 3, 80); // Minimum 80px, 1/3 of board size
        const bowlRadius = bowlSize / 2;

        console.log('Board size:', boardSize, 'Bowl size:', bowlSize);

        // Update bowl sizes
        this.blackBowl.style.width = `${bowlSize}px`;
        this.blackBowl.style.height = `${bowlSize}px`;
        this.whiteBowl.style.width = `${bowlSize}px`;
        this.whiteBowl.style.height = `${bowlSize}px`;

        // Position bowls relative to board size and position
        const bowlOffset = boardSize * 0.05; // 5% of board size as offset from edges

        // Black bowl (positioned in upper left, offset from board)
        this.blackBowl.style.position = 'absolute';
        this.blackBowl.style.left = `${canvasX - bowlSize - bowlOffset}px`;
        this.blackBowl.style.top = `${canvasY + bowlOffset}px`;

        // White bowl (positioned in lower right, offset from board)
        this.whiteBowl.style.position = 'absolute';
        this.whiteBowl.style.left = `${canvasX + canvasRect.width + bowlOffset}px`;
        this.whiteBowl.style.top = `${canvasY + canvasRect.height - bowlSize - bowlOffset}px`;

        // Update bowl stone container sizes to match new bowl size
        const blackBowlStones = this.blackBowl.querySelector('.bowl-stones');
        const whiteBowlStones = this.whiteBowl.querySelector('.bowl-stones');
        if (blackBowlStones) {
            blackBowlStones.style.width = `${bowlSize - 30}px`;
            blackBowlStones.style.height = `${bowlSize - 30}px`;
        }
        if (whiteBowlStones) {
            whiteBowlStones.style.width = `${bowlSize - 30}px`;
            whiteBowlStones.style.height = `${bowlSize - 30}px`;
        }
    }

    setEngine(engine) {
        this.engine = engine;

        // Listen for board changes
        engine.addEventListener('boardChanged', (e) => {
            this.updateBoard(e.detail);
        });

        engine.addEventListener('moveApplied', (e) => {
            this.handleMoveApplied(e.detail);
        });

        engine.addEventListener('liveMove', (e) => {
            this.handleLiveMove(e.detail);
        });
    }

    updateBoard(board) {
        this.stones.clear();
        this.jitterCache.clear();

        // Add stones from board
        for (let y = 0; y < board.size; y++) {
            for (let x = 0; x < board.size; x++) {
                const stone = board.getStone(x, y);
                if (stone) {
                    this.stones.set(`${x},${y}`, {
                        stone,
                        x,
                        y,
                        jitter: this.calculateJitter(x, y, board)
                    });
                }
            }
        }

        this.render();
    }

    handleMoveApplied(detail) {
        const { captures, lastMove } = detail;

        // Update captured stones in bowls
        if (captures.length > 0) {
            this.updateBowlStones(captures);
        }

        // Highlight last move
        if (lastMove) {
            this.highlightLastMove(lastMove);
        }
    }

    handleLiveMove(detail) {
        const { stone, x, y, captures, pass } = detail;

        if (pass) {
            this.clearLastMoveHighlight();
            return;
        }

        // Add stone with animation
        this.addStoneWithAnimation(x, y, stone);

        // Handle captures
        if (captures && captures.length > 0) {
            this.animateCaptures(captures);
            this.updateBowlStones(captures);
        }

        // Update board history for Ko tracking
        this.updateBoardHistory();

        // Clear Ko position after successful move
        this.koPosition = null;
    }

    render() {
        console.log('BoardRenderer render() called, canvas size:', this.canvas.width, 'x', this.canvas.height);
        console.log('Canvas context:', this.ctx);

        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

        this.drawBoard();
        this.drawGrid();
        this.drawHoshiPoints();
        this.drawStones();
        this.drawCoordinates();
        this.drawKoMarker();

        if (this.hoverPreview) {
            this.drawHoverPreview();
        }

        // Bowl stones only re-render when stones are captured, not on every cursor movement

        console.log('BoardRenderer render() completed');
    }

    drawBoard() {
        const ctx = this.ctx;
        const size = this.canvas.width;

        console.log('Drawing board, size:', size, 'imagesLoaded:', this.imagesLoaded);

        // Calculate proper border width (1.5 cell widths for larger kaya border)
        const gridSize = this.boardSize;
        // Total space = border + grid + border
        // grid = (gridSize - 1) cells between grid lines
        // We want borderWidth = 1.5 * cellWidth, so:
        // size = 1.5*cellWidth + (gridSize - 1) * cellWidth + 1.5*cellWidth = (gridSize + 2) * cellWidth
        const cellWidth = size / (gridSize + 2);
        const borderWidth = 1.5 * cellWidth; // Border width = 1.5 cell width for larger kaya border

        if (this.images.boardTexture && this.imagesLoaded) {
            // Use kaya wood texture for ENTIRE canvas - no separate border
            ctx.drawImage(this.images.boardTexture, 0, 0, size, size);
        } else {
            // Fallback: Draw wooden texture for entire canvas
            this.drawWoodBoard(ctx, size, 0); // No border offset - cover entire canvas
        }
    }

    drawWoodenBorder(ctx, size, borderWidth = 30) {

        // Outer wooden border (lighter colors)
        const gradient = ctx.createLinearGradient(0, 0, size, size);
        gradient.addColorStop(0, '#D2B48C');
        gradient.addColorStop(0.3, '#DEB887');
        gradient.addColorStop(0.7, '#CD853F');
        gradient.addColorStop(1, '#D2B48C');

        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, size, size);

        // Wood grain effect on border
        ctx.save();
        ctx.globalAlpha = 0.3;
        for (let i = 0; i < 15; i++) {
            ctx.strokeStyle = '#4a2c17';
            ctx.lineWidth = Math.random() * 1.5 + 0.5;
            ctx.beginPath();
            ctx.moveTo(Math.random() * size, 0);
            ctx.lineTo(Math.random() * size, size);
            ctx.stroke();
        }
        ctx.restore();
    }

    drawWoodBoard(ctx, size, borderWidth = 30) {
        const boardSize = size - 2 * borderWidth;

        // Board wood texture
        const gradient = ctx.createRadialGradient(
            size * 0.3, size * 0.3, 0,
            size * 0.5, size * 0.5, boardSize * 0.6
        );
        gradient.addColorStop(0, '#deb887');
        gradient.addColorStop(1, '#d2b48c');

        ctx.fillStyle = gradient;
        ctx.fillRect(borderWidth, borderWidth, boardSize, boardSize);

        // Add subtle wood grain
        ctx.save();
        ctx.globalAlpha = 0.1;
        for (let i = 0; i < 12; i++) {
            ctx.strokeStyle = '#8b4513';
            ctx.lineWidth = Math.random() * 1;
            ctx.beginPath();
            ctx.moveTo(borderWidth, borderWidth + Math.random() * boardSize);
            ctx.lineTo(borderWidth + boardSize, borderWidth + Math.random() * boardSize);
            ctx.stroke();
        }
        ctx.restore();
    }

    drawGrid() {
        const ctx = this.ctx;
        const size = this.canvas.width;
        const gridSize = this.boardSize;

        // Calculate proper border width (same as used in drawBoard)
        const calculatedCellWidth = size / (gridSize + 1);
        const borderWidth = calculatedCellWidth; // Border width = 1 cell width

        // Grid should fit within the wooden board area, with padding for coordinates
        const woodBoardSize = size - 2 * borderWidth; // Available wood board area
        const gridMargin = borderWidth * 0.5; // Margin within the wood board for grid (half cell width)
        const gridAreaSize = woodBoardSize - 2 * gridMargin;

        const cellWidth = gridAreaSize / (gridSize - 1);
        const cellHeight = gridAreaSize / (gridSize - 1);

        // Grid starts at wooden border + grid margin
        const offsetX = borderWidth + gridMargin;
        const offsetY = borderWidth + gridMargin;

        // Store for coordinate calculations
        this.gridInfo = {
            offsetX,
            offsetY,
            cellWidth,
            cellHeight,
            gridSize
        };

        ctx.strokeStyle = '#000';
        ctx.lineWidth = 1;

        // Vertical lines
        for (let i = 0; i < gridSize; i++) {
            const x = offsetX + i * cellWidth;
            ctx.beginPath();
            ctx.moveTo(x, offsetY);
            ctx.lineTo(x, offsetY + gridAreaSize);
            ctx.stroke();
        }

        // Horizontal lines
        for (let j = 0; j < gridSize; j++) {
            const y = offsetY + j * cellHeight;
            ctx.beginPath();
            ctx.moveTo(offsetX, y);
            ctx.lineTo(offsetX + gridAreaSize, y);
            ctx.stroke();
        }
    }

    drawHoshiPoints() {
        if (!this.gridInfo) return;

        const ctx = this.ctx;
        const { offsetX, offsetY, cellWidth, cellHeight } = this.gridInfo;

        // Standard 19x19 hoshi points
        const hoshiPoints = this.boardSize === 19 ?
            [[3, 3], [3, 9], [3, 15], [9, 3], [9, 9], [9, 15], [15, 3], [15, 9], [15, 15]] :
            this.boardSize === 13 ?
            [[3, 3], [3, 9], [6, 6], [9, 3], [9, 9]] :
            [[2, 2], [2, 6], [4, 4], [6, 2], [6, 6]]; // 9x9

        ctx.fillStyle = '#000';
        for (const [x, y] of hoshiPoints) {
            const px = offsetX + x * cellWidth;
            const py = offsetY + y * cellHeight;

            ctx.beginPath();
            ctx.arc(px, py, 3, 0, 2 * Math.PI);
            ctx.fill();
        }
    }

    drawStones() {
        if (!this.gridInfo) return;

        const { offsetX, offsetY, cellWidth, cellHeight } = this.gridInfo;

        for (const stoneData of this.stones.values()) {
            const { stone, x, y, jitter } = stoneData;

            // Calculate position with jitter
            const px = offsetX + x * cellWidth + (jitter.x || 0);
            const py = offsetY + y * cellHeight + (jitter.y || 0);

            this.drawStone(px, py, stone, false);
        }
    }

    drawStone(x, y, stone, isPreview = false) {
        const ctx = this.ctx;
        const radius = this.gridInfo.cellWidth * 0.48; // Slightly bigger stones
        const diameter = radius * 2;

        ctx.save();

        if (isPreview) {
            ctx.globalAlpha = 0.6;
        }

        // Add shadow
        ctx.shadowColor = 'rgba(0, 0, 0, 0.6)';
        ctx.shadowBlur = 8;
        ctx.shadowOffsetX = 3;
        ctx.shadowOffsetY = 3;

        if (stone === Stone.BLACK && this.images.blackStone && this.imagesLoaded) {
            // Use actual black stone image
            ctx.drawImage(
                this.images.blackStone,
                x - radius, y - radius,
                diameter, diameter
            );
        } else if (stone === Stone.WHITE && this.images.whiteStones.length > 0 && this.imagesLoaded) {
            // Use random clam shell for white stone variation
            const stoneKey = `${Math.floor(x) + Math.floor(y) * 1000}`;
            const stoneIndex = this.getWhiteStoneVariation(stoneKey);
            const whiteStoneImage = this.images.whiteStones[stoneIndex];

            if (whiteStoneImage) {
                ctx.drawImage(
                    whiteStoneImage,
                    x - radius, y - radius,
                    diameter, diameter
                );
            } else {
                this.drawStoneFallback(ctx, x, y, stone, radius);
            }
        } else {
            this.drawStoneFallback(ctx, x, y, stone, radius);
        }

        ctx.restore();
    }

    drawStoneFallback(ctx, x, y, stone, radius) {
        // Fallback to gradient stones
        if (stone === Stone.BLACK) {
            const gradient = ctx.createRadialGradient(
                x - radius * 0.3, y - radius * 0.3, 0,
                x, y, radius
            );
            gradient.addColorStop(0, '#333');
            gradient.addColorStop(1, '#000');
            ctx.fillStyle = gradient;
        } else {
            const gradient = ctx.createRadialGradient(
                x - radius * 0.3, y - radius * 0.3, 0,
                x, y, radius
            );
            gradient.addColorStop(0, '#fff');
            gradient.addColorStop(1, '#e8e8e8');
            ctx.fillStyle = gradient;
            ctx.strokeStyle = '#ccc';
            ctx.lineWidth = 1;
        }

        ctx.beginPath();
        ctx.arc(x, y, radius, 0, 2 * Math.PI);
        ctx.fill();

        if (stone === Stone.WHITE) {
            ctx.shadowColor = 'transparent';
            ctx.stroke();
        }
    }

    getWhiteStoneVariation(stoneKey) {
        // Consistent variation selection based on position
        const hash = stoneKey.split('').reduce((a, b) => {
            a = ((a << 5) - a) + b.charCodeAt(0);
            return a & a;
        }, 0);
        return Math.abs(hash) % this.images.whiteStones.length;
    }

    drawCoordinates() {
        if (!this.gridInfo) return;

        const ctx = this.ctx;
        const { offsetX, offsetY, cellWidth, cellHeight, gridSize } = this.gridInfo;

        // Clear any shadow effects that might interfere
        ctx.shadowColor = 'transparent';
        ctx.shadowBlur = 0;
        ctx.shadowOffsetX = 0;
        ctx.shadowOffsetY = 0;

        // Calculate proper border width (same as used in drawBoard)
        const canvasSize = this.canvas.width;
        const calculatedCellWidth = canvasSize / (gridSize + 2);
        const borderWidth = 1.5 * calculatedCellWidth;

        // Font size = 1/2 cell height
        const fontSize = Math.max(cellHeight * 0.5, 8); // Minimum 8px for readability

        ctx.font = `${fontSize}px Arial`;
        ctx.fillStyle = '#000'; // Black text as requested
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';

        // Letters (A-T, skipping I) - horizontal coordinates
        const letters = 'ABCDEFGHJKLMNOPQRST';
        for (let i = 0; i < gridSize; i++) {
            const x = offsetX + i * cellWidth;

            // Top coordinates (within wooden border)
            ctx.fillText(letters[i], x, borderWidth / 2);

            // Bottom coordinates (within wooden border)
            ctx.fillText(letters[i], x, canvasSize - borderWidth / 2);
        }

        // Numbers (1-19 from bottom to top) - vertical coordinates
        for (let j = 0; j < gridSize; j++) {
            const y = offsetY + j * cellHeight;
            const num = gridSize - j; // Bottom-left origin: 19 at top, 1 at bottom

            // Left coordinates (within wooden border)
            ctx.fillText(num.toString(), borderWidth / 2, y);

            // Right coordinates (within wooden border)
            ctx.fillText(num.toString(), canvasSize - borderWidth / 2, y);
        }
    }

    drawHoverPreview() {
        if (!this.hoverPreview || !this.gridInfo) return;

        const { x, y, stone } = this.hoverPreview;
        const { offsetX, offsetY, cellWidth, cellHeight } = this.gridInfo;

        const px = offsetX + x * cellWidth;
        const py = offsetY + y * cellHeight;

        this.drawStone(px, py, stone, true);
    }

    // SGF Player Bowl Physics Implementation
    // SGF Player Bowl Physics - Complete Port
    // Deterministic RNG based on SGF Player's PCG64
    createPCG64(seed) {
        return {
            state: seed === 0 ? 1 : seed,
            nextRaw() {
                // Simple LCG with safe operations - same as SimpleRNG
                this.state = ((this.state * 1103515245) + 12345) & 0xFFFFFFFF;
                return (this.state >>> 16) & 0x7FFFFFFF;
            },
            nextUnit() {
                return this.nextRaw() / 0x7FFFFFFF;
            }
        };
    }

    // Calculate all bowl stone positions using SGF Player's exact algorithm
    calculateBowlPhysicsPositions(stoneCount, seed, bowlCenter, stoneSize) {
        console.log('calculateBowlPhysicsPositions called with:', { stoneCount, seed, bowlCenter, stoneSize });

        if (stoneCount === 0) return [];

        const centerPull = 0.045;   // base pull per iteration toward center (from SGFPlayer)
        const repel = 0.70;         // strength of pairwise push (from SGFPlayer)
        const iterations = 14;      // SGF Player uses 14 iterations

        try {
            // Deterministic RNG
            const rng = this.createPCG64(seed);

            // Start from jittered points inside unit circle, less center bias for better distribution
            const points = [];
            for (let i = 0; i < stoneCount; i++) {
                const t = rng.nextUnit();
                const r = 0.75 * Math.sqrt(rng.nextUnit());  // reduced from 0.85, more center bias (from SGFPlayer)
                const a = 2 * Math.PI * t;
                points.push({
                    x: r * Math.cos(a),
                    y: r * Math.sin(a)
                });
            }

            console.log('Initial points:', points.slice(0, 3)); // Log first 3 points

            // Advanced relaxation with adaptive physics
            for (let iteration = 0; iteration < iterations; iteration++) {
                // Gentle center pull - only for stones getting too far out
                for (let i = 0; i < points.length; i++) {
                    const currentR = Math.sqrt(points[i].x * points[i].x + points[i].y * points[i].y);

                    // Only apply pull if stone is getting far from center
                    if (currentR > 0.4) {
                        const distanceFactor = (currentR - 0.4) * 1.5;  // gradual increase
                        const adaptivePull = centerPull * distanceFactor;
                        points[i].x *= (1 - adaptivePull);
                        points[i].y *= (1 - adaptivePull);
                    }
                }

                // Natural repulsion - only when stones are too close
                for (let i = 0; i < points.length; i++) {
                    for (let j = i + 1; j < points.length; j++) {
                        const dx = points[j].x - points[i].x;
                        const dy = points[j].y - points[i].y;
                        const d2 = dx * dx + dy * dy + 1e-6;
                        const d = Math.sqrt(d2);

                        // Only repel if stones are overlapping or very close
                        const comfortableDistance = 0.12;
                        if (d < comfortableDistance) {
                            const overlap = comfortableDistance - d;
                            const push = repel * overlap * 0.5;  // gentle push
                            const ux = dx / Math.max(d, 0.001);
                            const uy = dy / Math.max(d, 0.001);
                            points[i].x -= ux * push * 0.5;
                            points[i].y -= uy * push * 0.5;
                            points[j].x += ux * push * 0.5;
                            points[j].y += uy * push * 0.5;
                        }
                    }
                }

                // Soft wall with stronger edge repulsion
                for (let i = 0; i < points.length; i++) {
                    const r = Math.sqrt(points[i].x * points[i].x + points[i].y * points[i].y);
                    const maxR = 0.85;  // tighter boundary

                    if (r > maxR) {
                        // Strong pushback from edge
                        const overshoot = r - maxR;
                        const pushbackStrength = Math.min(0.3, overshoot * 2.0);  // strong correction
                        const normalizedX = points[i].x / r;
                        const normalizedY = points[i].y / r;

                        points[i].x = normalizedX * (maxR - pushbackStrength * overshoot);
                        points[i].y = normalizedY * (maxR - pushbackStrength * overshoot);
                    } else if (r > 0.75) {
                        // Gentle inward nudge for stones approaching edge
                        const edgeFactor = (r - 0.75) / (maxR - 0.75);  // 0 to 1 as approaching edge
                        const inwardPull = centerPull * 2.0 * edgeFactor;
                        points[i].x *= (1 - inwardPull);
                        points[i].y *= (1 - inwardPull);
                    }
                }
            }

            // Convert from unit circle to relative coordinates (center = 0,0)
            // Return positions relative to center, not absolute coordinates
            // Keep stones well within the bowl - use 30% of bowl radius for a tight fit
            const physicsRadius = bowlCenter * 0.3;
            const rotationRng = this.createPCG64(seed + 1000); // Different seed for rotation

            const result = points.map(point => {
                const relativeX = point.x * physicsRadius; // Relative to center
                const relativeY = point.y * physicsRadius; // Relative to center
                const rotation = (rotationRng.nextUnit() - 0.5) * 20;

                return {
                    x: relativeX,
                    y: relativeY,
                    rotation: rotation
                };
            });

            return result;

        } catch (error) {
            console.error('Error in calculateBowlPhysicsPositions:', error);
            // Fallback to simple positioning
            return Array.from({length: stoneCount}, (_, i) => ({
                x: bowlCenter - stoneSize/2 + (Math.random() - 0.5) * bowlCenter,
                y: bowlCenter - stoneSize/2 + (Math.random() - 0.5) * bowlCenter,
                rotation: (Math.random() - 0.5) * 20
            }));
        }
    }

    // Event handling
    handleClick(e) {
        const coord = this.getCoordinateFromEvent(e);
        if (!coord) return;

        if (this.clickHandler) {
            this.clickHandler(coord.x, coord.y);
        }
    }

    handleMouseMove(e) {
        const coord = this.getCoordinateFromEvent(e);
        if (!coord) {
            this.clearHoverPreview();
            return;
        }

        // Show preview if position is empty
        if (this.engine && this.engine.board.isEmpty(coord.x, coord.y)) {
            // Check for Ko violation
            if (this.checkKoViolation(coord.x, coord.y, this.currentPlayer)) {
                // Don't show hover preview for Ko positions
                this.clearHoverPreview();
            } else {
                this.hoverPreview = {
                    x: coord.x,
                    y: coord.y,
                    stone: this.currentPlayer
                };
            }
            this.render();
        } else {
            this.clearHoverPreview();
        }

        if (this.hoverHandler) {
            this.hoverHandler(coord.x, coord.y);
        }
    }

    clearHoverPreview() {
        if (this.hoverPreview) {
            this.hoverPreview = null;
            this.render();
        }
    }

    getCoordinateFromEvent(e) {
        if (!this.gridInfo) return null;

        const rect = this.canvas.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;

        const { offsetX, offsetY, cellWidth, cellHeight, gridSize } = this.gridInfo;

        // Convert to grid coordinates
        const gridX = Math.round((x - offsetX) / cellWidth);
        const gridY = Math.round((y - offsetY) / cellHeight);

        if (gridX < 0 || gridX >= gridSize || gridY < 0 || gridY >= gridSize) {
            return null;
        }

        return { x: gridX, y: gridY };
    }

    // Jitter calculation (simplified from SGFPlayer)
    calculateJitter(x, y, board) {
        if (this.jitterMultiplier <= 0) return { x: 0, y: 0 };

        const key = `${x},${y}`;
        if (this.jitterCache.has(key)) {
            return this.jitterCache.get(key);
        }

        // Simple pseudo-random jitter based on position
        const seed = x * 31 + y * 17;
        const random = (seed * 9301 + 49297) % 233280 / 233280;

        const maxJitter = this.gridInfo.cellWidth * 0.15 * this.jitterMultiplier;
        const jitter = {
            x: (random * 2 - 1) * maxJitter,
            y: ((random * 13) % 1 * 2 - 1) * maxJitter
        };

        this.jitterCache.set(key, jitter);
        return jitter;
    }

    // Animation methods
    addStoneWithAnimation(x, y, stone) {
        const stoneData = {
            stone,
            x,
            y,
            jitter: this.calculateJitter(x, y, this.engine.board)
        };

        this.stones.set(`${x},${y}`, stoneData);

        // Animate stone placement
        const { offsetX, offsetY, cellWidth, cellHeight } = this.gridInfo;
        const px = offsetX + x * cellWidth;
        const py = offsetY + y * cellHeight;

        // Create temporary DOM element for animation
        const stoneEl = document.createElement('div');
        stoneEl.className = `board-stone ${stone} placing`;
        stoneEl.style.left = `${px - cellWidth * 0.45}px`;
        stoneEl.style.top = `${py - cellWidth * 0.45}px`;
        stoneEl.style.width = `${cellWidth * 0.9}px`;
        stoneEl.style.height = `${cellWidth * 0.9}px`;

        this.canvas.parentElement.appendChild(stoneEl);

        // Remove after animation
        setTimeout(() => {
            if (stoneEl.parentElement) {
                stoneEl.parentElement.removeChild(stoneEl);
            }
            this.render();
        }, 300);
    }

    animateCaptures(captures) {
        // Remove captured stones with animation
        for (const capture of captures) {
            this.stones.delete(`${capture.x},${capture.y}`);
        }

        // Render immediately to show captures
        this.render();
    }

    updateBowlStones(captures) {
        // Add captured stones with unique IDs - SGFPlayer approach
        let newWhiteStones = [];
        let newBlackStones = [];

        for (const capture of captures) {
            if (capture.stone === Stone.BLACK) {
                // Black stone captured goes to white bowl
                const stoneId = `white_${this.nextStoneId.white++}`;
                const stoneData = {
                    id: stoneId,
                    originalCapture: capture
                };
                this.bowlStones.white.push(stoneData);
                newWhiteStones.push(stoneData);
            } else {
                // White stone captured goes to black bowl
                const stoneId = `black_${this.nextStoneId.black++}`;
                const stoneData = {
                    id: stoneId,
                    originalCapture: capture
                };
                this.bowlStones.black.push(stoneData);
                newBlackStones.push(stoneData);
            }
        }

        // Only calculate positions for NEW stones while preserving existing positions
        if (newWhiteStones.length > 0) {
            this.addStonesToBowl('white', newWhiteStones);
        }
        if (newBlackStones.length > 0) {
            this.addStonesToBowl('black', newBlackStones);
        }

        // Re-render affected bowls
        this.renderBowlStones();
    }

    // Add new stones to a bowl while preserving existing stone positions
    addStonesToBowl(color, newStones) {
        if (newStones.length === 0) return;

        const bowlSize = Math.max(Math.max(this.canvas.width, this.canvas.height) / 3, 80);
        const bowlRadius = bowlSize * 0.46; // Conservative inner radius like SGFPlayer
        const boardStoneRadius = this.gridInfo.cellWidth * 0.48;

        // Get existing stone positions from layout map
        const existingLayout = this.stoneLayout[color];

        // SGFPlayer approach: only calculate positions for NEW stones
        // Use deterministic physics but place them to avoid existing stones
        const seed = color === 'white' ? 12345 : 54321;

        for (let i = 0; i < newStones.length; i++) {
            const stoneData = newStones[i];

            // Generate a position for this new stone using deterministic seed + more variation
            // Add more entropy to break systematic patterns
            const stoneSeed = seed + (existingLayout.size * 7919) + (i * 2531) + (seed % 1000);
            const position = this.generateSingleStonePosition(stoneSeed, bowlRadius, boardStoneRadius, existingLayout);

            existingLayout.set(stoneData.id, position);
        }
    }

    // Generate a single stone position using SGFPlayer-like physics with gradual degradation
    generateSingleStonePosition(seed, bowlRadius, stoneRadius, existingLayout) {
        // Use simple deterministic random generation like SGFPlayer
        let rng = seed;
        function nextFloat() {
            rng = (rng * 1664525 + 1013904223) % (2**32);
            return (rng / (2**32));
        }

        // SGFPlayer approach: gradually relax constraints rather than binary accept/reject
        const maxAttempts = 30;
        const idealDistance = stoneRadius * 2.4; // Ideal spacing
        const minimumDistance = stoneRadius * 1.2; // Minimum before significant overlap

        let bestPosition = null;
        let bestScore = -Infinity;

        for (let attempt = 0; attempt < maxAttempts; attempt++) {
            // Generate more varied positions - mix of radial distances and add some center bias
            let r, angle;

            if (nextFloat() < 0.4) {
                // 40% chance: prefer center area (more natural clustering)
                r = bowlRadius * 0.3 * Math.sqrt(nextFloat());
            } else if (nextFloat() < 0.7) {
                // 30% chance: middle ring
                r = bowlRadius * (0.25 + 0.25 * nextFloat());
            } else {
                // 30% chance: outer area
                r = bowlRadius * (0.45 + 0.2 * nextFloat());
            }

            // Add some variation to angle to break up systematic patterns
            angle = nextFloat() * 2 * Math.PI;
            // Add small random offset to break perfect circular patterns
            angle += (nextFloat() - 0.5) * 0.4; // ±0.2 radian variation

            const candidatePos = {
                x: Math.cos(angle) * r,
                y: Math.sin(angle) * r,
                rotation: nextFloat() * 360
            };

            // Score this position based on multiple factors (like SGFPlayer's energy minimization)
            let score = this.scoreStonePosition(candidatePos, existingLayout, bowlRadius, stoneRadius);

            if (score > bestScore) {
                bestScore = score;
                bestPosition = candidatePos;
            }

            // If we found a really good position, use it early
            if (score > 0.8) {
                break;
            }

            // Vary the seed for next attempt
            rng = (rng + 1000) % (2**32);
        }

        return bestPosition || {
            x: 0, y: 0, rotation: nextFloat() * 360
        };
    }

    // Score a stone position based on SGFPlayer-like physics
    scoreStonePosition(pos, existingLayout, bowlRadius, stoneRadius) {
        let score = 1.0; // Start with perfect score

        // Strong penalty for being too close to bowl edge (avoid overlapping the lip)
        const distanceFromCenter = Math.sqrt(pos.x * pos.x + pos.y * pos.y);
        const safeRadius = bowlRadius * 0.6; // Keep within 60% of bowl radius to stay clear of lip
        const warningRadius = bowlRadius * 0.7; // Start penalty at 70%

        if (distanceFromCenter > safeRadius) {
            if (distanceFromCenter > warningRadius) {
                // Heavy penalty for being near the lip
                const overflowRatio = (distanceFromCenter - warningRadius) / (bowlRadius * 0.3);
                score -= overflowRatio * 1.2; // Strong edge penalty
            } else {
                // Light penalty in warning zone
                const warningRatio = (distanceFromCenter - safeRadius) / (bowlRadius * 0.1);
                score -= warningRatio * 0.3;
            }
        }

        // Evaluate relationships with existing stones
        for (const existingPos of existingLayout.values()) {
            const dx = pos.x - existingPos.x;
            const dy = pos.y - existingPos.y;
            const distance = Math.sqrt(dx * dx + dy * dy);

            const idealDistance = stoneRadius * 2.2; // Comfortable spacing
            const minimumDistance = stoneRadius * 1.4; // Before major overlap
            const stackingDistance = stoneRadius * 0.8; // Complete stacking

            if (distance < stackingDistance) {
                // Heavy penalty for stacking (but not impossible)
                score -= 0.8;
            } else if (distance < minimumDistance) {
                // Strong penalty for significant overlap
                const overlapRatio = (minimumDistance - distance) / (minimumDistance - stackingDistance);
                score -= 0.6 * overlapRatio;
            } else if (distance < idealDistance) {
                // Light penalty for being closer than ideal
                const crowdingRatio = (idealDistance - distance) / (idealDistance - minimumDistance);
                score -= 0.2 * crowdingRatio;
            } else if (distance > idealDistance * 2.0) {
                // Very light penalty for being too far (encourages some clustering)
                const isolationRatio = Math.min(1.0, (distance - idealDistance * 2.0) / (idealDistance * 2.0));
                score -= 0.1 * isolationRatio;
            }
        }

        // Slight preference for positions that are not at exact center (natural variation)
        if (distanceFromCenter < stoneRadius) {
            score -= 0.1;
        }

        return Math.max(-2.0, score); // Cap minimum penalty
    }


    renderBowlStones() {
        if (!this.gridInfo) return;

        // Check if bowls are created yet
        if (!this.blackBowl || !this.whiteBowl) {
            console.log('Bowls not available yet, skipping renderBowlStones');
            return;
        }

        // Calculate stone size to match board stones (cellWidth * 0.48 * 2 for diameter)
        const boardStoneRadius = this.gridInfo.cellWidth * 0.48;
        const stoneSize = boardStoneRadius * 2;

        // Get current bowl dimensions
        const bowlSize = Math.max(Math.max(this.canvas.width, this.canvas.height) / 3, 80);
        const bowlCenter = bowlSize / 2; // Actual center of bowl

        // Render stones in black bowl (captured white stones) - SGFPlayer UUID approach
        const blackBowlStones = this.blackBowl.querySelector('.bowl-stones');
        blackBowlStones.innerHTML = '';

        if (this.bowlStones.white.length > 0) {
            // If no positions cached yet, calculate initial positions for all stones
            // This should only happen on first load or resize
            if (this.stoneLayout.white.size === 0 && this.bowlStones.white.length > 0) {
                // Calculate initial positions for all existing stones (happens only once at start)
                const stonesWithoutPositions = this.bowlStones.white.filter(stone => !this.stoneLayout.white.has(stone.id));
                this.addStonesToBowl('white', stonesWithoutPositions);
            }

            // Render each stone using its persistent position from layout map
            this.bowlStones.white.forEach((stoneData, index) => {
                const stone = document.createElement('div');
                stone.className = 'bowl-stone white';

                // Set stone size to match board stones
                stone.style.width = `${stoneSize}px`;
                stone.style.height = `${stoneSize}px`;

                // Randomly select white stone variation (clam_01 through clam_05)
                // Use deterministic seed based on stone ID for consistency
                const stoneVariation = ((index * 7) % 5) + 1;
                stone.style.backgroundImage = `url('../assets/clam_${stoneVariation.toString().padStart(2, '0')}.png')`;

                // Get persistent position for this stone ID
                const position = this.stoneLayout.white.get(stoneData.id);
                if (position) {
                    // Convert from physics center-based coordinates to bowl-stones container coordinates
                    // .bowl-stones has 15px padding, so center is at (containerSize - 30px) / 2
                    const containerSize = bowlSize - 30; // Account for 15px padding on each side
                    const containerCenter = containerSize / 2;
                    const finalX = containerCenter + position.x - stoneSize/2;
                    const finalY = containerCenter + position.y - stoneSize/2;

                    stone.style.left = `${finalX}px`;
                    stone.style.top = `${finalY}px`;
                    stone.style.transform = `rotate(${position.rotation || 0}deg)`;
                } else {
                    // Fallback if no position found - center of container
                    const containerSize = bowlSize - 30;
                    const containerCenter = containerSize / 2;
                    stone.style.left = `${containerCenter - stoneSize/2}px`;
                    stone.style.top = `${containerCenter - stoneSize/2}px`;
                }

                blackBowlStones.appendChild(stone);
            });
        }

        // Render stones in white bowl (captured black stones) - SGFPlayer UUID approach
        const whiteBowlStones = this.whiteBowl.querySelector('.bowl-stones');
        whiteBowlStones.innerHTML = '';

        if (this.bowlStones.black.length > 0) {
            // If no positions cached yet, calculate initial positions for all stones
            // This should only happen on first load or resize
            if (this.stoneLayout.black.size === 0 && this.bowlStones.black.length > 0) {
                // Calculate initial positions for all existing stones (happens only once at start)
                const stonesWithoutPositions = this.bowlStones.black.filter(stone => !this.stoneLayout.black.has(stone.id));
                this.addStonesToBowl('black', stonesWithoutPositions);
            }

            // Render each stone using its persistent position from layout map
            this.bowlStones.black.forEach((stoneData, index) => {
                const stone = document.createElement('div');
                stone.className = 'bowl-stone black';

                // Set stone size to match board stones
                stone.style.width = `${stoneSize}px`;
                stone.style.height = `${stoneSize}px`;

                // Get persistent position for this stone ID
                const position = this.stoneLayout.black.get(stoneData.id);
                if (position) {
                    // Convert from physics center-based coordinates to bowl-stones container coordinates
                    // .bowl-stones has 15px padding, so center is at (containerSize - 30px) / 2
                    const containerSize = bowlSize - 30; // Account for 15px padding on each side
                    const containerCenter = containerSize / 2;
                    stone.style.left = `${containerCenter + position.x - stoneSize/2}px`;
                    stone.style.top = `${containerCenter + position.y - stoneSize/2}px`;
                    stone.style.transform = `rotate(${position.rotation || 0}deg)`;
                } else {
                    // Fallback if no position found - center of container
                    const containerSize = bowlSize - 30;
                    const containerCenter = containerSize / 2;
                    stone.style.left = `${containerCenter - stoneSize/2}px`;
                    stone.style.top = `${containerCenter - stoneSize/2}px`;
                }

                whiteBowlStones.appendChild(stone);
            });
        }
    }


    highlightLastMove(lastMove) {
        // Implementation for highlighting last move
        this.lastMoveHighlight = lastMove;
        this.render();
    }

    clearLastMoveHighlight() {
        this.lastMoveHighlight = null;
        this.render();
    }

    // Ko rule implementation
    getBoardStateHash() {
        // Create a hash of the current board state for Ko detection
        const positions = [];
        for (const [key, stoneData] of this.stones.entries()) {
            positions.push(`${key}:${stoneData.stone}`);
        }
        return positions.sort().join('|');
    }

    updateBoardHistory() {
        // Keep track of board states to detect Ko
        const currentHash = this.getBoardStateHash();
        this.boardHistory.push(currentHash);

        // Keep only last 3 states (current + 2 previous)
        if (this.boardHistory.length > 3) {
            this.boardHistory.shift();
        }
    }

    checkKoViolation(x, y, stone) {
        // Simplified Ko rule checking without capture simulation
        // For now, disable Ko rule until getCaptures is implemented in engine
        return false;

        // TODO: Implement proper Ko rule when engine has getCaptures method
        // The Ko rule prevents immediate recapture of a single stone
    }

    drawKoMarker() {
        if (!this.koPosition || !this.gridInfo) return;

        const { offsetX, offsetY, cellWidth, cellHeight } = this.gridInfo;
        const { x, y } = this.koPosition;

        const px = offsetX + x * cellWidth;
        const py = offsetY + y * cellHeight;

        const ctx = this.ctx;
        const size = cellWidth * 0.3; // Smaller than stones

        // Draw hollow black square
        ctx.save();
        ctx.strokeStyle = '#000';
        ctx.lineWidth = 2;
        ctx.fillStyle = 'transparent';

        ctx.beginPath();
        ctx.rect(px - size/2, py - size/2, size, size);
        ctx.stroke();
        ctx.restore();
    }

    // Public API
    setClickHandler(handler) {
        this.clickHandler = handler;
    }

    setCurrentPlayer(stone) {
        this.currentPlayer = stone;
    }

    setHoverHandler(handler) {
        this.hoverHandler = handler;
    }

    setBoardSize(size) {
        this.boardSize = size;
        this.stones.clear();
        this.jitterCache.clear();
        this.render();
    }

    setJitterMultiplier(multiplier) {
        this.jitterMultiplier = multiplier;
        this.jitterCache.clear();
        if (this.engine) {
            this.updateBoard(this.engine.board);
        }
    }

    loadAssets() {
        const assetPaths = {
            boardTexture: 'assets/board_kaya.jpg',
            blackStone: 'assets/stone_black.png',
            whiteStones: [
                'assets/clam_01.png',
                'assets/clam_02.png',
                'assets/clam_03.png',
                'assets/clam_04.png',
                'assets/clam_05.png'
            ],
            bowlLids: [
                'assets/go_lid_1.png',
                'assets/go_lid_2.png'
            ]
        };

        let loadedCount = 0;
        let totalImages = 1 + 1 + 5 + 2; // board + black stone + 5 white stones + 2 lids

        const onImageLoad = () => {
            loadedCount++;
            if (loadedCount === totalImages) {
                this.imagesLoaded = true;
                Logger.debug('All board assets loaded');
                this.updateBowlImages(); // Update bowl backgrounds
                this.render(); // Re-render with assets
            }
        };

        const onImageError = (path) => {
            Logger.warn(`Failed to load asset: ${path}`);
            loadedCount++;
            if (loadedCount === totalImages) {
                this.imagesLoaded = true;
                this.updateBowlImages();
                this.render();
            }
        };

        // Load board texture
        this.images.boardTexture = new Image();
        this.images.boardTexture.onload = onImageLoad;
        this.images.boardTexture.onerror = () => onImageError(assetPaths.boardTexture);
        this.images.boardTexture.src = assetPaths.boardTexture;

        // Load black stone
        this.images.blackStone = new Image();
        this.images.blackStone.onload = onImageLoad;
        this.images.blackStone.onerror = () => onImageError(assetPaths.blackStone);
        this.images.blackStone.src = assetPaths.blackStone;

        // Load white stone variations
        this.images.whiteStones = [];
        assetPaths.whiteStones.forEach((path, index) => {
            const img = new Image();
            img.onload = onImageLoad;
            img.onerror = () => onImageError(path);
            img.src = path;
            this.images.whiteStones[index] = img;
        });

        // Load bowl lids
        this.images.bowlLids = [];
        assetPaths.bowlLids.forEach((path, index) => {
            const img = new Image();
            img.onload = onImageLoad;
            img.onerror = () => onImageError(path);
            img.src = path;
            this.images.bowlLids[index] = img;
        });
    }
}

// Export for web usage
window.BoardRenderer = BoardRenderer;