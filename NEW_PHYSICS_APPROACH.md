# New Physics Approach: Photo-Based Stone Placement

## Concept
Instead of calculating physics for stone placement in bowls, use pre-captured positions from actual photos of stones in bowls.

## The Matrix Structure
```
Variation 1: [positions for 1 stone, 2 stones, ... 10+ stones]
Variation 2: [positions for 1 stone, 2 stones, ... 10+ stones]
...
Variation 5-10: [same structure]
```

Total: 5-10 variations × 10+ stone counts = 50-100 position sets

## Runtime Behavior
1. Pick a variation (randomly or sequentially)
2. Look up position array for current capture count
3. Apply random rotation (0-360°) to entire set
4. Optional: add small random jitter (±2-3 pixels)
5. Place/animate stones to those positions

## Why This is Better Than Physics
- **Predictable & Aesthetic** - Exact control over appearance
- **Performance** - Simple lookup vs complex physics calculations
- **Artist-Controlled** - Real bowls with real stones
- **No Edge Cases** - No weird physics behavior

## Photo Capture Requirements

### Stone Color
- **Black stones preferred** (higher contrast, easier detection)
- Use white stones if bowl is dark
- Key: maximum contrast between stones and bowl

### Photo Setup
- Top-down angle (camera directly above bowl)
- Even lighting (avoid harsh shadows/glare)
- Consistent background (same bowl for each sequence)
- Clear focus (sharp stone edges)
- High resolution

### Helpful Markings
- **Center point mark** (small dot/crosshair at bowl center) - MOST IMPORTANT
- Optional: Radius reference (mark the edge/rim)
- Rotation reference not needed (we randomize rotation anyway)

## Photo Collection Process
For each variation (5-10 total):
- Photo 1: 1 stone in bowl
- Photo 2: 2 stones in bowl
- Photo 3: 3 stones in bowl
- ...
- Photo 10+: 10+ stones in bowl

## Analysis Output
Computer vision will extract:
- (x, y) coordinates for each stone
- Normalized to bowl center/radius (0.0 - 1.0 range)
- Output as JSON or Swift data structure

## Data Structure (Proposed)
```swift
struct BowlLayout {
    let stonePositions: [[CGPoint]]  // Index = number of stones - 1
    let bowlRadius: CGFloat
}

// Separate layouts for black and white bowls
let blackBowlLayouts: [BowlLayout] = [...]
let whiteBowlLayouts: [BowlLayout] = [...]
```

## Implementation Steps
1. Build position extraction tool (analyze photos → extract positions)
2. Create data structures to store positions
3. Integrate with existing bowl rendering code
4. Add rotation and optional jitter at runtime

## Variation Math
- 10 base sequences
- × 360° rotation possibilities
- × optional small jitter
- = effectively infinite perceived variation

## Next Steps
- [ ] Take first test sequence (10 photos)
- [ ] Build/test position extraction tool
- [ ] Validate output format
- [ ] Extend to multiple variations
- [ ] Integrate with existing codebase
