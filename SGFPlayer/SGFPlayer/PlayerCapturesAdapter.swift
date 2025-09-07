// MARK: - File: PlayerCapturesAdapter.swift
import Foundation
import SwiftUI

/// Light adapter that can be expanded later. Right now ContentView only calls `refresh`.
final class PlayerCapturesAdapter: ObservableObject {

    // If you later want to bind bowls to UI, publish these:
    @Published var stonesUL: [BowlView.LidStone] = []   // white stones captured by Black (upper-left lid)
    @Published var stonesLR: [BowlView.LidStone] = []   // black stones captured by White (lower-right lid)

    // Internal state to avoid redundant work
    private var lastMoveIndex: Int = -1
    private var gameSeed: UInt64 = 0

    /// Rebuild any internal state for the current move/game. Safe to call often.
    func refresh(using player: SGFPlayer, gameFingerprint: String) {
        // Update seed whenever the game changes (simple stable hash)
        let newSeed = Self.hash64(gameFingerprint)
        if newSeed != gameSeed {
            gameSeed = newSeed
            lastMoveIndex = -1
        }

        // Only recompute once per move index
        let idx = player.currentIndex
        guard idx != lastMoveIndex else { return }
        lastMoveIndex = idx

        // NOTE:
        // We’re not deriving captured counts here because ContentView already computes/animates
        // bowl stones on each capture. If/when you want this adapter to be the single source of truth,
        // move that logic here and bind ContentView to `stonesUL` / `stonesLR`.
    }

    // MARK: - Utilities

    /// Very small stable 64-bit hash (FNV-1a variant) for deterministic seeding.
    private static func hash64(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        for b in s.utf8 {
            hash ^= UInt64(b)
            hash &*= prime
        }
        return hash
    }
}
