/**
 * OGS API Client - WebSocket and REST API integration
 * Based on research of OGS APIs and third-party client patterns
 */

class OGSClient extends EventTarget {
    constructor() {
        super();

        // Connection state
        this.ws = null;
        this.isConnected = false;
        this.authToken = null;
        this.userId = null;
        this.userInfo = null;

        // API endpoints
        this.baseURL = 'https://online-go.com';
        this.wsURL = 'wss://online-go.com/socket.io/?EIO=3&transport=websocket';

        // Message handling
        this.messageQueue = [];
        this.responseHandlers = new Map();
        this.messageId = 1;

        // Reconnection
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
        this.reconnectDelay = 1000;

        // Game state
        this.activeGames = new Map();
        this.openGames = [];
        this.challenges = [];

        Logger.info('OGSClient initialized');
    }

    // Authentication

    /**
     * Authenticate with OGS using session-based login (fallback method)
     */
    async authenticate(credentials) {
        try {
            Logger.info('Authenticating with OGS...');

            // Try session-based login first (more reliable for testing)
            const loginResponse = await fetch(`${this.baseURL}/api/v0/login`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                credentials: 'include', // Important for session cookies
                body: JSON.stringify({
                    username: credentials.username,
                    password: credentials.password
                })
            });

            if (!loginResponse.ok) {
                const errorData = await loginResponse.text();
                Logger.error('Login response:', errorData);
                throw new Error(`Authentication failed: ${loginResponse.status} ${loginResponse.statusText}`);
            }

            const loginData = await loginResponse.json();
            Logger.info('Login successful:', loginData);

            // Store session info
            this.userId = loginData.id;
            this.authToken = 'session'; // Indicates session-based auth

            // Get detailed user info
            await this.fetchUserInfo();

            Logger.info(`Authenticated as ${this.userInfo.username}`);
            this.dispatchEvent(new CustomEvent('authenticated', { detail: this.userInfo }));

            return this.userInfo;

        } catch (error) {
            Logger.error('Authentication failed:', error);

            // Try OAuth2 as fallback (requires proper client credentials)
            if (credentials.client_id && credentials.client_secret) {
                return this.authenticateOAuth2(credentials);
            }

            this.dispatchEvent(new CustomEvent('authError', { detail: error.message }));
            throw error;
        }
    }

    /**
     * OAuth2 authentication (requires proper client credentials)
     */
    async authenticateOAuth2(credentials) {
        const response = await fetch(`${this.baseURL}/oauth2/token/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: new URLSearchParams({
                grant_type: 'password',
                username: credentials.username,
                password: credentials.password,
                client_id: credentials.client_id,
                client_secret: credentials.client_secret
            })
        });

        if (!response.ok) {
            throw new Error(`OAuth2 failed: ${response.statusText}`);
        }

        const tokenData = await response.json();
        this.authToken = tokenData.access_token;
        return this.fetchUserInfo();
    }

    /**
     * Get current user information
     */
    async fetchUserInfo() {
        try {
            // Try the newer API first
            const response = await this.apiRequest('/api/v1/me');
            this.userInfo = response;
            this.userId = response.id;
            return response;
        } catch (error) {
            Logger.warn('v1/me failed, trying v0/me:', error.message);
            // Fallback to older API
            const response = await this.apiRequest('/api/v0/me');
            this.userInfo = response;
            this.userId = response.id;
            return response;
        }
    }

    // Connection Management

    /**
     * Connect to OGS WebSocket
     */
    async connect() {
        if (this.isConnected) {
            Logger.warning('Already connected to OGS');
            return;
        }

        if (!this.authToken) {
            throw new Error('Must authenticate before connecting');
        }

        try {
            Logger.info('Connecting to OGS WebSocket...');

            this.ws = new WebSocket(this.wsURL);

            this.ws.onopen = () => {
                Logger.info('WebSocket connected');
                this.isConnected = true;
                this.reconnectAttempts = 0;

                // Send authentication
                this.sendMessage('authenticate', {
                    auth: this.authToken,
                    player_id: this.userId
                });

                this.dispatchEvent(new CustomEvent('connected'));
            };

            this.ws.onmessage = (event) => {
                this.handleMessage(event.data);
            };

            this.ws.onclose = (event) => {
                Logger.warning('WebSocket disconnected:', event.code, event.reason);
                this.isConnected = false;
                this.ws = null;

                this.dispatchEvent(new CustomEvent('disconnected', { detail: event }));

                // Attempt reconnection
                if (this.reconnectAttempts < this.maxReconnectAttempts) {
                    setTimeout(() => this.reconnect(), this.reconnectDelay);
                }
            };

            this.ws.onerror = (error) => {
                Logger.error('WebSocket error:', error);
                this.dispatchEvent(new CustomEvent('error', { detail: error }));
            };

        } catch (error) {
            Logger.error('Failed to connect:', error);
            throw error;
        }
    }

    /**
     * Reconnect to OGS
     */
    async reconnect() {
        this.reconnectAttempts++;
        Logger.info(`Reconnection attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts}`);

        try {
            await this.connect();
        } catch (error) {
            if (this.reconnectAttempts < this.maxReconnectAttempts) {
                this.reconnectDelay *= 2; // Exponential backoff
                setTimeout(() => this.reconnect(), this.reconnectDelay);
            } else {
                Logger.error('Max reconnection attempts reached');
                this.dispatchEvent(new CustomEvent('reconnectFailed'));
            }
        }
    }

    /**
     * Disconnect from OGS
     */
    disconnect() {
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
        this.isConnected = false;
    }

    // Message Handling

    /**
     * Send message to OGS WebSocket
     */
    sendMessage(type, data = {}) {
        if (!this.isConnected || !this.ws) {
            Logger.warning('Not connected, queueing message:', type);
            this.messageQueue.push({ type, data });
            return;
        }

        const message = {
            id: this.messageId++,
            type,
            ...data
        };

        const messageStr = JSON.stringify(message);
        Logger.debug('Sending message:', messageStr);

        this.ws.send(messageStr);
        return message.id;
    }

    /**
     * Handle incoming WebSocket message
     */
    handleMessage(messageStr) {
        try {
            const message = JSON.parse(messageStr);
            Logger.debug('Received message:', message);

            // Handle specific message types
            switch (message.type) {
                case 'auth_ok':
                    this.handleAuthSuccess(message);
                    break;
                case 'auth_error':
                    this.handleAuthError(message);
                    break;
                case 'game/update':
                    this.handleGameUpdate(message);
                    break;
                case 'game/move':
                    this.handleGameMove(message);
                    break;
                case 'game/challenge':
                    this.handleGameChallenge(message);
                    break;
                case 'chat/message':
                    this.handleChatMessage(message);
                    break;
                case 'lobby/game':
                    this.handleLobbyGame(message);
                    break;
                default:
                    Logger.debug('Unhandled message type:', message.type);
            }

            // Handle response callbacks
            if (message.id && this.responseHandlers.has(message.id)) {
                const handler = this.responseHandlers.get(message.id);
                handler(message);
                this.responseHandlers.delete(message.id);
            }

            // Emit generic message event
            this.dispatchEvent(new CustomEvent('message', { detail: message }));

        } catch (error) {
            Logger.error('Failed to parse message:', error, messageStr);
        }
    }

    handleAuthSuccess(message) {
        Logger.info('WebSocket authenticated successfully');

        // Send queued messages
        while (this.messageQueue.length > 0) {
            const queued = this.messageQueue.shift();
            this.sendMessage(queued.type, queued.data);
        }

        // Subscribe to channels
        this.subscribeToChannels();

        this.dispatchEvent(new CustomEvent('wsAuthenticated'));
    }

    handleAuthError(message) {
        Logger.error('WebSocket authentication failed:', message.error);
        this.dispatchEvent(new CustomEvent('wsAuthError', { detail: message.error }));
    }

    handleGameUpdate(message) {
        const game = message.game;
        this.activeGames.set(game.id, game);

        this.dispatchEvent(new CustomEvent('gameUpdate', { detail: game }));
    }

    handleGameMove(message) {
        const { game_id, move } = message;
        const game = this.activeGames.get(game_id);

        if (game) {
            // Update game state
            if (!game.moves) game.moves = [];
            game.moves.push(move);

            this.dispatchEvent(new CustomEvent('gameMove', {
                detail: { gameId: game_id, move, game }
            }));
        }
    }

    handleGameChallenge(message) {
        this.challenges.push(message.challenge);
        this.dispatchEvent(new CustomEvent('gameChallenge', { detail: message.challenge }));
    }

    handleChatMessage(message) {
        this.dispatchEvent(new CustomEvent('chatMessage', { detail: message }));
    }

    handleLobbyGame(message) {
        const game = message.game;

        if (message.action === 'add') {
            this.openGames.push(game);
        } else if (message.action === 'remove') {
            this.openGames = this.openGames.filter(g => g.id !== game.id);
        } else if (message.action === 'update') {
            const index = this.openGames.findIndex(g => g.id === game.id);
            if (index >= 0) {
                this.openGames[index] = { ...this.openGames[index], ...game };
            }
        }

        this.dispatchEvent(new CustomEvent('lobbyUpdate', {
            detail: { action: message.action, game, openGames: this.openGames }
        }));
    }

    // Channel Management

    /**
     * Subscribe to OGS channels
     */
    subscribeToChannels() {
        // Subscribe to lobby updates
        this.sendMessage('lobby/join');

        // Subscribe to global chat
        this.sendMessage('chat/join', { channel: 'global-english' });

        // Subscribe to user notifications
        this.sendMessage('notification/subscribe');

        Logger.info('Subscribed to OGS channels');
    }

    // REST API Methods

    /**
     * Make authenticated API request
     */
    async apiRequest(endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;
        const headers = {
            'Content-Type': 'application/json',
            ...options.headers
        };

        // Use session cookies for session-based auth, Bearer token for OAuth2
        const fetchOptions = {
            ...options,
            headers,
            credentials: 'include' // Always include cookies for session auth
        };

        if (this.authToken && this.authToken !== 'session') {
            headers['Authorization'] = `Bearer ${this.authToken}`;
        }

        const response = await fetch(url, fetchOptions);

        if (!response.ok) {
            const errorText = await response.text();
            Logger.error(`API request failed: ${response.status} ${response.statusText}`, errorText);
            throw new Error(`API request failed: ${response.statusText}`);
        }

        const contentType = response.headers.get('content-type');
        if (contentType && contentType.includes('application/json')) {
            return response.json();
        } else {
            return response.text();
        }
    }

    // Game Management

    /**
     * Get open games from lobby
     */
    async getOpenGames() {
        const response = await this.apiRequest('/api/v1/challenges');
        this.openGames = response.results || [];
        return this.openGames;
    }

    /**
     * Create a new game challenge
     */
    async createGame(gameConfig) {
        const response = await this.apiRequest('/api/v1/challenges', {
            method: 'POST',
            body: JSON.stringify(gameConfig)
        });

        Logger.info('Game created:', response);
        return response;
    }

    /**
     * Accept a game challenge
     */
    async acceptChallenge(challengeId) {
        const response = await this.apiRequest(`/api/v1/challenges/${challengeId}/accept`, {
            method: 'POST'
        });

        Logger.info('Challenge accepted:', response);
        return response;
    }

    /**
     * Join a game
     */
    joinGame(gameId) {
        this.sendMessage('game/connect', { game_id: gameId });
        Logger.info(`Joining game ${gameId}`);
    }

    /**
     * Leave a game
     */
    leaveGame(gameId) {
        this.sendMessage('game/disconnect', { game_id: gameId });
        this.activeGames.delete(gameId);
        Logger.info(`Left game ${gameId}`);
    }

    /**
     * Make a move in a game
     */
    makeMove(gameId, x, y) {
        this.sendMessage('game/move', {
            game_id: gameId,
            move: [x, y]
        });

        Logger.info(`Move made: ${x}, ${y} in game ${gameId}`);
    }

    /**
     * Pass in a game
     */
    pass(gameId) {
        this.sendMessage('game/move', {
            game_id: gameId,
            move: []
        });

        Logger.info(`Pass in game ${gameId}`);
    }

    /**
     * Resign from a game
     */
    resign(gameId) {
        this.sendMessage('game/resign', { game_id: gameId });
        Logger.info(`Resigned from game ${gameId}`);
    }

    // Chat

    /**
     * Send chat message
     */
    sendChatMessage(channel, message) {
        this.sendMessage('chat/send', {
            channel,
            message
        });
    }

    /**
     * Send game chat message
     */
    sendGameChat(gameId, message) {
        this.sendMessage('game/chat', {
            game_id: gameId,
            message
        });
    }

    // User Management

    /**
     * Get user profile
     */
    async getUserProfile(userId) {
        return await this.apiRequest(`/api/v1/players/${userId}`);
    }

    /**
     * Search for users
     */
    async searchUsers(query) {
        const response = await this.apiRequest(`/api/v1/players?search=${encodeURIComponent(query)}`);
        return response.results || [];
    }

    // Utility Methods

    /**
     * Get connection status
     */
    getConnectionStatus() {
        return {
            connected: this.isConnected,
            authenticated: !!this.authToken,
            user: this.userInfo,
            activeGames: this.activeGames.size,
            openGames: this.openGames.length
        };
    }

    /**
     * Get active games
     */
    getActiveGames() {
        return Array.from(this.activeGames.values());
    }

    /**
     * Get open games
     */
    getOpenGamesList() {
        return this.openGames;
    }
}

// Export for web usage
window.OGSClient = OGSClient;