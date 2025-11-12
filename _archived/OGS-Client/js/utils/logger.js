/**
 * Logger utility - Adapted from SGFPlayer
 */
class Logger {
    static LOG_LEVELS = {
        DEBUG: 0,
        INFO: 1,
        WARNING: 2,
        ERROR: 3
    };

    static currentLevel = Logger.LOG_LEVELS.INFO;
    static enableTimestamps = true;

    static setLevel(level) {
        this.currentLevel = level;
    }

    static debug(message, ...args) {
        this._log(this.LOG_LEVELS.DEBUG, '🔍', message, ...args);
    }

    static info(message, ...args) {
        this._log(this.LOG_LEVELS.INFO, 'ℹ️', message, ...args);
    }

    static warning(message, ...args) {
        this._log(this.LOG_LEVELS.WARNING, '⚠️', message, ...args);
    }

    static error(message, ...args) {
        this._log(this.LOG_LEVELS.ERROR, '❌', message, ...args);
    }

    static _log(level, icon, message, ...args) {
        if (level < this.currentLevel) return;

        const timestamp = this.enableTimestamps ?
            `[${new Date().toISOString().substr(11, 12)}]` : '';

        const logFunction = level >= this.LOG_LEVELS.ERROR ? console.error :
                           level >= this.LOG_LEVELS.WARNING ? console.warn :
                           console.log;

        logFunction(`${timestamp} ${icon} ${message}`, ...args);
    }

    static group(title, fn) {
        console.group(title);
        try {
            fn();
        } finally {
            console.groupEnd();
        }
    }

    static time(label) {
        console.time(label);
    }

    static timeEnd(label) {
        console.timeEnd(label);
    }
}

// Set debug level in development
if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    Logger.setLevel(Logger.LOG_LEVELS.DEBUG);
}

window.Logger = Logger;