/**
 * Main Application Controller
 * Coordinates all components and manages application state
 */

class AppController {
    constructor() {
        // Core components
        this.ogsClient = new OGSClient();
        this.gameEngine = new SGFPlayerEngine();
        this.meetIntegration = new GoogleMeetIntegration();

        // UI controllers
        this.lobbyController = null;
        this.gameController = null;

        // Application state
        this.currentView = 'loading';
        this.isAuthenticated = false;
        this.currentGame = null;

        // UI elements
        this.elements = {};

        this.init();
    }

    async init() {
        Logger.info('Initializing Advanced OGS Client...');

        // Initialize UI elements
        this.initializeElements();

        // Set up event listeners
        this.setupEventListeners();

        // Initialize Google Meet integration
        await this.initializeGoogleMeet();

        // Show authentication screen
        this.showView('auth');

        Logger.info('App controller initialized');
    }

    initializeElements() {
        // Main screens
        this.elements = {
            loadingScreen: document.getElementById('loading-screen'),
            authScreen: document.getElementById('auth-screen'),
            mainApp: document.getElementById('main-app'),

            // Auth elements
            oauthLoginBtn: document.getElementById('oauth-login'),
            manualLoginForm: document.getElementById('manual-login'),
            usernameInput: document.getElementById('username'),
            passwordInput: document.getElementById('password'),
            passwordToggle: document.getElementById('password-toggle'),

            // Navigation
            navTabs: document.querySelectorAll('.nav-tab'),
            userNameEl: document.getElementById('user-name'),
            userRankEl: document.getElementById('user-rank'),
            logoutBtn: document.getElementById('logout-btn'),

            // Views
            lobbyView: document.getElementById('lobby-view'),
            gameView: document.getElementById('game-view'),

            // Modal
            meetModal: document.getElementById('meet-modal'),
            confirmMeetBtn: document.getElementById('confirm-meet'),
            cancelMeetBtn: document.getElementById('cancel-meet')
        };
    }

    setupEventListeners() {
        // Authentication
        this.elements.oauthLoginBtn.addEventListener('click', () => {
            this.handleOAuthLogin();
        });

        this.elements.manualLoginForm.addEventListener('submit', (e) => {
            e.preventDefault();
            this.handleManualLogin();
        });

        // Password toggle
        this.elements.passwordToggle.addEventListener('click', () => {
            this.togglePasswordVisibility();
        });

        // Navigation
        this.elements.navTabs.forEach(tab => {
            tab.addEventListener('click', () => {
                this.switchView(tab.dataset.view);
            });
        });

        this.elements.logoutBtn.addEventListener('click', () => {
            this.logout();
        });

        // OGS Client events
        this.ogsClient.addEventListener('authenticated', (e) => {
            this.handleAuthenticated(e.detail);
        });

        this.ogsClient.addEventListener('connected', () => {
            this.handleConnected();
        });

        this.ogsClient.addEventListener('gameUpdate', (e) => {
            this.handleGameUpdate(e.detail);
        });

        this.ogsClient.addEventListener('gameMove', (e) => {
            this.handleGameMove(e.detail);
        });

        this.ogsClient.addEventListener('chatMessage', (e) => {
            this.handleChatMessage(e.detail);
        });

        this.ogsClient.addEventListener('error', (e) => {
            this.handleError(e.detail);
        });

        // Meet modal
        this.elements.confirmMeetBtn.addEventListener('click', () => {
            this.confirmMeetInvite();
        });

        this.elements.cancelMeetBtn.addEventListener('click', () => {
            this.closeMeetModal();
        });

        // Click outside modal to close
        this.elements.meetModal.addEventListener('click', (e) => {
            if (e.target === this.elements.meetModal) {
                this.closeMeetModal();
            }
        });
    }

    async initializeGoogleMeet() {
        try {
            // Initialize with demo config (you'll need to set up real credentials)
            await this.meetIntegration.initialize({
                apiKey: 'your-google-api-key', // Replace with real key
                accessToken: null // Will be set during auth
            });

            Logger.info('Google Meet integration ready');
        } catch (error) {
            Logger.warning('Google Meet initialization failed, using fallback mode:', error);
        }
    }

    // Authentication

    async handleOAuthLogin() {
        try {
            this.setAuthLoading(true);

            // This would redirect to OGS OAuth page in real implementation
            // For demo, we'll show manual login
            Logger.info('OAuth login not implemented in demo - please use manual login');
            this.showError('OAuth login not available in demo. Please use username/password.');

        } catch (error) {
            this.showError(error.message);
        } finally {
            this.setAuthLoading(false);
        }
    }

