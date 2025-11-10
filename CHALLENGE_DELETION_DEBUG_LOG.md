# OGS Challenge Deletion Debugging Log

**Problem:** Challenges created via REST API appear successfully but are deleted by server after 6-9 seconds.

**Current Status:** v3.81 (reverted v3.82 as incorrect)

---

## Test History & Hypotheses Eliminated

### v3.74 - WebSocket Subscription Hypothesis
**Hypothesis:** Challenges deleted because no WebSocket subscription to game
**Test:** Subscribe to game via WebSocket after creating challenge
**Result:** ❌ FAILED - Challenges still deleted
**Eliminated:** Server doesn't require WebSocket subscription to keep challenges alive

---

### v3.75 - Seekgraph Health Monitoring
**Hypothesis:** Seekgraph subscription silently dying
**Test:** Add health monitoring, auto-resubscribe if stale
**Result:** ℹ️ INFRASTRUCTURE - Not directly related to deletion issue
**Note:** Improved reliability of seeing challenge updates

---

### v3.76 - First rengo_casual_mode Test
**Hypothesis:** `rengo_casual_mode: true` causing deletion
**Test:** Changed `rengo_casual_mode` from `true` to `false`
**Result:** ❌ FAILED - Challenges still deleted
**Eliminated:** Setting it to `false` doesn't help

---

### v3.77 - Enhanced Logging
**Hypothesis:** Delete message contains error/reason
**Test:** Added detailed logging of DELETE payload
**Result:** ℹ️ DATA GATHERING - Delete payload shows: `{"delete": 1, "challenge_id": <id>}`
**Finding:** No error message or reason provided by server

---

### v3.78 - Corrected rengo_casual_mode
**Hypothesis:** v3.76 was wrong, should actually be `true`
**Test:** Changed `rengo_casual_mode` back to `true` (matches browser)
**Result:** ✅ CORRECT SETTING - Browser uses `true`, this matches browser behavior
**Confirmed:** `rengo_casual_mode: true` is the CORRECT setting for non-rengo games
**Note:** Challenges still deleted, but this setting is definitively correct

---

### v3.79 - Cookie Header Investigation
**Hypothesis:** Cookies not being sent in request
**Test:** Added comprehensive header/cookie logging
**Result:** 🔍 DISCOVERY - Cookie header was NOT being sent!
**Finding:**
- Both csrftoken and sessionid cookies exist in HTTPCookieStorage ✅
- X-CSRFToken, Referer, Origin headers being sent ✅
- **Cookie header was missing** ❌

---

### v3.80 - Manual Cookie Header
**Hypothesis:** Missing Cookie header causing deletion
**Test:** Manually construct and set Cookie header from HTTPCookieStorage
**Result:** ⚠️ PARTIAL SUCCESS
**Confirmed Working:**
- Cookie header now sent: `Cookie: csrftoken=...; sessionid=...` ✅
- Challenge creates successfully (HTTP 200) ✅
- Challenge appears in seekgraph ✅
**Still Failing:**
- Challenge deleted after 6-9 seconds ❌

---

### v3.81 - Referer Path & User-Agent Headers
**Hypothesis:** Missing Referer path or User-Agent causing deletion
**Test:**
1. Changed Referer from `https://online-go.com` to `https://online-go.com/play`
2. Added User-Agent header to match Safari browser
**Result:** ⚠️ NO CHANGE
**Confirmed Working:**
- All headers now match browser (Cookie, Referer with /play, User-Agent) ✅
- Challenge creates successfully (HTTP 200) ✅
- Challenge appears in seekgraph ✅
**Still Failing:**
- Challenge deleted after 6-9 seconds ❌

---

### v3.82 - INCORRECT (Reverted)
**Hypothesis:** Changed `rengo_casual_mode` to `false` again
**Result:** ❌ MISTAKE - This contradicts v3.78 findings
**Action:** Immediately reverted
**Note:** This was going in circles - v3.78 already proved this wrong

---

### v3.83 - CRITICAL DISCOVERY: Wrong WebSocket URL + challenge/keepalive!
**Hypothesis:** App connecting to wrong WebSocket server
**Investigation:** Captured browser WebSocket connections in Dev Tools Network tab
**Result:** 🎯 **ROOT CAUSE IDENTIFIED!**

