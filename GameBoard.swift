import SwiftUI

// MARK: - Game Board

@MainActor
class GameBoard: ObservableObject {
    static let rows = 8, cols = 8
    static let maxKinds = 7

    @Published var grid: [[Gem?]]
    @Published var score = 0
    @Published var combo = 0
    @Published var selectedPosition: Position?
    @Published var isProcessing = false
    @Published var matches: [MatchGroup] = []
    @Published var particles: [Particle] = []
    @Published var flashRings: [FlashRing] = []
    @Published var scorePops: [ScorePop] = []
    @Published var bgPetals: [BgPetal] = []
    @Published var deadlockMessage: String? = nil
    @Published var nuclearFlash = false
    @Published var missile: Missile? = nil
    var rainbowProtected: Position? = nil
    var lastSwapA: Position? = nil, lastSwapB: Position? = nil
    var suppressRainbowGeneration = false
    /// Increments on every newGame(). Async chains capture it and bail out if
    /// it changed, so a chain in flight when the board resets can't corrupt
    /// the fresh board (e.g. a gravity/spawn firing after New Game is pressed).
    private var boardGeneration = 0
    @Published var nukeStyle: NukeStyle = .missile
    @Published var gameMode: GameMode = .casual
    var highScore: Int { HighScoreManager.highScore(for: gameMode) }
    @Published var theme: Theme = .sakura
    @Published var failedSwaps = 0
    @Published var timeRemaining: Double = 10
    @Published var gameOver = false
    @Published var gameOverReason = ""

    /// Flat list of all gems with positions, for smooth animation
    @Published var placedGems: [PlacedGem] = []
    var cellPx: CGFloat = 44  // set by view for particle positioning
    var windowWidth: CGFloat = 500
    var windowHeight: CGFloat = 700

    var activeKinds: Int { min(4 + (score / 500), Self.maxKinds) }

    private var availableKinds: [GemKind] { Array(GemKind.normalKinds.prefix(activeKinds)) }

    init() {
        grid = Array(repeating: Array(repeating: nil, count: Self.cols), count: Self.rows)
        fillInitial()
    }

    /// Replace the whole grid with the given layout and rebuild `placedGems`.
    /// Used by tests to set up deterministic boards (no random fill).
    func loadGrid(_ newGrid: [[Gem?]]) {
        precondition(newGrid.count == Self.rows && newGrid.allSatisfy { $0.count == Self.cols },
                     "loadGrid: grid must be \(Self.rows)×\(Self.cols)")
        grid = newGrid
        rebuildPlacedGems()
    }

    // MARK: - Setup

    private func fillInitial() {
        let kinds = availableKinds
        for r in 0..<Self.rows { for c in 0..<Self.cols { grid[r][c] = Gem(kind: kinds.randomElement()!) } }
        while let mg = findMatches(), !mg.isEmpty { removeGems(mg); gravity(); spawn(kinds) }
        rebuildPlacedGems()
    }

    func newGame() {
        // NOTE: high score is saved explicitly by callers for the mode the
        // score was earned in (game-over paths, New Game button, mode switch).
        // Saving here would risk recording it against the *new* mode when
        // switching Casual ↔ Ranked mid-game.
        boardGeneration += 1  // invalidate any in-flight async chains
        let kinds = availableKinds
        grid = Array(repeating: Array(repeating: nil, count: Self.cols), count: Self.rows)
        for r in 0..<Self.rows { for c in 0..<Self.cols { grid[r][c] = Gem(kind: kinds.randomElement()!) } }
        selectedPosition = nil; matches = []; score = 0; combo = 0; isProcessing = false; suppressRainbowGeneration = false
        particles = []; flashRings = []; scorePops = []
        failedSwaps = 0; timeRemaining = 10; lastTimeDisplay = 10; gameOver = false; gameOverReason = ""
        tickFrame = 0
        while let mg = findMatches(), !mg.isEmpty { removeGems(mg); gravity(); spawn(kinds) }
        rebuildPlacedGems()
    }