    togglePasswordVisibility() {
        const passwordInput = this.elements.passwordInput;
        const eyeIcon = this.elements.passwordToggle.querySelector('.eye-icon');

        if (passwordInput.type === 'password') {
            passwordInput.type = 'text';
            eyeIcon.textContent = '🙈';
        } else {
            passwordInput.type = 'password';
            eyeIcon.textContent = '👁️';
        }
    }

    async handleManualLogin() {
        try {
            this.setAuthLoading(true);

            const username = this.elements.usernameInput.value;
            const password = this.elements.passwordInput.value;

            // Demo mode - bypass authentication if username is "demo"
            if (username === 'demo') {
                Logger.info('Entering demo mode');

                // Simulate user info for demo
                const demoUserInfo = {
                    id: 12345,
                    username: 'demo',
                    ranking: '5k',
                    country: 'us'
                };

                this.handleAuthenticated(demoUserInfo);
                return;
            }

            const credentials = {
                username: username,
                password: password,
                client_id: 'demo-client', // You'll need real credentials
                client_secret: 'demo-secret'
            };

            await this.ogsClient.authenticate(credentials);

        } catch (error) {
            Logger.error('Login failed:', error);
            console.error('Full error details:', error);
            this.showError(`Login failed: ${error.message}. Try username "demo" with any password to see board demo.`);
            this.setAuthLoading(false);
        }
    }

    async handleAuthenticated(userInfo) {
        try {
            this.isAuthenticated = true;

            // Update UI with user info
            this.elements.userNameEl.textContent = userInfo.username;
            this.elements.userRankEl.textContent = userInfo.ranking || '?k';

            // Demo mode - skip OGS connection
            if (userInfo.username === 'demo') {
                Logger.info('Demo mode - showing board without OGS connection');

                // Show main app first
                this.showView('main');

                // Initialize controllers after main app is shown
                setTimeout(() => {
                    console.log('Initializing controllers in demo mode...');
                    this.initializeControllers();
                    this.setupDemoGame();
                }, 100);

                return;
            }

            // Connect to WebSocket
            await this.ogsClient.connect();

        } catch (error) {
            this.showError('Connection failed: ' + error.message);
            this.setAuthLoading(false);
        }
    }

    handleConnected() {
        Logger.info('Connected to OGS successfully');

        // Hide auth screen and show main app
        this.showView('main');

        // Initialize controllers
        this.initializeControllers();

        // Load initial data
        this.loadInitialData();
    }

    initializeControllers() {
        // Initialize lobby controller
        this.lobbyController = new LobbyController(this.ogsClient, this.meetIntegration);
        this.lobbyController.initialize();

        // Initialize game controller
        this.gameController = new GameController(
            this.gameEngine,
            this.ogsClient,
            this.meetIntegration
        );
        this.gameController.initialize();

        // Listen for game join requests
        this.lobbyController.addEventListener('joinGame', (e) => {
            this.joinGame(e.detail.gameId);
        });

        this.lobbyController.addEventListener('createGame', (e) => {
            this.createGame(e.detail.config);
        });
    }

