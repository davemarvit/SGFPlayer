/**
 * SGF Parser - Direct port from SGFPlayer Swift code
 * Lightweight SGF AST (MVP: flattens to the main line; ignores variations)
 */

class SGFError extends Error {
    constructor(message) {
        super(message);
        this.name = 'SGFError';
    }
}

class SGFNode {
    constructor(props = {}) {
        this.props = props;
    }
}

class SGFTree {
    constructor(nodes = []) {
        this.nodes = nodes;
    }
}

class SGFParser {
    static parse(text) {
        // Normalize line endings
        const s = text.replace(/\r/g, '');
        let i = 0;

        function peek() {
            return i < s.length ? s[i] : null;
        }

        function advance() {
            if (i < s.length) i++;
        }

        function skipWhitespace() {
            while (peek() && /\s/.test(peek())) {
                advance();
            }
        }

        const nodes = [];
        skipWhitespace();

        if (peek() !== '(') {
            throw new SGFError("Missing '(' at start");
        }

        consumeSubtree(); // parse the outer tree, collecting the main line nodes
        return new SGFTree(nodes);

        function consumeSubtree() {
            if (peek() !== '(') {
                throw new SGFError("Expected '('");
            }
            advance(); // '('
            skipWhitespace();

            while (peek()) {
                const c = peek();
                if (c === ';') {
                    advance();
                    nodes.push(parseNode());
                    skipWhitespace();
                } else if (c === '(') {
                    skipSubtree(); // skip variation
                    skipWhitespace();
                } else if (c === ')') {
                    advance();
                    break;
                } else {
                    advance(); // tolerate junk
                }
            }
        }

        function parseNode() {
            const props = {};
            skipWhitespace();

            while (peek() && /[a-zA-Z]/.test(peek())) {
                const key = parseIdent();
                const values = [];
                skipWhitespace();

                while (peek() === '[') {
                    values.push(parseValue());
                    skipWhitespace();
                }

                if (values.length > 0) {
                    if (!props[key]) props[key] = [];
                    props[key].push(...values);
                }
                skipWhitespace();
            }

            return new SGFNode(props);
        }

        function parseIdent() {
            const start = i;
            while (peek() && /[a-zA-Z]/.test(peek())) {
                advance();
            }
            return s.substring(start, i).toUpperCase();
        }

        function parseValue() {
            if (peek() !== '[') {
                throw new SGFError("Expected '['");
            }
            advance(); // '['

            let out = '';
            while (peek()) {
                const c = peek();
                advance();
                if (c === '\\') {
                    if (peek()) {
                        out += peek();
                        advance();
                    }
                } else if (c === ']') {
                    break;
                } else {
                    out += c;
                }
            }
            return out;
        }

        function skipSubtree() {
            if (peek() !== '(') return;
            advance();
            let depth = 0;

            while (peek()) {
                const c = peek();
                advance();
                if (c === '(') {
                    depth++;
                } else if (c === ')') {
                    if (depth === 0) {
                        break;
                    } else {
                        depth--;
                    }
                }
            }
        }
    }
}

// Stone types
const Stone = {
    BLACK: 'black',
    WHITE: 'white'
};

class SGFGame {
    constructor() {
        this.boardSize = 19;
        this.info = {
            event: null,
            playerBlack: null,
            playerWhite: null,
            result: null,
            date: null
        };
        this.setup = []; // [{stone: Stone, x: number, y: number}]
        this.moves = []; // [{stone: Stone, coord: {x: number, y: number} | null}] (null = pass)
    }

    static from(tree) {
        const game = new SGFGame();

        for (const node of tree.nodes) {
            for (const [k, vals] of Object.entries(node.props)) {
                switch (k) {
                    case 'SZ':
                        if (vals[0]) {
                            const v = vals[0];
                            if (v.includes(':')) {
                                const [left, right] = v.split(':').map(s => parseInt(s) || 19);
                                game.boardSize = Math.max(2, Math.min(25, Math.min(left, right)));
                            } else {
                                const sz = parseInt(v) || 19;
                                game.boardSize = Math.max(2, Math.min(25, sz));
                            }
                        }
                        break;
                    case 'EV':
                        game.info.event = vals[0];
                        break;
                    case 'PB':
                        game.info.playerBlack = vals[0];
                        break;
                    case 'PW':
                        game.info.playerWhite = vals[0];
                        break;
                    case 'RE':
                        game.info.result = vals[0];
                        break;
                    case 'DT':
                        game.info.date = vals[0];
                        break;
                    case 'AB':
                        for (const v of vals) {
                            const coord = parseCoord(v);
                            if (coord) {
                                game.setup.push({stone: Stone.BLACK, x: coord.x, y: coord.y});
                            }
                        }
                        break;
                    case 'AW':
                        for (const v of vals) {
                            const coord = parseCoord(v);
                            if (coord) {
                                game.setup.push({stone: Stone.WHITE, x: coord.x, y: coord.y});
                            }
                        }
                        break;
                    case 'B':
                        const bCoord = parseCoord(vals[0] || '');
                        game.moves.push({stone: Stone.BLACK, coord: bCoord});
                        break;
                    case 'W':
                        const wCoord = parseCoord(vals[0] || '');
                        game.moves.push({stone: Stone.WHITE, coord: wCoord});
                        break;
                }
            }
        }

        return game;
    }
}

// SGF coords: two lowercase letters; 'aa' => (0,0). Empty => pass.
function parseCoord(s) {
    if (!s) return null; // pass
    if (s.length !== 2) return null;

    const x = s.charCodeAt(0) - 97; // 'a' = 97
    const y = s.charCodeAt(1) - 97;

    if (x < 0 || y < 0) return null;
    return {x, y};
}

// Export for web usage
window.SGFParser = SGFParser;
window.SGFGame = SGFGame;
window.SGFError = SGFError;
window.Stone = Stone;