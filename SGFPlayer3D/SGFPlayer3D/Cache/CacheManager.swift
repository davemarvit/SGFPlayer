// MARK: - Cache Management System
// Clean separation of caching concerns with proper invalidation

import Foundation

/// Game stone type (avoiding conflict with physics Stone)
enum GameStone: Equatable {
    case black, white
}

/// Represents cached stone layout for a specific game move
struct CachedLayout {
    let blackStones: [StonePosition]
    let whiteStones: [StonePosition]
    let physicsModel: String // Which physics model generated this layout
    let timestamp: Date
    
    init(blackStones: [StonePosition], whiteStones: [StonePosition], physicsModel: String) {
        self.blackStones = blackStones
        self.whiteStones = whiteStones
        self.physicsModel = physicsModel
        self.timestamp = Date()
    }
}

/// Centralized cache management with proper invalidation
class CacheManager: ObservableObject {
    
    // Stone position cache keyed by move index
    private var layoutCache: [Int: CachedLayout] = [:]
    
    // Stone count cache keyed by move index
    private var tallyCache: [Int: (whiteByBlack: Int, blackByWhite: Int)] = [:]
    
    // Board state cache keyed by move index
    private var gridCache: [Int: [[GameStone?]]] = [:]
    
    // Current physics model for cache validation
    private var currentPhysicsModel: String = ""
    
    /// Clear all caches (used when physics model changes)
    func clearAll(reason: String) {
        layoutCache.removeAll()
        tallyCache.removeAll()
        gridCache.removeAll()
        print("🔄 CacheManager: Cleared all caches - \(reason)")
    }
    
    /// Clear caches if physics model changed
    func validatePhysicsModel(_ newModel: String) {
        if currentPhysicsModel != newModel {
            let oldModel = currentPhysicsModel.isEmpty ? "none" : currentPhysicsModel
            currentPhysicsModel = newModel
            clearAll(reason: "Physics model changed from \(oldModel) to \(newModel)")
        }
    }
    
    /// Initialize cache with base state
    func initializeWithBaseState(grid: [[GameStone?]]) {
        tallyCache[0] = (0, 0)
        gridCache[0] = grid
        layoutCache[0] = CachedLayout(blackStones: [], whiteStones: [], physicsModel: currentPhysicsModel)
        print("🔄 CacheManager: Initialized with base state")
    }
    
    // MARK: - Layout Cache
    
    func getCachedLayout(forMove move: Int) -> CachedLayout? {
        guard let layout = layoutCache[move] else { return nil }
        
        // Validate that the cached layout was generated with current physics model
        if layout.physicsModel != currentPhysicsModel {
            layoutCache.removeValue(forKey: move)
            print("🔄 CacheManager: Invalidated stale layout cache for move \(move) (was \(layout.physicsModel), now \(currentPhysicsModel))")
            return nil
        }
        
        return layout
    }
    
    func setCachedLayout(_ layout: CachedLayout, forMove move: Int) {
        layoutCache[move] = layout
        print("🔄 CacheManager: Cached layout for move \(move) with \(layout.physicsModel)")
    }
    
    // MARK: - Tally Cache
    
    func getCachedTally(forMove move: Int) -> (whiteByBlack: Int, blackByWhite: Int)? {
        return tallyCache[move]
    }
    
    func setCachedTally(_ tally: (whiteByBlack: Int, blackByWhite: Int), forMove move: Int) {
        tallyCache[move] = tally
    }
    
    // MARK: - Grid Cache
    
    func getCachedGrid(forMove move: Int) -> [[GameStone?]]? {
        return gridCache[move]
    }
    
    func setCachedGrid(_ grid: [[GameStone?]], forMove move: Int) {
        gridCache[move] = grid
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStats() -> String {
        return "Layouts: \(layoutCache.count), Tallies: \(tallyCache.count), Grids: \(gridCache.count)"
    }
    
    var hasCachedLayout: (Int) -> Bool {
        return { move in
            self.getCachedLayout(forMove: move) != nil
        }
    }
}