    setupDemoGame() {
        // Create a demo game to showcase your board assets
        setTimeout(() => {
            Logger.info('Setting up demo game with your assets');
            console.log('Game controller:', this.gameController);
            console.log('Current view:', this.currentView);

            // Debug: Check if main app is visible
            const mainApp = this.elements.mainApp;
            console.log('Main app element:', mainApp);
            console.log('Main app classes:', mainApp.className);
            console.log('Main app computed style display:', window.getComputedStyle(mainApp).display);

            // Show game view directly (not a tab view)
            this.showGameView();

            // Additional check to ensure game view is truly visible
            const gameView = document.getElementById('game-view');
            if (gameView) {
                console.log('Game view after showGameView:');
                console.log('  Display:', window.getComputedStyle(gameView).display);
                console.log('  Visibility:', window.getComputedStyle(gameView).visibility);
                console.log('  Dimensions:', gameView.offsetWidth, 'x', gameView.offsetHeight);
            }

            // Check canvas element exists and has dimensions
            const canvas = document.getElementById('go-board');
            console.log('Canvas element:', canvas);
            if (canvas) {
                console.log('Canvas dimensions:', canvas.offsetWidth, 'x', canvas.offsetHeight);
                console.log('Canvas parent:', canvas.parentElement);
            }

            // Setup a demo board with some stones to show off your assets
            if (this.gameController && typeof this.gameController.setupDemoBoard === 'function') {
                console.log('Calling setupDemoBoard...');
                this.gameController.setupDemoBoard();
            } else {
                console.error('Game controller not available or setupDemoBoard not found');
                console.error('Available methods on game controller:', this.gameController ? Object.getOwnPropertyNames(Object.getPrototypeOf(this.gameController)) : 'none');
            }

            // Force a resize after a short delay to ensure proper board sizing
            setTimeout(() => {
                if (this.gameController && this.gameController.boardRenderer) {
                    console.log('Resizing board renderer...');
                    this.gameController.boardRenderer.resizeCanvas();
                } else {
                    console.log('Board renderer not available for resize');
                }
            }, 200);

            // Final check after everything should be set up
            setTimeout(() => {
                console.log('=== Final demo setup check ===');
                const finalCanvas = document.getElementById('go-board');
                if (finalCanvas) {
                    console.log('Final canvas dimensions:', finalCanvas.offsetWidth, 'x', finalCanvas.offsetHeight);
                    console.log('Canvas style width/height:', finalCanvas.style.width, finalCanvas.style.height);
                    console.log('Canvas context:', finalCanvas.getContext('2d'));
                }

                // Check for bowl elements
                const bowls = document.querySelectorAll('.bowl');
                console.log('Bowl elements found:', bowls.length);
                bowls.forEach((bowl, index) => {
                    console.log(`Bowl ${index}:`, bowl.className, 'visible:', window.getComputedStyle(bowl).display !== 'none');
                });
            }, 500);
        }, 1000);
    }

    showGameView() {
        console.log('showGameView() called');

        // Hide all navigation views
        document.querySelectorAll('#lobby-view, #games-view, #observe-view, #tournaments-view').forEach(view => {
            console.log('Hiding view:', view.id);
            view.style.display = 'none';
        });

        // Show game view
        const gameView = document.getElementById('game-view');
        console.log('Game view element:', gameView);
        if (gameView) {
            console.log('Setting game view to display block');
            gameView.style.display = 'block';
            gameView.classList.add('active');
            console.log('Game view classes after:', gameView.className);
            console.log('Game view computed display:', window.getComputedStyle(gameView).display);
        } else {
            console.error('Game view element not found!');
        }

        Logger.info('Switched to game view');
    }

    async loadInitialData() {
        try {
            // Load open games
            await this.ogsClient.getOpenGames();

            // Switch to lobby view
            this.switchView('lobby');

        } catch (error) {
            Logger.error('Failed to load initial data:', error);
            this.showError('Failed to load game data');
        }
    }

    // View Management

    showView(viewName) {
        // Hide all screens
        this.elements.loadingScreen.classList.add('hidden');
        this.elements.authScreen.classList.add('hidden');
        this.elements.mainApp.classList.add('hidden');

        // Show requested screen
        switch (viewName) {
            case 'loading':
                this.elements.loadingScreen.classList.remove('hidden');
                break;
            case 'auth':
                this.elements.authScreen.classList.remove('hidden');
                break;
            case 'main':
                this.elements.mainApp.classList.remove('hidden');
                break;
        }

        this.currentView = viewName;
    }

    switchView(viewName) {
        if (!this.isAuthenticated) return;

        // Update navigation
        this.elements.navTabs.forEach(tab => {
            tab.classList.toggle('active', tab.dataset.view === viewName);
        });

        // Hide all views
        document.querySelectorAll('.view').forEach(view => {
            view.classList.remove('active');
        });

        // Show requested view
        const targetView = document.getElementById(`${viewName}-view`);
        if (targetView) {
            targetView.classList.add('active');
        }

        // Handle view-specific logic
        switch (viewName) {
            case 'lobby':
                this.lobbyController?.refresh();
                break;
            case 'games':
                this.loadMyGames();
                break;
            case 'observe':
                this.loadObservableGames();
                break;
            case 'tournaments':
                this.loadTournaments();
                break;
        }
    }

    // Game Management

    async joinGame(gameId) {
        try {
            Logger.info(`Joining game ${gameId}`);

            // Join via OGS
            this.ogsClient.joinGame(gameId);

            // Switch to game view
            this.currentGame = gameId;
            this.gameController.setGame(gameId);
            document.getElementById('game-view').classList.add('active');
            document.getElementById('lobby-view').classList.remove('active');

        } catch (error) {
            Logger.error('Failed to join game:', error);
            this.showError('Failed to join game');
        }
    }

