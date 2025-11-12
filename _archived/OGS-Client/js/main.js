/**
 * Main Application Entry Point
 * Initializes the Advanced OGS Client
 */

console.log('=== main.js loaded ===');

// Global application instance
let app = null;

// Initialize application when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    console.log('DOMContentLoaded event fired, calling initializeApp()');
    initializeApp();
});

async function initializeApp() {
    try {
        console.log('initializeApp() called');
        Logger.info('🚀 Starting Advanced OGS Client...');

        // Create main application controller
        console.log('Creating AppController...');
        app = new AppController();
        console.log('AppController created:', app);

        // Store global reference for debugging
        window.app = app;

        Logger.info('✅ Advanced OGS Client initialized successfully');

        // Show version info in console
        console.log(`
╔══════════════════════════════════════════════════════════════╗
║                    Advanced OGS Client                       ║
║                                                              ║
║  🎮 Enhanced Go experience with beautiful boards             ║
║  📹 Google Meet integration for video calls                 ║
║  🎨 Adapted from SGFPlayer with stone jitter & physics      ║
║                                                              ║
║  Built with modern web technologies and OGS APIs            ║
╚══════════════════════════════════════════════════════════════╝
        `);

    } catch (error) {
        Logger.error('Failed to initialize application:', error);
        showCriticalError(error);
    }
}

function showCriticalError(error) {
    // Create error overlay
    const errorOverlay = document.createElement('div');
    errorOverlay.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100vw;
        height: 100vh;
        background: linear-gradient(135deg, #e53e3e, #c53030);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 10000;
        color: white;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
    `;

    errorOverlay.innerHTML = `
        <div style="text-align: center; max-width: 500px; padding: 2rem;">
            <div style="font-size: 3rem; margin-bottom: 1rem;">⚠️</div>
            <h1 style="margin-bottom: 1rem;">Application Failed to Start</h1>
            <p style="margin-bottom: 2rem; opacity: 0.9;">
                ${error.message || 'An unexpected error occurred during initialization.'}
            </p>
            <button onclick="location.reload()" style="
                background: white;
                color: #e53e3e;
                border: none;
                padding: 0.75rem 2rem;
                border-radius: 8px;
                font-weight: 600;
                cursor: pointer;
                font-size: 1rem;
            ">
                Reload Application
            </button>
        </div>
    `;

    document.body.appendChild(errorOverlay);
}

// Global error handling
window.addEventListener('error', (event) => {
    Logger.error('Uncaught error:', event.error);
});

window.addEventListener('unhandledrejection', (event) => {
    Logger.error('Unhandled promise rejection:', event.reason);
});

// Performance monitoring
if (window.performance && window.performance.mark) {
    window.performance.mark('app-start');

    window.addEventListener('load', () => {
        window.performance.mark('app-loaded');

        if (window.performance.measure) {
            window.performance.measure('app-load-time', 'app-start', 'app-loaded');

            const loadTime = window.performance.getEntriesByName('app-load-time')[0];
            Logger.info(`📊 App load time: ${Math.round(loadTime.duration)}ms`);
        }
    });
}

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
    // Only handle shortcuts when app is ready
    if (!app || !app.isUserAuthenticated()) return;

    // Ctrl/Cmd + shortcuts
    if (e.ctrlKey || e.metaKey) {
        switch (e.key) {
            case '1':
                e.preventDefault();
                app.switchView('lobby');
                break;
            case '2':
                e.preventDefault();
                app.switchView('games');
                break;
            case '3':
                e.preventDefault();
                app.switchView('observe');
                break;
            case '4':
                e.preventDefault();
                app.switchView('tournaments');
                break;
        }
    }

    // Escape key
    if (e.key === 'Escape') {
        // Close modals
        document.querySelectorAll('.modal:not(.hidden)').forEach(modal => {
            modal.classList.add('hidden');
        });
    }
});

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    if (app) {
        // Disconnect from OGS gracefully
        const ogsClient = app.getOGSClient();
        if (ogsClient && ogsClient.isConnected) {
            ogsClient.disconnect();
        }

        // Clean up game controller
        if (app.gameController) {
            app.gameController.cleanup();
        }

        Logger.info('🛑 Application shutting down');
    }
});

// Service Worker registration (for future PWA features)
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        // Note: You would need to create a service worker file
        // navigator.serviceWorker.register('/sw.js')
        //     .then(registration => {
        //         Logger.info('SW registered:', registration);
        //     })
        //     .catch(registrationError => {
        //         Logger.warning('SW registration failed:', registrationError);
        //     });
    });
}

// Debugging utilities (development only)
if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    // Add debug utilities to global scope
    window.debug = {
        getApp: () => app,
        getOGS: () => app?.getOGSClient(),
        getEngine: () => app?.getGameEngine(),
        getMeet: () => app?.getMeetIntegration(),

        // Test functions
        testSGFParser: (sgfText) => {
            try {
                const tree = SGFParser.parse(sgfText);
                const game = SGFGame.from(tree);
                console.log('Parsed SGF:', { tree, game });
                return { tree, game };
            } catch (error) {
                console.error('SGF parsing failed:', error);
            }
        },

        testBoardRenderer: () => {
            const canvas = document.getElementById('go-board');
            if (canvas) {
                const renderer = new BoardRenderer(canvas);
                console.log('Board renderer:', renderer);
                return renderer;
            }
        },

        simulateGame: async () => {
            // Simulate a simple game for testing
            const engine = app?.getGameEngine();
            if (!engine) return;

            const moves = [
                { stone: Stone.BLACK, coord: { x: 3, y: 3 } },
                { stone: Stone.WHITE, coord: { x: 3, y: 4 } },
                { stone: Stone.BLACK, coord: { x: 4, y: 3 } },
                { stone: Stone.WHITE, coord: { x: 4, y: 4 } }
            ];

            const game = new SGFGame();
            game.moves = moves;

            engine.load(game);
            engine.play();
        }
    };

    Logger.info('🔧 Debug utilities available in window.debug');
}

// Export for potential module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { initializeApp };
}