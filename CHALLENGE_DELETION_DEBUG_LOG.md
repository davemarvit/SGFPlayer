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

## Current Understanding (as of v3.81)

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

## Next Steps to Try

### Test Priority 1: Simpler Challenge Settings
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
