import Testing
import SwiftUI
@testable import MatchThree

// MARK: - Test helpers

private func gem(_ name: String) -> Gem {
    Gem(kind: GemKind.normalKinds.first { $0.name == name } ?? .rainbow)
}

/// Build an 8×8 grid from a compact row-of-strings layout.
/// "." = empty, any other char maps via `names`.
private func makeGrid(_ rows: [String], names: [Character: String]) -> [[Gem?]] {
    var g = Array(repeating: Array(repeating: nil as Gem?, count: 8), count: 8)
    for (r, row) in rows.enumerated() {
        for (c, ch) in row.enumerated() where ch != "." {
            g[r][c] = gem(names[ch]!)
        }
    }
    return g
}

// MARK: - findMatches

@MainActor
struct FindMatchesTests {

    @Test func noMatchesOnCleanBoard() async throws {
        // Every row/col alternates so no 3-in-a-row exists.
        let layout = ["rgrgrgrg", "grgrgrgr", "rgrgrgrg", "grgrgrgr",
                      "rgrgrgrg", "grgrgrgr", "rgrgrgrg", "grgrgrgr"]
        let names: [Character: String] = ["r": "ruby", "g": "emerald"]
        let board = GameBoard()
        board.loadGrid(makeGrid(layout, names: names))
        let matches = board.findMatches()
        #expect(matches == nil || matches?.isEmpty == true)
    }

    @Test func detectsHorizontalTriple() async throws {
        // Row 0: three rubies in a row (cols 0-2), rest alternating.
        let layout = ["rrrg....", "g.g.g.g.", "r.r.r.r.", "g.g.g.g.",
                      "r.r.r.r.", "g.g.g.g.", "r.r.r.r.", "g.g.g.g."]
        let names: [Character: String] = ["r": "ruby", "g": "emerald"]
        let board = GameBoard()
        board.loadGrid(makeGrid(layout, names: names))
        let matches = try #require(board.findMatches())
        let totalPositions = matches.reduce(0) { $0 + $1.positions.count }
        #expect(totalPositions >= 3)
    }

    @Test func detectsVerticalTriple() async throws {
        // Col 0: three sapphires in a column (rows 0-2).
        let layout = ["s.s.s.s.", "s.s.s.s.", "s.s.s.s.", "e.e.e.e.",
                      "s.s.s.s.", "e.e.e.e.", "s.s.s.s.", "e.e.e.e."]
        let names: [Character: String] = ["s": "sapphire", "e": "emerald"]
        let board = GameBoard()
        board.loadGrid(makeGrid(layout, names: names))
        let matches = try #require(board.findMatches())
        let totalPositions = matches.reduce(0) { $0 + $1.positions.count }
        #expect(totalPositions >= 3)
    }
}

// MARK: - gravity

@MainActor
struct GravityTests {

    @Test func gemsFallToFillGaps() async throws {
        // Col 0: sapphire at row 0, then empty, empty, emerald at row 3.
        // After gravity: sapphire lands at row 1, emerald stays at row 0...
        // actually gravity fills bottom-up. Let's set a clear case.
        // Col 0: [top] empty, empty, sapphire, sapphire, empty, empty, empty, empty
        let names: [Character: String] = ["s": "sapphire", "e": "emerald"]
        let layout = ["........", "........", "s.......", "s.......",
                      "e.......", "........", "........", "........"]
        let board = GameBoard()
        board.loadGrid(makeGrid(layout, names: names))
        let dists = board.gravity()
        // After gravity, the two sapphires + one emerald should stack at the bottom of col 0.
        // Row 7 = sapphire, row 6 = sapphire, row 5 = emerald
        #expect(board.grid[7][0]?.kind.name == "sapphire")
        #expect(board.grid[6][0]?.kind.name == "sapphire")
        #expect(board.grid[5][0]?.kind.name == "emerald")
        // Drop distances: sapphires moved from rows 2,3 -> 6,7 (down by 4 each).
        // We only verify that at least the gems moved downward (positive distance).
        #expect(!dists.isEmpty)
    }
}

// MARK: - spawn

@MainActor
struct SpawnTests {

    @Test func spawnFillsAllEmptyCells() async throws {
        let board = GameBoard()
        // Start from a fully-empty board
        board.loadGrid(Array(repeating: Array(repeating: nil as Gem?, count: 8), count: 8))
        board.spawn(Array(GemKind.normalKinds.prefix(4)))
        // Every cell should now be non-nil
        for r in 0..<8 {
            for c in 0..<8 {
                #expect(board.grid[r][c] != nil, "cell (\(r),\(c)) should be filled")
            }
        }
    }
}

