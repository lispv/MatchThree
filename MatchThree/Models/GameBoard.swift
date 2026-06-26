import Foundation

@MainActor
class GameBoard: ObservableObject {
    static let rows = 8
    static let cols = 8

    @Published var grid: [[Gem?]]
    @Published var score = 0
    @Published var selectedPosition: Position?
    @Published var isProcessing = false
    @Published var matches: [MatchGroup] = []

    init() {
        grid = Array(repeating: Array(repeating: nil, count: Self.cols), count: Self.rows)
        fillInitial()
    }

    // MARK: - Setup

    private func fillInitial() {
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                grid[r][c] = Gem.random()
            }
        }
        // Remove any initial matches so board starts clean
        while let matchGroups = findMatches(), !matchGroups.isEmpty {
            removeMatches(matchGroups)
            applyGravity()
            spawnNewGems()
        }
    }

    // MARK: - Tap handling

    func tap(row: Int, col: Int) {
        guard !isProcessing else { return }
        let pos = Position(row: row, col: col)

        if let selected = selectedPosition {
            if selected == pos {
                selectedPosition = nil
            } else if areAdjacent(selected, pos) {
                trySwap(selected, pos)
            } else {
                selectedPosition = pos
            }
        } else {
            selectedPosition = pos
        }
    }

    private func areAdjacent(_ a: Position, _ b: Position) -> Bool {
        let dr = abs(a.row - b.row)
        let dc = abs(a.col - b.col)
        return (dr == 1 && dc == 0) || (dr == 0 && dc == 1)
    }

    // MARK: - Swap

    private func trySwap(_ a: Position, _ b: Position) {
        isProcessing = true
        selectedPosition = nil

        // Perform swap
        let temp = grid[a.row][a.col]
        grid[a.row][a.col] = grid[b.row][b.col]
        grid[b.row][b.col] = temp

        // Check if swap produced matches
        if let matchGroups = findMatches(), !matchGroups.isEmpty {
            processMatchChain()
        } else {
            // Swap back
            let tempBack = grid[a.row][a.col]
            grid[a.row][a.col] = grid[b.row][b.col]
            grid[b.row][b.col] = tempBack
            isProcessing = false
        }
    }

    // MARK: - Match detection

    func findMatches() -> [MatchGroup]? {
        var groups: [MatchGroup] = []

        // Horizontal
        for r in 0..<Self.rows {
            var c = 0
            while c < Self.cols {
                guard let gem = grid[r][c] else { c += 1; continue }
                var end = c
                while end + 1 < Self.cols, grid[r][end + 1]?.type == gem.type {
                    end += 1
                }
                if end - c >= 2 {
                    let positions = Set((c...end).map { Position(row: r, col: $0) })
                    groups.append(MatchGroup(positions: positions, type: gem.type))
                }
                c = end + 1
            }
        }

        // Vertical
        for c in 0..<Self.cols {
            var r = 0
            while r < Self.rows {
                guard let gem = grid[r][c] else { r += 1; continue }
                var end = r
                while end + 1 < Self.rows, grid[end + 1][c]?.type == gem.type {
                    end += 1
                }
                if end - r >= 2 {
                    let positions = Set((r...end).map { Position(row: $0, col: c) })
                    groups.append(MatchGroup(positions: positions, type: gem.type))
                }
                r = end + 1
            }
        }

        return groups.isEmpty ? nil : groups
    }

    // MARK: - Match chain (process until stable)

    func processMatchChain() {
        guard let matchGroups = findMatches(), !matchGroups.isEmpty else {
            isProcessing = false
            return
        }

        matches = matchGroups
        let totalMatched = matchGroups.reduce(0) { $0 + $1.positions.count }
        score += totalMatched * 10

        removeMatches(matchGroups)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.applyGravity()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.spawnNewGems()
                self?.matches = []
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.processMatchChain()
                }
            }
        }
    }

    func removeMatches(_ groups: [MatchGroup]) {
        for group in groups {
            for pos in group.positions {
                grid[pos.row][pos.col] = nil
            }
        }
    }

    func applyGravity() {
        for c in 0..<Self.cols {
            var writeRow = Self.rows - 1
            for r in (0..<Self.rows).reversed() {
                if grid[r][c] != nil {
                    grid[writeRow][c] = grid[r][c]
                    if writeRow != r { grid[r][c] = nil }
                    writeRow -= 1
                }
            }
        }
    }

    func spawnNewGems() {
        for c in 0..<Self.cols {
            for r in 0..<Self.rows {
                if grid[r][c] == nil {
                    grid[r][c] = Gem.random()
                }
            }
        }
    }
}