    async createGame(config) {
        try {
            Logger.info('Creating new game:', config);

            const response = await this.ogsClient.createGame(config);
            Logger.info('Game created:', response);

            // Join the created game
            if (response.game_id) {
                await this.joinGame(response.game_id);
            }

        } catch (error) {
            Logger.error('Failed to create game:', error);
            this.showError('Failed to create game');
        }
    }

    leaveCurrentGame() {
        if (this.currentGame) {
            this.ogsClient.leaveGame(this.currentGame);
            this.currentGame = null;

            // Return to lobby
            this.switchView('lobby');
        }
    }

    // Event Handlers

    handleGameUpdate(game) {
        if (this.gameController && this.currentGame === game.id) {
            this.gameController.updateGame(game);
        }
    }

    handleGameMove(data) {
        if (this.gameController && this.currentGame === data.gameId) {
            this.gameController.handleMove(data);
        }
    }

    handleChatMessage(message) {
        // Route to appropriate controller
        if (message.channel === 'global-english') {
            this.lobbyController?.handleGlobalChat(message);
        } else if (message.game_id && this.currentGame === message.game_id) {
            this.gameController?.handleGameChat(message);
        }
    }

    handleError(error) {
        Logger.error('OGS Client error:', error);
        this.showError('Connection error: ' + error.message);
    }

    // Google Meet

    showMeetModal() {
        this.elements.meetModal.classList.remove('hidden');
    }

    closeMeetModal() {
        this.elements.meetModal.classList.add('hidden');
    }

    async confirmMeetInvite() {
        try {
            this.closeMeetModal();

            if (!this.currentGame) {
                throw new Error('No active game');
            }

            await this.gameController.startMeetSession();

        } catch (error) {
            Logger.error('Failed to start meet session:', error);
            this.showError('Failed to start video call');
        }
    }

    // Utility Methods

    setAuthLoading(loading) {
        const submitBtn = this.elements.manualLoginForm.querySelector('button[type="submit"]');
        const oauthBtn = this.elements.oauthLoginBtn;

        if (loading) {
            submitBtn.classList.add('auth-loading');
            submitBtn.disabled = true;
            oauthBtn.classList.add('auth-loading');
            oauthBtn.disabled = true;
        } else {
            submitBtn.classList.remove('auth-loading');
            submitBtn.disabled = false;
            oauthBtn.classList.remove('auth-loading');
            oauthBtn.disabled = false;
        }
    }

    showError(message) {
        // Remove existing error messages
        document.querySelectorAll('.auth-error').forEach(el => el.remove());

        // Create new error message
        const errorDiv = document.createElement('div');
        errorDiv.className = 'auth-error';
        errorDiv.textContent = message;

        // Insert into auth form
        const authContainer = document.querySelector('.auth-methods');
        authContainer.insertBefore(errorDiv, authContainer.firstChild);

        // Auto-remove after 5 seconds
        setTimeout(() => {
            if (errorDiv.parentElement) {
                errorDiv.remove();
            }
        }, 5000);
    }

    async logout() {
        try {
            // Disconnect from OGS
            this.ogsClient.disconnect();

            // Leave current game
            if (this.currentGame) {
                this.leaveCurrentGame();
            }

            // Reset state
            this.isAuthenticated = false;
            this.currentGame = null;

            // Show auth screen
            this.showView('auth');

            // Clear form
            this.elements.usernameInput.value = '';
            this.elements.passwordInput.value = '';

            Logger.info('Logged out successfully');

        } catch (error) {
            Logger.error('Logout error:', error);
        }
    }

    // Placeholder methods for other views
    async loadMyGames() {
        Logger.info('Loading my games...');
        // Implementation would load user's active games
    }

    async loadObservableGames() {
        Logger.info('Loading observable games...');
        // Implementation would load games available for observation
    }

    async loadTournaments() {
        Logger.info('Loading tournaments...');
        // Implementation would load tournament data
    }

    // Public API

    getOGSClient() {
        return this.ogsClient;
    }

    getGameEngine() {
        return this.gameEngine;
    }

    getMeetIntegration() {
        return this.meetIntegration;
    }

    getCurrentGame() {
        return this.currentGame;
    }

    isUserAuthenticated() {
        return this.isAuthenticated;
    }
}

// Export for web usage
window.AppController = AppController;