    // MARK: - Tap

    func tap(row: Int, col: Int) {
        guard !isProcessing && !gameOver else { return }
        let pos = Position(row: row, col: col)
        guard let sel = selectedPosition else { selectedPosition = pos; return }
        if sel == pos { selectedPosition = nil; return }
        if abs(sel.row - row) + abs(sel.col - col) == 1 { trySwap(sel, pos) }
        else { selectedPosition = pos }
    }

    private func trySwap(_ a: Position, _ b: Position) {
        isProcessing = true; selectedPosition = nil; combo = 0
        lastSwapA = a; lastSwapB = b
        let gen = boardGeneration
        let va = grid[a.row][a.col]; let vb = grid[b.row][b.col]
        let isRainbowA = va?.kind.name == "rainbow"
        let isRainbowB = vb?.kind.name == "rainbow"

        if isRainbowA || isRainbowB {
            // Rainbow swap: clear entire board of the non-rainbow color, then consume rainbow
            let rainbowPos = isRainbowA ? a : b
            let otherKind = (isRainbowA ? vb : va)?.kind
            guard let targetKind = otherKind else {
                isProcessing = false; suppressRainbowGeneration = false
                return
            }
            // Swap them so rainbow moves to other position
            grid[a.row][a.col] = vb; grid[b.row][b.col] = va
            swapPlacedGemsVisual(a, b)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self = self, gen == self.boardGeneration else { return }
                // Clear entire board of target color, then replace rainbow with normal
                var allMatched: Set<Position> = []
                let newRainbowPos = isRainbowA ? b : a // rainbow moved here after swap
                for r in 0..<Self.rows {
                    for c in 0..<Self.cols {
                        if let gem = self.grid[r][c], gem.kind.name == targetKind.name {
                            allMatched.insert(Position(row: r, col: c))
                        }
                    }
                }
                // Also clear the rainbow gem itself
                allMatched.insert(newRainbowPos)
                // Replace rainbow's old position with normal gem
                let replacementKind = self.availableKinds.filter { $0.name != "rainbow" }.randomElement()!
                self.grid[rainbowPos.row][rainbowPos.col] = Gem(kind: replacementKind)
                // Process as match — suppress rainbow generation for this chain
                self.suppressRainbowGeneration = true
                self.failedSwaps = 0
                self.timeRemaining = 10
                self.processMatches([MatchGroup(positions: allMatched, kind: targetKind)])
            }
            return
        }

        // Actually swap in grid
        grid[a.row][a.col] = vb; grid[b.row][b.col] = va

        // Sound
        SoundEngine.shared.playSwap()
        HapticEngine.tap()

        // Animate visual swap
        swapPlacedGemsVisual(a, b)