// MARK: - hasValidMoves

@MainActor
struct HasValidMovesTests {

    @Test func reportsMovesWhenAvailable() async throws {
        // A normal random board almost always has moves; verify a constructed
        // board where swapping (0,0)<->(0,1) creates a match.
        // Row 0: r r r ...  -> already a match, but we want a *potential* swap.
        // Use: row0 = r e r r g g g g ; swapping (0,0) and (0,1) makes cols 1-3 = r r r.
        let names: [Character: String] = [
            "r": "ruby", "e": "emerald", "g": "sapphire"
        ]
        let layout = ["rerrgggg",
                      "erergrgr",
                      "rgrererg",
                      "ergrergr",
                      "rergrerg",
                      "grererer",
                      "ergrerer",
                      "rergrere"]
        let board = GameBoard()
        board.loadGrid(makeGrid(layout, names: names))
        // This layout may already contain matches; either way, hasValidMoves
        // should be true for any reasonably filled board.
        #expect(board.hasValidMoves())
    }

    @Test func noMovesOnUniformBoard() async throws {
        // If every gem is the same kind, ANY swap still yields all-same -> match.
        // So to test "no moves", we need a board where no swap produces a 3-match.
        // Use a strict alternating pattern in BOTH directions (checkerboard of 4 kinds).
        // 4-color checkerboard: no two adjacent same, and no swap can create a 3-run.
        let kinds = ["ruby", "emerald", "sapphire", "topaz"]
        var layout: [String] = []
        for r in 0..<8 {
            var row = ""
            for c in 0..<8 {
                let idx = (r % 2 == 0) ? (c % 2) : ((c + 1) % 2)
                // map idx 0,1 -> kinds[0..2] but we have 4, alternate rows use kinds[2..4]
                let name = (r < 4) ? kinds[idx] : kinds[idx + 2]
                row.append(Character(name.first!))
            }
            layout.append(row)
        }
        let names: [Character: String] = [
            "r": "ruby", "e": "emerald", "s": "sapphire", "t": "topaz"
        ]
        let board = GameBoard()
        board.loadGrid(makeGrid(layout, names: names))
        #expect(!board.hasValidMoves())
    }
}

// MARK: - newGame / init invariants

@MainActor
struct NewGameTests {

    @Test func newBoardHasNoImmediateMatches() async throws {
        let board = GameBoard()
        // fillInitial() runs in init and clears any matches until stable.
        let matches = board.findMatches()
        #expect(matches == nil || matches?.isEmpty == true)
    }

    @Test func newBoardHasAtLeastOneValidMove() async throws {
        let board = GameBoard()
        #expect(board.hasValidMoves())
    }

    @Test func newGameResetsScoreAndCombo() async throws {
        let board = GameBoard()
        board.score = 1234
        board.combo = 5
        board.newGame()
        #expect(board.score == 0)
        #expect(board.combo == 0)
        #expect(board.gameOver == false)
    }
}

// MARK: - findValidSwap

@MainActor
struct FindValidSwapTests {

    @Test func returnsSwapOnSolvableBoard() async throws {
        let board = GameBoard()
        // A freshly built board always has at least one move.
        let swap = try #require(board.findValidSwap())
        // The two positions must be adjacent (Manhattan distance 1).
        let dr = abs(swap.0.row - swap.1.row)
        let dc = abs(swap.0.col - swap.1.col)
        #expect(dr + dc == 1)
    }

    @Test func returnsNilOnDeadlockBoard() async throws {
        // Strict checkerboard of 4 kinds: no swap can create a 3-run.
        let kinds = ["ruby", "emerald", "sapphire", "topaz"]
        var layout: [String] = []
        for r in 0..<8 {
            var row = ""
            for c in 0..<8 {
                let idx = (r % 2 == 0) ? (c % 2) : ((c + 1) % 2)
                let name = (r < 4) ? kinds[idx] : kinds[idx + 2]
                row.append(Character(name.first!))
            }
            layout.append(row)
        }
        let names: [Character: String] = [
            "r": "ruby", "e": "emerald", "s": "sapphire", "t": "topaz"
        ]
        let board = GameBoard()
        board.loadGrid(makeGrid(layout, names: names))
        #expect(board.findValidSwap() == nil)
    }
}
