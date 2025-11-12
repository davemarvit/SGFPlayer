/**
 * Google Meet Integration - Based on Google Meet REST API
 * Handles creating meeting spaces and inviting opponents
 */

class GoogleMeetIntegration {
    constructor() {
        // Google Meet API configuration
        this.apiKey = null; // Set via configuration
        this.accessToken = null;
        this.baseURL = 'https://meet.googleapis.com/v2';

        // Meeting state
        this.activeMeetings = new Map();
        this.pendingInvites = new Map();

        Logger.info('GoogleMeetIntegration initialized');
    }

    /**
     * Initialize with Google API credentials
     */
    async initialize(config) {
        this.apiKey = config.apiKey;
        this.accessToken = config.accessToken;

        // Load Google API client if not already loaded
        if (!window.gapi) {
            await this.loadGoogleAPI();
        }

        Logger.info('Google Meet integration configured');
    }

    /**
     * Load Google API client library
     */
    async loadGoogleAPI() {
        return new Promise((resolve, reject) => {
            const script = document.createElement('script');
            script.src = 'https://apis.google.com/js/api.js';
            script.onload = () => {
                window.gapi.load('client:auth2', resolve);
            };
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }

    /**
     * Authenticate with Google OAuth2
     */
    async authenticate() {
        try {
            // Initialize the Google API client
            await window.gapi.client.init({
                apiKey: this.apiKey,
                discoveryDocs: ['https://meet.googleapis.com/$discovery/rest?version=v2'],
                scope: 'https://www.googleapis.com/auth/meetings.space.created'
            });

            // Sign in
            const authInstance = window.gapi.auth2.getAuthInstance();
            const user = await authInstance.signIn();
            this.accessToken = user.getAuthResponse().access_token;

            Logger.info('Google Meet authentication successful');
            return true;

        } catch (error) {
            Logger.error('Google Meet authentication failed:', error);
            throw error;
        }
    }

    /**
     * Create a new Google Meet space
     */
    async createMeetingSpace(gameId, config = {}) {
        try {
            if (!this.accessToken) {
                throw new Error('Not authenticated with Google');
            }

            // Create meeting space using Google Meet REST API
            const response = await fetch(`${this.baseURL}/spaces`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.accessToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    config: {
                        accessType: 'OPEN',
                        entryPointAccess: 'ALL',
                        ...config
                    }
                })
            });

            if (!response.ok) {
                throw new Error(`Failed to create meeting space: ${response.statusText}`);
            }

            const meetingSpace = await response.json();

            // Store meeting info
            const meetingInfo = {
                spaceId: meetingSpace.name,
                meetingUri: meetingSpace.meetingUri,
                meetingCode: meetingSpace.meetingCode,
                gameId,
                createdAt: new Date()
            };

            this.activeMeetings.set(gameId, meetingInfo);

            Logger.info(`Created meeting space for game ${gameId}:`, meetingInfo);
            return meetingInfo;

        } catch (error) {
            Logger.error('Failed to create meeting space:', error);
            throw error;
        }
    }

    /**
     * Send meeting invite to opponent via OGS chat
     */
    async inviteOpponent(gameId, ogsClient, opponentId) {
        try {
            const meetingInfo = this.activeMeetings.get(gameId);
            if (!meetingInfo) {
                throw new Error('No meeting space found for this game');
            }

            // Create invite message
            const inviteMessage = this.createInviteMessage(meetingInfo);

            // Send via game chat
            ogsClient.sendGameChat(gameId, inviteMessage);

            // Track pending invite
            this.pendingInvites.set(gameId, {
                opponentId,
                sentAt: new Date(),
                meetingInfo
            });

            Logger.info(`Sent meeting invite for game ${gameId} to opponent ${opponentId}`);
            return meetingInfo;

        } catch (error) {
            Logger.error('Failed to send meeting invite:', error);
            throw error;
        }
    }

    /**
     * Create formatted invite message
     */
    createInviteMessage(meetingInfo) {
        return `🎥 Video Call Invitation 🎥

I've created a Google Meet session for our game!

📹 Join here: ${meetingInfo.meetingUri}
🔢 Meeting ID: ${meetingInfo.meetingCode}

Let's chat while we play! Click the link or use the meeting ID to join.

This invitation was sent via Advanced OGS Client.`;
    }

    /**
     * Join a meeting (opens in new tab/window)
     */
    joinMeeting(gameId, autoJoin = false) {
        const meetingInfo = this.activeMeetings.get(gameId);
        if (!meetingInfo) {
            throw new Error('No meeting found for this game');
        }

        // Open Google Meet in new tab
        const meetWindow = window.open(
            meetingInfo.meetingUri,
            `meet-${gameId}`,
            'width=1200,height=800,scrollbars=yes,resizable=yes'
        );

        if (!meetWindow) {
            // Fallback: copy link to clipboard
            this.copyMeetingLink(meetingInfo.meetingUri);
            throw new Error('Popup blocked. Meeting link copied to clipboard.');
        }

        Logger.info(`Joined meeting for game ${gameId}`);
        return meetingWindow;
    }

    /**
     * Copy meeting link to clipboard
     */
    async copyMeetingLink(meetingUri) {
        try {
            await navigator.clipboard.writeText(meetingUri);
            Logger.info('Meeting link copied to clipboard');
            return true;
        } catch (error) {
            Logger.warning('Failed to copy to clipboard:', error);
            return false;
        }
    }

    /**
     * Parse meeting invitation from chat message
     */
    parseMeetingInvite(message) {
        // Look for Google Meet URLs or meeting IDs in messages
        const meetUriRegex = /https:\/\/meet\.google\.com\/[a-z-]+/i;
        const meetIdRegex = /Meeting ID:\s*([a-z-]{3}-[a-z]{4}-[a-z]{3})/i;

        const uriMatch = message.match(meetUriRegex);
        const idMatch = message.match(meetIdRegex);

        if (uriMatch || idMatch) {
            return {
                meetingUri: uriMatch ? uriMatch[0] : null,
                meetingId: idMatch ? idMatch[1] : null,
                isInvite: true
            };
        }

        return null;
    }

    /**
     * End a meeting space
     */
    async endMeeting(gameId) {
        try {
            const meetingInfo = this.activeMeetings.get(gameId);
            if (!meetingInfo) {
                Logger.warning(`No meeting found for game ${gameId}`);
                return;
            }

            // End the meeting space (if we have permission)
            if (this.accessToken) {
                await fetch(`${this.baseURL}/${meetingInfo.spaceId}:endActiveConference`, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${this.accessToken}`,
                        'Content-Type': 'application/json'
                    }
                });
            }

            // Clean up local state
            this.activeMeetings.delete(gameId);
            this.pendingInvites.delete(gameId);

            Logger.info(`Ended meeting for game ${gameId}`);

        } catch (error) {
            Logger.error('Failed to end meeting:', error);
            // Clean up anyway
            this.activeMeetings.delete(gameId);
            this.pendingInvites.delete(gameId);
        }
    }

    /**
     * Get meeting info for a game
     */
    getMeetingInfo(gameId) {
        return this.activeMeetings.get(gameId);
    }

    /**
     * Check if a game has an active meeting
     */
    hasMeeting(gameId) {
        return this.activeMeetings.has(gameId);
    }

    /**
     * Get all active meetings
     */
    getActiveMeetings() {
        return Array.from(this.activeMeetings.entries()).map(([gameId, info]) => ({
            gameId,
            ...info
        }));
    }

    /**
     * Clean up expired meetings
     */
    cleanupExpiredMeetings() {
        const now = new Date();
        const expireTime = 4 * 60 * 60 * 1000; // 4 hours

        for (const [gameId, meetingInfo] of this.activeMeetings.entries()) {
            if (now - meetingInfo.createdAt > expireTime) {
                Logger.info(`Cleaning up expired meeting for game ${gameId}`);
                this.activeMeetings.delete(gameId);
                this.pendingInvites.delete(gameId);
            }
        }
    }

    /**
     * Simple meeting creation without full OAuth (fallback)
     */
    createSimpleMeetingLink() {
        // Generate a random meeting room name
        const roomName = this.generateMeetingRoom();
        const meetingUri = `https://meet.google.com/${roomName}`;

        return {
            meetingUri,
            meetingCode: roomName,
            isSimple: true,
            createdAt: new Date()
        };
    }

    /**
     * Generate a meeting room name (for simple links)
     */
    generateMeetingRoom() {
        const chars = 'abcdefghijklmnopqrstuvwxyz';
        const part1 = Array(3).fill().map(() => chars[Math.floor(Math.random() * chars.length)]).join('');
        const part2 = Array(4).fill().map(() => chars[Math.floor(Math.random() * chars.length)]).join('');
        const part3 = Array(3).fill().map(() => chars[Math.floor(Math.random() * chars.length)]).join('');

        return `${part1}-${part2}-${part3}`;
    }

    /**
     * Create meeting with fallback to simple link
     */
    async createMeetingWithFallback(gameId, config = {}) {
        try {
            // Try full API first
            return await this.createMeetingSpace(gameId, config);
        } catch (error) {
            Logger.warning('Failed to create meeting via API, using simple link fallback:', error);

            // Fallback to simple meeting link
            const meetingInfo = this.createSimpleMeetingLink();
            meetingInfo.gameId = gameId;

            this.activeMeetings.set(gameId, meetingInfo);
            return meetingInfo;
        }
    }

    /**
     * Get meeting button state for UI
     */
    getMeetingButtonState(gameId) {
        const meetingInfo = this.activeMeetings.get(gameId);

        if (!meetingInfo) {
            return {
                text: '📹 Start Google Meet',
                action: 'create',
                disabled: false
            };
        }

        return {
            text: '📹 Join Meeting',
            action: 'join',
            disabled: false,
            meetingInfo
        };
    }
}

// Export for web usage
window.GoogleMeetIntegration = GoogleMeetIntegration;