        // Wait for animation, then check result
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self, gen == self.boardGeneration else { return }
            if let mg = self.findMatches(), !mg.isEmpty {
                self.failedSwaps = 0  // reset on success
                self.timeRemaining = 10
                self.processMatches(mg)
            } else {
                // No match — count as failed swap
                self.failedSwaps += 1
                if self.gameMode == .ranked && self.failedSwaps >= 5 {
                    self.gameOver = true
                    self.gameOverReason = "5 failed swaps"
                    self.isProcessing = false; self.suppressRainbowGeneration = false
                    HighScoreManager.save(self.score, for: self.gameMode)
                    SoundEngine.shared.playGameOver()
                    HapticEngine.heavy()
                    return
                }
                // Animate back
                self.grid[a.row][a.col] = va; self.grid[b.row][b.col] = vb
                self.swapPlacedGemsVisual(a, b)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    guard let self = self, gen == self.boardGeneration else { return }
                    self.isProcessing = false; self.suppressRainbowGeneration = false
                }
            }
        }
    }

    private func swapPlacedGemsVisual(_ a: Position, _ b: Position) {
        var gems = placedGems
        guard let ia = gems.firstIndex(where: { $0.row == a.row && $0.col == a.col }),
              let ib = gems.firstIndex(where: { $0.row == b.row && $0.col == b.col }) else { return }
        let ra = gems[ia].row; let ca = gems[ia].col
        gems[ia] = PlacedGem(gem: gems[ia].gem, row: gems[ib].row, col: gems[ib].col, dropDistance: 0)
        gems[ib] = PlacedGem(gem: gems[ib].gem, row: ra, col: ca, dropDistance: 0)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            placedGems = gems
        }
    }

    // MARK: - Match Detection

    func findMatches() -> [MatchGroup]? {
        var groups: [MatchGroup] = []
        for r in 0..<Self.rows {
            var c = 0
            while c < Self.cols {
                guard let g = grid[r][c] else { c += 1; continue }
                var end = c
                while end + 1 < Self.cols, grid[r][end + 1]?.kind.name == g.kind.name { end += 1 }
                if end - c >= 2 { groups.append(MatchGroup(positions: Set((c...end).map{Position(row:r,col:$0)}), kind: g.kind)) }
                c = end + 1
            }
        }
        for c in 0..<Self.cols {
            var r = 0
            while r < Self.rows {
                guard let g = grid[r][c] else { r += 1; continue }
                var end = r
                while end + 1 < Self.rows, grid[end + 1][c]?.kind.name == g.kind.name { end += 1 }
                if end - r >= 2 { groups.append(MatchGroup(positions: Set((r...end).map{Position(row:$0,col:c)}), kind: g.kind)) }
                r = end + 1
            }
        }
        return groups.isEmpty ? nil : groups
    }

    // MARK: - Process chain

    private func processMatches(_ groups: [MatchGroup]) {
        let gen = boardGeneration
        // Snapshot the effect style at the start of the chain so a mid-chain
        // picker change can't flip us between missile/blocks halfway through.
        let nukeStyleSnapshot = nukeStyle
        combo += 1
        let count = groups.reduce(0) { $0 + $1.positions.count }
        let base = count * 10
        let bonus = combo > 1 ? combo * 15 : 0
        score += base + bonus

        // Sound
        SoundEngine.shared.playMatch(combo: combo)
        HapticEngine.click()

        matches = groups

        // --- Special pattern detection ---
        let gap: CGFloat = 2
        let step = cellPx + gap
        var extraClears = Set<Position>()
        var bombRings: [(CGFloat, CGFloat)] = []  // for visual flash rings

        for g in groups {
            if g.positions.count >= 5 && !suppressRainbowGeneration {
                // Rainbow gem: 6-match spawns at swap position (where player triggered the match)
                let swapPos: Position
                if let a = lastSwapA, g.positions.contains(a) { swapPos = a }
                else if let b = lastSwapB, g.positions.contains(b) { swapPos = b }
                else {
                    // Fallback: centroid
                    let rows = g.positions.map(\.row)
                    let cols = g.positions.map(\.col)
                    swapPos = Position(row: rows.reduce(0,+) / rows.count, col: cols.reduce(0,+) / cols.count)
                }
                rainbowProtected = swapPos
                grid[swapPos.row][swapPos.col] = Gem(kind: GemKind.rainbow)
                let bx = CGFloat(swapPos.col) * step + cellPx/2 + 6
                let by = CGFloat(swapPos.row) * step + cellPx/2 + 6
                bombRings.append((bx, by))
                SoundEngine.shared.playRainbow()
                HapticEngine.heavy()
            } else if g.positions.count >= 4 {
                // Bomb: clear 3×3 around centroid
                let rows = g.positions.map(\.row)
                let cols = g.positions.map(\.col)
                let cr = rows.reduce(0,+) / rows.count
                let cc = cols.reduce(0,+) / cols.count
                for r in max(0, cr-1)...min(Self.rows-1, cr+1) {
                    for c in max(0, cc-1)...min(Self.cols-1, cc+1) {
                        extraClears.insert(Position(row: r, col: c))
                    }
                }
                let bx = CGFloat(cc) * step + cellPx/2 + 6
                let by = CGFloat(cr) * step + cellPx/2 + 6
                bombRings.append((bx, by))
                SoundEngine.shared.playBombClear()
                HapticEngine.heavy()
            }
        }
        // L-shape (intersecting groups): total positions >= 5 → rainbow at intersection
        if !suppressRainbowGeneration, groups.count >= 2 {
            let allPositions = Set(groups.flatMap(\.positions))
            if allPositions.count >= 5 {
                // Find first intersection between any two groups
                outer: for i in 0..<(groups.count-1) {
                    for j in (i+1)..<groups.count {
                        let inter = groups[i].positions.intersection(groups[j].positions)
                        if let pos = inter.first {
                            rainbowProtected = pos
                            grid[pos.row][pos.col] = Gem(kind: GemKind.rainbow)
                            let bx = CGFloat(pos.col) * step + cellPx/2 + 6
                            let by = CGFloat(pos.row) * step + cellPx/2 + 6
                            bombRings.append((bx, by))
                            SoundEngine.shared.playRainbow()
                            HapticEngine.heavy()
                            break outer
                        }
                    }
                }
            }
        }
        // Rainbow gem is visible while everything else clears — exclude from matched animation
        if let rp = rainbowProtected {
            var filtered: [MatchGroup] = []
            for g in matches {
                var pos = g.positions
                if pos.contains(rp) { pos.remove(rp) }
                filtered.append(MatchGroup(positions: pos, kind: g.kind))
            }
            matches = filtered
        }

        // Match centroid (for score pop, missile, nuke)
        var totalRow: CGFloat = 0, totalCol: CGFloat = 0, totalCount: CGFloat = 0
        for g in groups { for p in g.positions { totalRow += CGFloat(p.row); totalCol += CGFloat(p.col); totalCount += 1 } }
        let tx = (totalCol / totalCount) * step + cellPx / 2 + 6
        let ty = (totalRow / totalCount) * step + cellPx / 2 + 6

        // Score pop at match centroid
        let text = combo > 1 ? "+\(base + bonus)  x\(combo)" : "+\(base)"
        scorePops.append(ScorePop(position: CGPoint(x: tx, y: ty), text: text))

        // Store match context for delayed nuke
        let nukeTarget = (cx: tx, cy: ty, count: Int(totalCount))

        // Branch on effect style — clear old effects first
        particles.removeAll()
        flashRings.removeAll()
        missile = nil

        // Special pattern flash rings (after clearing old effects)
        for (bx, by) in bombRings {
            flashRings.append(FlashRing(x: bx, y: by, color: .yellow, lineWidth: 10))
            flashRings.append(FlashRing(x: bx, y: by, color: .orange, lineWidth: 5))
        }

        if nukeStyleSnapshot == .missile {
            missile = Missile(x: tx + CGFloat.random(in: -60...60), y: -60, targetX: tx, targetY: ty)
            func flyMissile() {
            guard gen == boardGeneration else { return }
            guard var m = missile else { return }
            m.progress += 0.04
            let t = CGFloat(m.progress)
            m.x = m.x + (m.targetX - m.x) * t
            m.y = m.y + (m.targetY - m.y) * t + sin(t * .pi) * -30
            for _ in 0..<1 {  // reduced trail
                particles.append(Particle(
                    x: m.x + CGFloat.random(in: -6...6),
                    y: m.y + CGFloat.random(in: -6...6),
                    vx: CGFloat.random(in: -40...40),
                    vy: CGFloat.random(in: 20...60),
                    color: [.orange, .yellow, .red].randomElement()!,
                    life: 0.5,
                    size: CGFloat.random(in: 5...12),
                    rotationSpeed: Double.random(in: -200...200),
                    shape: .circle
                ))
            }
            missile = m
            if m.progress >= 1.0 {
                missile = nil
                triggerNuke(cx: nukeTarget.cx, cy: nukeTarget.cy, matchCount: nukeTarget.count)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { flyMissile() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { flyMissile() }
        } else {
        // Blocks: shatter immediately
        triggerBlocks(cx: tx, cy: ty, groups: groups, cellPx: cellPx)
        }

        // Grid cleanup happens immediately
        if combo >= 2 { nuclearFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.nuclearFlash = false }
        }
        removeGems(groups)
        // Extra clears from special patterns
        for pos in extraClears {
            guard grid[pos.row][pos.col] != nil else { continue }
            // Extra particles at extra clear positions
            let px = CGFloat(pos.col) * step + cellPx/2 + 6
            let py = CGFloat(pos.row) * step + cellPx/2 + 6
            for _ in 0..<4 {
                particles.append(Particle(x: px + CGFloat.random(in: -6...6), y: py + CGFloat.random(in: -6...6),
                    vx: CGFloat.random(in: -80...80), vy: CGFloat.random(in: -120...(-30)),
                    color: .white, size: CGFloat.random(in: 6...14),
                    rotationSpeed: Double.random(in: -200...200), shape: .burst))
            }
            if rainbowProtected == nil || pos != rainbowProtected! { grid[pos.row][pos.col] = nil }
        }
        rainbowProtected = nil
        // Score bonus for special clears
        let extraCount = extraClears.count
        if extraCount > 0 { score += extraCount * 15 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, gen == self.boardGeneration else { return }
            let gravityDists = self.gravity()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, gen == self.boardGeneration else { return }
                self.spawn(self.availableKinds, mergeDists: gravityDists)
                self.matches = []
                if let next = self.findMatches(), !next.isEmpty { self.processMatches(next) }
                else { self.isProcessing = false; self.suppressRainbowGeneration = false; self.combo = 0; self.checkAndFixDeadlock() }
            }
        }
    }

    private func triggerBlocks(cx: CGFloat, cy: CGFloat, groups: [MatchGroup], cellPx: CGFloat) {
        let gap: CGFloat = 2
        let step = cellPx + gap

        for g in groups {
            for p in g.positions {
                let px = CGFloat(p.col) * step + cellPx / 2 + 6
                let py = CGFloat(p.row) * step + cellPx / 2 + 6

                // Shatter: fewer, simpler fragments
                for _ in 0..<5 {
                    let angle = Double.random(in: 0...(2 * .pi))
                    let speed = CGFloat.random(in: 60...200)
                    particles.append(Particle(
                        x: px, y: py,
                        vx: cos(angle) * speed,
                        vy: sin(angle) * speed - CGFloat.random(in: 30...100),
                        color: g.kind.color,
                        size: CGFloat.random(in: 10...22),
                        rotationSpeed: Double.random(in: -400...400),
                        shape: .rect,
                        bounceCount: 1
                    ))
                }
                // Minimal dust
                for _ in 0..<3 {
                    particles.append(Particle(
                        x: px + CGFloat.random(in: -6...6),
                        y: py + CGFloat.random(in: -6...6),
                        vx: CGFloat.random(in: -50...50),
                        vy: CGFloat.random(in: -120...(-20)),
                        color: g.kind.color,
                        size: CGFloat.random(in: 3...6),
                        shape: .circle
                    ))
                }
            }
        }
    }

    private func triggerNuke(cx: CGFloat, cy: CGFloat, matchCount: Int) {

        SoundEngine.shared.playExplosion()
        HapticEngine.heavy()
        flashRings.append(FlashRing(x: cx, y: cy, color: .white, lineWidth: 16))
        flashRings.append(FlashRing(x: cx, y: cy, color: .yellow, lineWidth: 10))
        flashRings.append(FlashRing(x: cx, y: cy, color: .orange, lineWidth: 6))

        // Fireball
        for _ in 0..<(6 + matchCount) {
            particles.append(Particle(
                x: cx + CGFloat.random(in: -15...15), y: cy + CGFloat.random(in: -10...10),
                vx: CGFloat.random(in: -120...120), vy: CGFloat.random(in: -180...(-40)),
                color: [.white, Color(red:1, green:0.95, blue:0.7)].randomElement()!,
                size: CGFloat.random(in: 15...40),
                rotationSpeed: Double.random(in: -300...300),
                shape: .circle
            ))
        }

        // Stem
        let capY = cy - cellPx * 2.5
        for _ in 0..<(5 + matchCount) {
            particles.append(Particle(
                x: cx + CGFloat.random(in: -8...8),
                y: cy - 30,
                vx: CGFloat.random(in: -20...20),
                vy: CGFloat.random(in: -350...(-250)),
                color: [.white, .yellow, Color(red:1, green:0.85, blue:0.5)].randomElement()!,
                size: CGFloat.random(in: 6...16),
                rotationSpeed: Double.random(in: -150...150),
                shape: .circle
            ))
        }

        // Mushroom cap
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self = self else { return }
            let capCount = 10 + matchCount * 2
            for i in 0..<capCount {
                let angle = Double(i) * .pi * 2 / Double(capCount)
                let spread = CGFloat.random(in: 100...300)
                self.particles.append(Particle(
                    x: cx, y: capY,
                    vx: cos(angle) * spread,
                    vy: CGFloat.random(in: -50...10),
                    color: [.orange, .red, Color(red:1, green:0.5, blue:0.1)].randomElement()!,
                    size: CGFloat.random(in: 20...60),
                    rotationSpeed: Double.random(in: -500...500),
                    shape: [.circle, .burst].randomElement()!
                ))
            }
            for i in 0..<8 {
                let angle = Double(i) * .pi * 2 / 8
                self.particles.append(Particle(
                    x: cx, y: capY,
                    vx: cos(angle) * CGFloat.random(in: 50...130),
                    vy: CGFloat.random(in: -25...20),
                    color: [.white, .yellow].randomElement()!,
                    size: CGFloat.random(in: 25...50),
                    rotationSpeed: Double.random(in: -200...200),
                    shape: .circle
                ))
            }
        }

        // Smoke ring
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self = self else { return }
            for i in 0..<10 {
                let angle = Double(i) * .pi * 2 / 10 + 0.15
                self.particles.append(Particle(
                    x: cx + cos(angle) * 80, y: capY,
                    vx: cos(angle) * CGFloat.random(in: 30...70),
                    vy: CGFloat.random(in: -40...(-10)),
                    color: [Color(red:0.2, green:0.18, blue:0.12)].randomElement()!,
                    size: CGFloat.random(in: 15...40),
                    shape: .circle,
                    bounceCount: 1
                ))
            }
            // Ground dust
            for i in 0..<10 {
                let angle = Double(i) * .pi * 2 / 10
                self.particles.append(Particle(
                    x: cx, y: cy + 6,
                    vx: cos(angle) * CGFloat.random(in: 80...250),
                    vy: CGFloat.random(in: -80...(-10)),
                    color: [Color(red:0.45, green:0.35, blue:0.25), .gray].randomElement()!,
                    size: CGFloat.random(in: 8...22),
                    rotationSpeed: Double.random(in: -200...200),
                    shape: .burst,
                    bounceCount: 2
                ))
            }
        }

        // Fallout
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { [weak self] in
            guard let self = self else { return }
            for _ in 0..<(4 + matchCount) {
                self.particles.append(Particle(
                    x: cx + CGFloat.random(in: -50...50),
                    y: capY + CGFloat.random(in: -30...80),
                    vx: CGFloat.random(in: -25...25),
                    vy: CGFloat.random(in: 15...50),
                    color: [Color(red:0.18, green:0.18, blue:0.18)].randomElement()!,
                    size: CGFloat.random(in: 3...10),
                    shape: .circle,
                    bounceCount: 3
                ))
            }
        }

    }

    // MARK: - Helpers

    private func rebuildPlacedGems(dropDistances: [UUID: Int] = [:]) {
        var result: [PlacedGem] = []
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                if let gem = grid[r][c] {
                    let dist = dropDistances[gem.id] ?? 0
                    result.append(PlacedGem(gem: gem, row: r, col: c, dropDistance: dist))
                }
            }
        }
        placedGems = result
    }

    private func removeGems(_ groups: [MatchGroup]) {
        for g in groups { for p in g.positions {
            if rainbowProtected == nil || p != rainbowProtected! {
                grid[p.row][p.col] = nil
            }
        } }
    }

    @discardableResult
    func gravity() -> [UUID: Int] {
        // Track gem positions before gravity
        var oldRows: [UUID: Int] = [:]
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                if let gem = grid[r][c] { oldRows[gem.id] = r }
            }
        }
        for c in 0..<Self.cols {
            var w = Self.rows - 1
            for r in (0..<Self.rows).reversed() {
                if grid[r][c] != nil { grid[w][c] = grid[r][c]; if w != r { grid[r][c] = nil }; w -= 1 }
            }
        }
        // Compute drop distances
        var dists: [UUID: Int] = [:]
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                if let gem = grid[r][c], let old = oldRows[gem.id] {
                    dists[gem.id] = r - old
                }
            }
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
            rebuildPlacedGems(dropDistances: dists)
        }
        return dists
    }

    func spawn(_ kinds: [GemKind], mergeDists: [UUID: Int] = [:]) {
        var dists = mergeDists
        for c in 0..<Self.cols {
            var emptyCount = 0
            // Count empty cells from top for each position
            for r in 0..<Self.rows {
                if grid[r][c] == nil { emptyCount += 1 }
                else if emptyCount > 0 {
                    // Gems above were filled by gravity, these are falling from spawn
                    dists[grid[r][c]!.id] = emptyCount
                }
            }
            for r in 0..<Self.rows {
                if grid[r][c] == nil {
                    let gem = Gem(kind: kinds.randomElement()!)
                    grid[r][c] = gem
                    // New gems appear to drop from above the board
                    dists[gem.id] = r + 1 + emptyCount
                    emptyCount += 1
                }
            }
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
            rebuildPlacedGems(dropDistances: dists)
        }
    }

    // MARK: - Deadlock detection

    func hasValidMoves() -> Bool {
        for r in 0..<Self.rows {
            for c in 0..<Self.cols {
                guard let gem = grid[r][c] else { continue }
                // Try swap right
                if c + 1 < Self.cols, let right = grid[r][c + 1] {
                    grid[r][c] = right; grid[r][c + 1] = gem
                    let match = findMatches()
                    grid[r][c] = gem; grid[r][c + 1] = right
                    if match != nil { return true }
                }
                // Try swap down
                if r + 1 < Self.rows, let down = grid[r + 1][c] {
                    grid[r][c] = down; grid[r + 1][c] = gem
                    let match = findMatches()
                    grid[r][c] = gem; grid[r + 1][c] = down
                    if match != nil { return true }
                }
            }
        }
        return false
    }

    func checkAndFixDeadlock() {
        guard !hasValidMoves() else { return }
        deadlockMessage = "No moves! Reshuffling…"
        SoundEngine.shared.playDeadlock()
        isProcessing = true
        let gen = boardGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self, gen == self.boardGeneration else { return }
            var attempts = 0
            repeat {
                let kinds = self.availableKinds
                for r in 0..<Self.rows { for c in 0..<Self.cols {
                    self.grid[r][c] = Gem(kind: kinds.randomElement()!)
                } }
                while let mg = self.findMatches(), !mg.isEmpty {
                    self.removeGems(mg); self.gravity(); self.spawn(kinds)
                }
                attempts += 1
            } while !self.hasValidMoves() && attempts < 50
            self.rebuildPlacedGems()
            self.deadlockMessage = nil
            self.isProcessing = false; self.suppressRainbowGeneration = false
        }
    }

    // Particle tick (called from view's TimelineView)
    var tickFrame = 0
    var lastTimeDisplay: Double = 10
    func tickParticles(dt: TimeInterval) {
        tickFrame += 1

        // Ranked countdown: ticks at half speed during chain processing
        if gameMode == .ranked && !gameOver {
            if isProcessing {
                timeRemaining -= dt * 0.5
            } else {
                timeRemaining -= dt
            }
            if tickFrame % 6 == 0 { lastTimeDisplay = timeRemaining }
            if timeRemaining <= 0 {
                gameOver = true
                gameOverReason = "Time's up"
                timeRemaining = 0
                lastTimeDisplay = 0
                HighScoreManager.save(score, for: gameMode)
                SoundEngine.shared.playGameOver()
            }
        }

        guard !particles.isEmpty || !flashRings.isEmpty else { return }
        let boardW = CGFloat(Self.cols) * (cellPx + 2) + 8
        let boardH = CGFloat(Self.rows) * (cellPx + 2) + 8

        var new: [Particle] = []
        for var p in particles {
            p.x += p.vx * CGFloat(dt)
            p.y += p.vy * CGFloat(dt)
            p.vy += 500 * CGFloat(dt)
            p.rotation += p.rotationSpeed * CGFloat(dt)
            p.life -= dt * 1.2
            p.size *= 0.96
            if p.bounceCount < 3 {
                if p.x < 0 { p.x = 0; p.vx = abs(p.vx) * 0.6; p.bounceCount += 1 }
                if p.x > boardW { p.x = boardW; p.vx = -abs(p.vx) * 0.6; p.bounceCount += 1 }
                if p.y > boardH { p.y = boardH; p.vy = -abs(p.vy) * 0.5; p.bounceCount += 1 }
            }
            if p.life > 0 { new.append(p) }
        }
        particles = new

        var newRings: [FlashRing] = []
        for var r in flashRings {
            r.radius += 350 * CGFloat(dt)
            r.opacity -= dt * 1.8
            if r.opacity > 0 { newRings.append(r) }
        }
        flashRings = newRings
    }

    func tickScorePops() {
        guard !scorePops.isEmpty else { return }
        var new: [ScorePop] = []
        for var s in scorePops {
            s.opacity -= 0.03; s.offset -= 2
            if s.opacity > 0 { new.append(s) }
        }
        scorePops = new
    }

    private var bgFrameCounter = 0
    func tickBackground(dt: TimeInterval, width: CGFloat, height: CGFloat) {
        // Spawn new petals periodically
        bgFrameCounter += 1
        let spawnRate = theme == .sakura ? 3 : theme == .seaside ? 5 : 8
        if bgFrameCounter % spawnRate == 0 && bgPetals.count < 80 {
            let petal = BgPetal(
                x: CGFloat.random(in: 0...width),
                y: -10,
                vx: CGFloat.random(in: -20...20),
                vy: CGFloat.random(in: 20...60),
                size: theme == .sakura ? CGFloat.random(in: 8...18) : theme == .seaside ? CGFloat.random(in: 14...30) : CGFloat.random(in: 4...14),
                opacity: Double.random(in: 0.3...0.7),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -120...120),
                kind: theme == .sakura ? 0 : theme == .seaside ? 1 : 2
            )
            bgPetals.append(petal)
        }

        // Move existing petals
        var kept: [BgPetal] = []
        for var p in bgPetals {
            p.x += p.vx * CGFloat(dt)
            p.y += p.vy * CGFloat(dt)
            p.rotation += p.rotationSpeed * CGFloat(dt)
            if theme == .sakura {
                p.vx += CGFloat.random(in: -3...3) * CGFloat(dt) * 30  // sway
            }
            if theme == .seaside {
                p.vx += sin(CGFloat(bgFrameCounter) * 0.05 + p.y * 0.02) * CGFloat(dt) * 15  // wave sway
            }
            if p.y < height + 20 && p.x > -20 && p.x < width + 20 {
                kept.append(p)
            }
        }
        bgPetals = kept
    }
}
