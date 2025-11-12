/**
 * Lobby Controller - Manages lobby view, open games, and quick match
 */

class LobbyController extends EventTarget {
    constructor(ogsClient, meetIntegration) {
        super();

        this.ogsClient = ogsClient;
        this.meetIntegration = meetIntegration;

        // UI elements
        this.elements = {};

        // State
        this.openGames = [];
        this.searchingForMatch = false;

        // Chat
        this.chatMessages = [];
        this.maxChatMessages = 100;
    }

    initialize() {
        this.initializeElements();
        this.setupEventListeners();
        this.setupOGSListeners();

        Logger.info('LobbyController initialized');
    }

    initializeElements() {
        this.elements = {
            // Quick game
            gameSizeSelect: document.getElementById('game-size'),
            timeControlSelect: document.getElementById('time-control'),
            automatchBtn: document.getElementById('automatch-btn'),

            // Game creation
            createGameBtn: document.getElementById('create-game-btn'),

            // Games list
            openGamesContainer: document.getElementById('open-games'),

            // Chat
            chatMessages: document.getElementById('chat-messages'),
            chatInput: document.getElementById('chat-input'),
            chatSendBtn: document.getElementById('chat-send')
        };
    }

    setupEventListeners() {
        // Quick game
        this.elements.automatchBtn.addEventListener('click', () => {
            this.toggleAutomatch();
        });

        // Game creation
        this.elements.createGameBtn.addEventListener('click', () => {
            this.showCreateGameDialog();
        });

        // Chat
        this.elements.chatSendBtn.addEventListener('click', () => {
            this.sendChatMessage();
        });

        this.elements.chatInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.sendChatMessage();
            }
        });
    }

    setupOGSListeners() {
        this.ogsClient.addEventListener('lobbyUpdate', (e) => {
            this.handleLobbyUpdate(e.detail);
        });

        this.ogsClient.addEventListener('chatMessage', (e) => {
            if (e.detail.channel === 'global-english') {
                this.handleGlobalChat(e.detail);
            }
        });

        this.ogsClient.addEventListener('gameChallenge', (e) => {
            this.handleGameChallenge(e.detail);
        });
    }

    // Quick Match

    async toggleAutomatch() {
        if (this.searchingForMatch) {
            await this.cancelAutomatch();
        } else {
            await this.startAutomatch();
        }
    }

    async startAutomatch() {
        try {
            const gameSize = parseInt(this.elements.gameSizeSelect.value);
            const timeControl = this.elements.timeControlSelect.value;

            Logger.info(`Starting automatch: ${gameSize}x${gameSize}, ${timeControl}`);

            // Create automatch request
            const matchConfig = {
                board_size: gameSize,
                time_control: this.getTimeControlConfig(timeControl),
                ranked: true
            };

            // Send automatch request to OGS
            this.ogsClient.sendMessage('automatch/find', matchConfig);

            // Update UI
            this.searchingForMatch = true;
            this.elements.automatchBtn.textContent = 'Cancel Search';
            this.elements.automatchBtn.classList.add('searching');

            // Timeout after 60 seconds
            setTimeout(() => {
                if (this.searchingForMatch) {
                    this.cancelAutomatch();
                    this.showNotification('No opponent found. Try again later.', 'warning');
                }
            }, 60000);

        } catch (error) {
            Logger.error('Failed to start automatch:', error);
            this.showNotification('Failed to start search', 'error');
        }
    }

    async cancelAutomatch() {
        try {
            this.ogsClient.sendMessage('automatch/cancel');

            this.searchingForMatch = false;
            this.elements.automatchBtn.textContent = 'Find Game';
            this.elements.automatchBtn.classList.remove('searching');

            Logger.info('Automatch cancelled');

        } catch (error) {
            Logger.error('Failed to cancel automatch:', error);
        }
    }

    getTimeControlConfig(timeControlType) {
        switch (timeControlType) {
            case 'blitz':
                return {
                    system: 'byoyomi',
                    time_control: 300, // 5 minutes
                    periods: 3,
                    period_time: 30
                };
            case 'live':
                return {
                    system: 'byoyomi',
                    time_control: 1200, // 20 minutes
                    periods: 5,
                    period_time: 30
                };
            case 'correspondence':
                return {
                    system: 'correspondence',
                    time_control: 259200, // 3 days per move
                    periods: 1,
                    period_time: 86400 // 1 day
                };
            default:
                return this.getTimeControlConfig('live');
        }
    }

    // Game Creation

    showCreateGameDialog() {
        // Create modal for custom game creation
        const modal = this.createGameModal();
        document.body.appendChild(modal);
    }

    createGameModal() {
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>Create Custom Game</h3>
                    <button class="modal-close">&times;</button>
                </div>
                <div class="modal-body">
                    <form id="create-game-form">
                        <div class="form-group">
                            <label>Board Size:</label>
                            <select name="board_size">
                                <option value="19">19×19</option>
                                <option value="13">13×13</option>
                                <option value="9">9×9</option>
                            </select>
                        </div>

                        <div class="form-group">
                            <label>Time Control:</label>
                            <select name="time_control">
                                <option value="blitz">Blitz (5min)</option>
                                <option value="live">Live (20min)</option>
                                <option value="correspondence">Correspondence</option>
                            </select>
                        </div>

                        <div class="form-group">
                            <label>Game Type:</label>
                            <select name="game_type">
                                <option value="ranked">Ranked</option>
                                <option value="unranked">Unranked</option>
                            </select>
                        </div>

                        <div class="form-group">
                            <label>Your Color:</label>
                            <select name="player_color">
                                <option value="automatic">Automatic</option>
                                <option value="black">Black</option>
                                <option value="white">White</option>
                            </select>
                        </div>

                        <div class="form-group">
                            <label>Handicap:</label>
                            <select name="handicap">
                                <option value="0">No Handicap</option>
                                <option value="2">2 stones</option>
                                <option value="3">3 stones</option>
                                <option value="4">4 stones</option>
                                <option value="5">5 stones</option>
                                <option value="6">6 stones</option>
                                <option value="7">7 stones</option>
                                <option value="8">8 stones</option>
                                <option value="9">9 stones</option>
                            </select>
                        </div>

                        <div class="form-group">
                            <label>
                                <input type="checkbox" name="private_game"> Private Game
                            </label>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" id="cancel-create">Cancel</button>
                    <button type="submit" class="btn btn-primary" id="confirm-create">Create Game</button>
                </div>
            </div>
        `;

        // Event listeners
        modal.querySelector('.modal-close').addEventListener('click', () => {
            modal.remove();
        });

        modal.querySelector('#cancel-create').addEventListener('click', () => {
            modal.remove();
        });

        modal.querySelector('#confirm-create').addEventListener('click', () => {
            this.handleCreateGame(modal);
        });

        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.remove();
            }
        });

        return modal;
    }

    async handleCreateGame(modal) {
        try {
            const form = modal.querySelector('#create-game-form');
            const formData = new FormData(form);

            const gameConfig = {
                board_size: parseInt(formData.get('board_size')),
                time_control: this.getTimeControlConfig(formData.get('time_control')),
                ranked: formData.get('game_type') === 'ranked',
                handicap: parseInt(formData.get('handicap')),
                color_preference: formData.get('player_color'),
                private: formData.get('private_game') === 'on'
            };

            Logger.info('Creating game with config:', gameConfig);

            this.dispatchEvent(new CustomEvent('createGame', {
                detail: { config: gameConfig }
            }));

            modal.remove();

        } catch (error) {
            Logger.error('Failed to create game:', error);
            this.showNotification('Failed to create game', 'error');
        }
    }

    // Games List Management

    handleLobbyUpdate(data) {
        const { action, game, openGames } = data;

        this.openGames = openGames;
        this.renderOpenGames();

        if (action === 'add') {
            this.showNotification(`New game available: ${game.players?.black?.username || 'Anonymous'} vs ${game.players?.white?.username || 'Open'}`);
        }
    }

    renderOpenGames() {
        const container = this.elements.openGamesContainer;

        if (this.openGames.length === 0) {
            container.innerHTML = `
                <div class="games-empty">
                    <h3>No Open Games</h3>
                    <p>Be the first to create a game!</p>
                </div>
            `;
            return;
        }

        container.innerHTML = this.openGames.map(game => this.renderGameCard(game)).join('');
    }

    renderGameCard(game) {
        const timeControl = this.formatTimeControl(game.time_control);
        const isRanked = game.ranked ? 'Ranked' : 'Unranked';

        return `
            <div class="game-card" data-game-id="${game.id}">
                <div class="game-card-header">
                    <div class="game-info">
                        <div class="game-size">${game.width}×${game.height}</div>
                        <div class="game-title">${isRanked} Game</div>
                    </div>
                </div>

                <div class="game-players">
                    <div class="player-info">
                        <div class="player-avatar black">⚫</div>
                        <div class="player-details">
                            <div class="player-name">${game.players?.black?.username || 'You'}</div>
                            <div class="player-rank">${game.players?.black?.rank || '?k'}</div>
                        </div>
                    </div>

                    <div class="vs-indicator">vs</div>

                    <div class="player-info">
                        <div class="player-avatar white">⚪</div>
                        <div class="player-details">
                            <div class="player-name">${game.players?.white?.username || 'Open'}</div>
                            <div class="player-rank">${game.players?.white?.rank || '?k'}</div>
                        </div>
                    </div>
                </div>

                <div class="game-meta">
                    <div class="time-control">
                        <span>⏱️</span> ${timeControl}
                    </div>
                    <div class="game-status ${game.phase}">${this.formatGameStatus(game)}</div>
                </div>
            </div>
        `;
    }

    formatTimeControl(timeControl) {
        if (!timeControl) return 'Unknown';

        if (timeControl.system === 'byoyomi') {
            const minutes = Math.floor(timeControl.time_control / 60);
            return `${minutes}min + ${timeControl.periods}×${timeControl.period_time}s`;
        } else if (timeControl.system === 'correspondence') {
            const days = Math.floor(timeControl.time_control / 86400);
            return `${days} days/move`;
        }

        return 'Custom';
    }

    formatGameStatus(game) {
        switch (game.phase) {
            case 'play':
                return 'In Progress';
            case 'stone removal':
                return 'Scoring';
            case 'finished':
                return 'Finished';
            default:
                return 'Waiting';
        }
    }

    // Chat

    handleGlobalChat(message) {
        this.chatMessages.push({
            id: Date.now(),
            username: message.username,
            message: message.message,
            timestamp: new Date()
        });

        // Keep only recent messages
        if (this.chatMessages.length > this.maxChatMessages) {
            this.chatMessages = this.chatMessages.slice(-this.maxChatMessages);
        }

        this.renderChatMessages();
    }

    renderChatMessages() {
        const container = this.elements.chatMessages;

        container.innerHTML = this.chatMessages.map(msg => `
            <div class="chat-message">
                <span class="chat-username">${msg.username}:</span>
                ${this.escapeHtml(msg.message)}
                <span class="chat-timestamp">${this.formatTime(msg.timestamp)}</span>
            </div>
        `).join('');

        // Scroll to bottom
        container.scrollTop = container.scrollHeight;
    }

    sendChatMessage() {
        const input = this.elements.chatInput;
        const message = input.value.trim();

        if (!message) return;

        this.ogsClient.sendChatMessage('global-english', message);
        input.value = '';
    }

    // Game Challenges

    handleGameChallenge(challenge) {
        this.showGameChallengeNotification(challenge);
    }

    showGameChallengeNotification(challenge) {
        const notification = document.createElement('div');
        notification.className = 'challenge-notification';
        notification.innerHTML = `
            <div class="notification-content">
                <h4>Game Challenge</h4>
                <p>${challenge.challenger.username} has challenged you to a game!</p>
                <div class="challenge-details">
                    <span>Board: ${challenge.width}×${challenge.height}</span>
                    <span>Time: ${this.formatTimeControl(challenge.time_control)}</span>
                </div>
                <div class="challenge-actions">
                    <button class="btn btn-secondary" onclick="this.parentElement.parentElement.parentElement.remove()">Decline</button>
                    <button class="btn btn-primary" onclick="lobbyController.acceptChallenge('${challenge.id}')">Accept</button>
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

    async acceptChallenge(challengeId) {
        try {
            const response = await this.ogsClient.acceptChallenge(challengeId);

            this.dispatchEvent(new CustomEvent('joinGame', {
                detail: { gameId: response.game_id }
            }));

            // Remove challenge notification
            document.querySelectorAll('.challenge-notification').forEach(el => el.remove());

        } catch (error) {
            Logger.error('Failed to accept challenge:', error);
            this.showNotification('Failed to accept challenge', 'error');
        }
    }

    // Event Handlers

    refresh() {
        // Reload open games and chat
        this.renderOpenGames();
        this.renderChatMessages();
    }

    // Utility Methods

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    formatTime(date) {
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.textContent = message;

        document.body.appendChild(notification);

        setTimeout(() => {
            notification.remove();
        }, 5000);
    }
}

// Export for web usage
window.LobbyController = LobbyController;