**Discovery 1: Wrong WebSocket Server**
Browser uses **completely different WebSocket URL** than app:
- **Browser:** `wss://wsp.online-go.com/` (still Socket.io format!)
- **App:** `wss://online-go.com/socket.io/?EIO=3&transport=websocket` (Socket.io/Engine.IO v3)

**Discovery 2: challenge/keepalive Messages Required!**
After creating a challenge, browser sends:
1. **Immediate:** `["game/connect", {"game_id": 81105931}]` right after challenge creation
2. **Every ~2 seconds:** `["challenge/keepalive", {"challenge_id": 3411893, "game_id": 81105931}]`

**Keepalive Pattern Observed:**
- 12:30:23 - Challenge created
- 12:30:23 - `game/connect` sent immediately
- 12:30:24 - First keepalive (1 second after creation)
- 12:30:25 - Second keepalive (2 seconds)
- 12:30:27 - Third keepalive (4 seconds)
- 12:30:29 - Fourth keepalive (6 seconds)
- Continues every ~2 seconds...

**This explains EVERYTHING:**
- ✅ Why all HTTP headers are correct but challenges still deleted
- ✅ Why challenge appears in seekgraph but gets deleted
- ✅ Why v3.74 game subscription didn't work (wrong WebSocket server!)
- ✅ Why no error message is sent (server can't find client on correct WebSocket)
- ✅ The 6-9 second timeout (server waits for keepalives on `wsp.online-go.com`, doesn't get them, deletes challenge)

**Evidence:**
- Browser Network tab shows connection to `wss://wsp.online-go.com/`
- App code at OGSClient.swift:182 connects to `wss://online-go.com/socket.io/...`
- Browser sends `game/connect` + periodic `challenge/keepalive` messages
- Messages still use Socket.io format: `["event", {data}]`

---

### v3.84 - Fix WebSocket URL + Implement challenge/keepalive
**Hypothesis:** Connecting to correct WebSocket and sending keepalives will prevent deletion
**Implementation:**
1. Change WebSocket URL to `wss://wsp.online-go.com/`
2. Send `["game/connect", {"game_id": <id>}]` immediately after challenge creation
3. Start timer sending `["challenge/keepalive", {"challenge_id": <id>, "game_id": <id>}]` every 2 seconds
4. Stop timer when challenge is accepted or cancelled

**Expected Result:** ✅ Challenges should persist until accepted or cancelled by user

---

## Current Understanding (as of v3.83)

### ✅ Confirmed Working / Correct
1. **Cookie Header**: Both csrftoken and sessionid sent correctly
2. **CSRF Token**: X-CSRFToken header sent correctly
3. **Referer**: `https://online-go.com/play` (matches browser)
4. **Origin**: `https://online-go.com` (matches browser)
5. **User-Agent**: Safari user agent string sent
6. **rengo_casual_mode**: Set to `true` (correct for non-rengo games)
7. **Challenge Creation**: HTTP 200 response, valid challenge_id and game_id returned
8. **Seekgraph Visibility**: Challenge appears in seekgraph immediately

### ❌ Still Failing
- **Challenge Deletion**: Server sends DELETE message 6-9 seconds after creation
- **No Error Message**: DELETE payload contains no reason or error field

### 🤔 Not Yet Tested
1. **Request Body Differences**: Are there other fields in the JSON body that differ from browser?
2. **Challenge Parameters**: Does the combination of settings matter?
   - Ranked: true, Handicap: 9, Rank range: 0-36
   - Is this combination invalid for a 2k player?
3. **Simpler Test Cases**:
   - Unranked game instead of ranked?
   - No handicap (automatic handicap: -1)?
   - Restricted rank range instead of 0-36?
4. **Other Headers**: Are there any other headers browsers send that we're missing?
5. **Session State**: Is there something about the session state or timing?

---

## NEW HYPOTHESIS: Challenge Keep-Alive Mechanism

**Theory (Nov 9, 2025):**
Browser clients may send periodic WebSocket messages to keep challenges alive. This would make sense for OGS's design:
- If someone creates a challenge and closes their browser, the challenge shouldn't persist forever
- Server likely expects some kind of periodic "I'm still here" message
- After 6-9 seconds without this message, server deletes the challenge

**Evidence:**
- v3.74 tried subscribing to the GAME (game/connect, spectate) but this didn't work
- This is logical because a challenge isn't a game yet - it only becomes a game when accepted
- Ping/pong exists for WebSocket-level keep-alive, but there might be an application-level keep-alive for challenges specifically

**What We Don't Know:**
- Does browser send any WebSocket messages after creating a challenge?
- Is there a "challenge/connect" or similar subscription message?
- Is there a periodic keep-alive message sent every few seconds?

**How to Test:**
1. **Browser WebSocket Traffic Capture:**
   - Create challenge in browser
   - Use browser dev tools → Network → WS (WebSocket tab)
   - Watch what messages are sent AFTER the challenge appears
   - Look for any periodic messages or challenge-specific subscriptions

2. **Message Pattern Analysis:**
   - Identify if there's a pattern like "every 5 seconds send X message"
   - Check if there's an acknowledgment when the challenge appears in seekgraph
   - Look for any "challenge/XXX" type messages

**This could explain:**
- ✅ Why challenge creates successfully
- ✅ Why it appears in seekgraph
- ✅ Why all headers are correct but it still fails
- ✅ Why it's deleted after exactly 6-9 seconds (a timeout period)
- ✅ Why no error message is sent (it's not an error, just a timeout)

---

## Next Steps to Try

### Test Priority 1: Change WebSocket URL to wsp.online-go.com **[HIGHEST PRIORITY - ROOT CAUSE]**
**Rationale:** Browser uses `wss://wsp.online-go.com/`, app uses wrong URL

**What to Change:**
Location: `OGSClient.swift:182`
```swift
// OLD (WRONG):
guard let url = URL(string: "wss://online-go.com/socket.io/?EIO=3&transport=websocket") else {

// NEW (CORRECT):
guard let url = URL(string: "wss://wsp.online-go.com/") else {
```

**CRITICAL CONSIDERATIONS:**
1. **Protocol Change:** `wsp.online-go.com` appears to use **plain WebSocket**, NOT Socket.io
   - Socket.io messages like `42["seekgraph/subscribe",...]` may not work
   - May need to use plain WebSocket JSON messages instead
2. **Message Format:** Need to understand what `wsp.online-go.com` expects
3. **Backwards Compatibility:** Will this break existing game functionality?

**Before Making Changes:**
- First, capture messages from browser's `wsp.online-go.com` connection to understand protocol
- Look at initial handshake, message format, seekgraph subscription format
- See if it's plain WebSocket or still some variant of Socket.io

### Test Priority 2: Investigate wsp.online-go.com Protocol **[DO THIS FIRST]**
**Rationale:** Need to understand message format before changing code

**Method:**
1. Browser Dev Tools → Network → WS tab → Click on `wsp.online-go.com` connection
2. Look at "Messages" tab
3. Capture:
   - Initial handshake/connection messages
   - What gets sent when subscribing to seekgraph
   - What format messages use (JSON? Socket.io protocol?)
   - Any challenge-related messages
4. This will tell us if we need major refactoring or just URL change

### Test Priority 2: Simpler Challenge Settings
**Rationale:** Current test uses potentially invalid combination (rank 27 creating ranked game with 9-stone handicap for any rank)

**Test A: Unranked Game**
```
ranked: false
handicap: -1 (automatic)
rank range: 0-36
```

**Test B: No Handicap**
```
ranked: true
handicap: -1 (automatic, not fixed 9 stones)
rank range: 0-36
```

**Test C: Restricted Rank Range**
```
ranked: true
handicap: -1 (automatic)
rank range: 24-30 (around user's rank)
```

### Test Priority 2: Full Browser Request Comparison
**Rationale:** Capture exact browser request and compare all fields

**Method:**
1. Use browser dev tools to capture complete POST request for challenge creation
2. Compare EVERY field in request body with what app sends
3. Look for any differences in JSON structure, field ordering, or values

### Test Priority 3: Session/Timing Investigation
**Rationale:** Could be related to session age or request timing

**Questions:**
- Does a fresh login vs existing session matter?
- Does waiting after login before creating challenge matter?
- Are there rate limits being hit?

---

## Known Issues / Contradictions

None identified yet. All test results are consistent.

---

## Test Template for Future Versions

```markdown
### vX.XX - [Hypothesis Name]
**Hypothesis:** [What you think is causing the issue]
**Test:** [What you changed to test it]
**Result:** [✅/❌/⚠️/ℹ️] [Outcome]
**Eliminated/Confirmed:** [What this proves or disproves]
```

---

## Log Update Instructions

After each test:
1. Add new version section with hypothesis and results
2. Update "Current Understanding" section
3. Update "Next Steps to Try" with new ideas
4. Note any contradictions discovered
