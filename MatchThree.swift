import SwiftUI
import AVFoundation
import AppKit

// MARK: - Haptic Engine

struct HapticEngine {
    static func tap()    { NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default) }
    static func click()  { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default) }
    static func heavy()  { NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default) }
}

// MARK: - High Score Manager

struct HighScoreManager {
    private static let defaults = UserDefaults.standard

    static func highScore(for mode: GameMode) -> Int {
        defaults.integer(forKey: "highscore_\(mode.rawValue)")
    }

    static func save(_ score: Int, for mode: GameMode) {
        let current = highScore(for: mode)
        if score > current {
            defaults.set(score, forKey: "highscore_\(mode.rawValue)")
        }
    }
}

// MARK: - Sound Engine (procedural, no audio files)

class SoundEngine {
    static let shared = SoundEngine()
    static var isEnabled = true
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var scheduledTime: AVAudioTime = .init(hostTime: 0)

    private init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, fromBus: 0, toBus: 0, format: nil)
        try? engine.start()
    }

    func playTone(frequency: Float, duration: Float, wave: Wave = .sine, volume: Float = 0.3, delay: Float = 0) {
        guard Self.isEnabled else { return }
        let format = playerNode.outputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)
        let frameCount = Int(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let channels = Int(format.channelCount)

        for frame in 0..<frameCount {
            let t = Float(frame) / sampleRate
            let envelope = max(0, 1.0 - (t / duration) * 1.5)
            let sample: Float = switch wave {
            case .sine:   sin(2 * .pi * frequency * t) * envelope * volume
            case .square: (sin(2 * .pi * frequency * t) > 0 ? 1.0 : -1.0) * envelope * volume * 0.3
            case .noise:  Float.random(in: -1...1) * envelope * volume * 0.6
            case .saw:     (2 * (t * frequency - floor(t * frequency + 0.5))) * envelope * volume * 0.3
            }
            for ch in 0..<channels {
                buffer.floatChannelData![ch][frame] = sample
            }
        }

        let now = playerNode.lastRenderTime ?? AVAudioTime(hostTime: mach_absolute_time())
        let startTime = AVAudioTime(hostTime: now.hostTime + AVAudioTime.hostTime(forSeconds: Double(delay)))
        playerNode.scheduleBuffer(buffer, at: startTime, options: [])
        if !playerNode.isPlaying { playerNode.play(at: nil) }
    }

    enum Wave { case sine, square, noise, saw }

    func playSwap() { playTone(frequency: 1200, duration: 0.03, wave: .sine, volume: 0.25) }

    func playMatch(combo: Int) {
        let base = 440 + Float(min(combo - 1, 4)) * 80
        playTone(frequency: base, duration: 0.12, wave: .sine, volume: 0.25)
        playTone(frequency: base * 1.25, duration: 0.10, wave: .sine, volume: 0.2, delay: 0.04)
        playTone(frequency: base * 1.5, duration: 0.08, wave: .sine, volume: 0.15, delay: 0.08)
    }

    func playExplosion() {
        playTone(frequency: 200, duration: 0.12, wave: .sine, volume: 0.35)
        playTone(frequency: 100, duration: 0.18, wave: .sine, volume: 0.3, delay: 0.05)
        playTone(frequency: 50, duration: 0.25, wave: .sine, volume: 0.25, delay: 0.1)
    }

    func playGameOver() {
        playTone(frequency: 330, duration: 0.2, wave: .sine, volume: 0.3)
        playTone(frequency: 262, duration: 0.25, wave: .sine, volume: 0.25, delay: 0.15)
        playTone(frequency: 196, duration: 0.35, wave: .sine, volume: 0.2, delay: 0.3)
    }

    func playDeadlock() {
        playTone(frequency: 660, duration: 0.08, wave: .sine, volume: 0.25)
        playTone(frequency: 880, duration: 0.1, wave: .sine, volume: 0.2, delay: 0.06)
    }

    func playBombClear() {
        playTone(frequency: 30, duration: 0.4, wave: .sine, volume: 0.45)
        playTone(frequency: 60, duration: 0.3, wave: .sine, volume: 0.35, delay: 0.05)
        playTone(frequency: 110, duration: 0.2, wave: .sine, volume: 0.22, delay: 0.1)
    }

    func playCrossClear() {
        playTone(frequency: 600, duration: 0.1, wave: .sine, volume: 0.3)
        playTone(frequency: 900, duration: 0.08, wave: .sine, volume: 0.25, delay: 0.05)
        playTone(frequency: 1200, duration: 0.06, wave: .sine, volume: 0.2, delay: 0.1)
        playTone(frequency: 440, duration: 0.15, wave: .sine, volume: 0.15, delay: 0.08)
    }
}

// MARK: - Gem Types (up to 8, unlocked progressively)

struct GemKind: Equatable {
    let name: String
    let color: Color
    let icon: String

    static func == (lhs: GemKind, rhs: GemKind) -> Bool { lhs.name == rhs.name }

    static let normalKinds: [GemKind] = [
        GemKind(name: "ruby",    color: Color(red: 1.00, green: 0.08, blue: 0.15), icon: "heart.fill"),
        GemKind(name: "emerald", color: Color(red: 0.05, green: 0.95, blue: 0.25), icon: "leaf.fill"),
        GemKind(name: "sapphire",color: Color(red: 0.10, green: 0.50, blue: 1.00), icon: "drop.fill"),
        GemKind(name: "topaz",   color: Color(red: 1.00, green: 0.55, blue: 0.00), icon: "flame.fill"),
        GemKind(name: "amethyst",color: Color(red: 0.75, green: 0.05, blue: 1.00), icon: "star.fill"),
        GemKind(name: "diamond", color: Color(red: 0.80, green: 0.95, blue: 1.00), icon: "sparkles"),
        GemKind(name: "obsidian",color: Color(red: 0.30, green: 0.30, blue: 0.38), icon: "moon.fill"),
        GemKind(name: "coral",   color: Color(red: 1.00, green: 0.38, blue: 0.22), icon: "seal.fill"),
    ]
    static let rainbow: GemKind = GemKind(name: "rainbow", color: Color(red: 1.00, green: 0.50, blue: 0.00), icon: "sparkles")
}

// MARK: - Models

struct Gem: Identifiable, Equatable {
    let id = UUID()
    let kind: GemKind
}

struct Position: Equatable, Hashable {
    let row: Int; let col: Int
}

struct MatchGroup {
    let positions: Set<Position>; let kind: GemKind
}

// MARK: - Particle

enum ParticleShape: CaseIterable {
    case circle, burst, rect
}

// MARK: - Effect style

enum NukeStyle: String, CaseIterable {
    case missile = "导弹"
    case blocks = "积木"
}

enum GameMode: String, CaseIterable {
    case casual = "休闲"
    case ranked = "排位"
}

enum Theme: String, CaseIterable {
    case skynet = "天网"
    case sakura = "樱花"
    case seaside = "海边"

    var bgGradient: [Color] {
        switch self {
        case .skynet: [Color(red:0.06,green:0.04,blue:0.08), .black]
        case .sakura: [Color(red:1.0,green:0.85,blue:0.9), Color(red:0.95,green:0.75,blue:0.82)]
        case .seaside: [Color(red:0.08,green:0.28,blue:0.38), Color(red:0.03,green:0.15,blue:0.22)]
        }
    }

    var accent: Color {
        switch self {
        case .skynet: Color(red:0.9, green:0.15, blue:0.1)
        case .sakura: Color(red:1.0, green:0.45, blue:0.65)
        case .seaside: Color(red:0.3, green:0.85, blue:1.0)
        }
    }

    var isDark: Bool { self != .sakura }
    var textColor: Color { isDark ? .white : Color(red:0.15, green:0.12, blue:0.18) }
    var dimColor: Color { isDark ? Color.white.opacity(0.6) : Color(red:0.3, green:0.25, blue:0.35) }
    var scoreColor: Color { isDark ? .yellow : Color(red:0.6, green:0.15, blue:0.0) }
    var boardBg: Color { isDark ? Color.black.opacity(0.3) : Color.white.opacity(0.3) }
    var boardStroke: Color { isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.1) }
}

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat; var y: CGFloat
    var vx: CGFloat; var vy: CGFloat
    var color: Color
    var life: Double = 1.0
    var size: CGFloat
    var rotation: Double = 0
    var rotationSpeed: Double = 0
    var shape: ParticleShape = .circle
    var bounceCount: Int = 0
}

// MARK: - Missile

struct Missile {
    var x: CGFloat; var y: CGFloat
    let targetX: CGFloat; let targetY: CGFloat
    var progress: Double = 0  // 0→1
    var trail: [CGPoint] = []
}

struct FlashRing: Identifiable {
    let id = UUID()
    let x: CGFloat; let y: CGFloat
    let color: Color
    var radius: CGFloat = 4
    var opacity: Double = 1.0
    var lineWidth: CGFloat = 3
}

// MARK: - Score pop

struct ScorePop: Identifiable {
    let id = UUID()
    let position: CGPoint
    let text: String
    var opacity: Double = 1
    var offset: CGFloat = 0
}

// MARK: - Background petal (theme animation)

struct BgPetal: Identifiable {
    let id = UUID()
    var x: CGFloat; var y: CGFloat
    var vx: CGFloat; var vy: CGFloat
    var size: CGFloat; var opacity: Double
    var rotation: Double; var rotationSpeed: Double
    var kind: Int  // 0=sakura petal, 1=bubble, 2=spark
}

// MARK: - Game Board

@MainActor
class GameBoard: ObservableObject {
    static let rows = 8, cols = 8
    static let maxKinds = 8

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
    @Published var nukeStyle: NukeStyle = .missile
    @Published var soundEnabled = true
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

    var activeKinds: Int { min(4 + (score / 300), Self.maxKinds) }

    private var availableKinds: [GemKind] { Array(GemKind.normalKinds.prefix(activeKinds)) }

    init() {
        grid = Array(repeating: Array(repeating: nil, count: Self.cols), count: Self.rows)
        fillInitial()
    }

    // MARK: - Setup

    private func fillInitial() {
        let kinds = availableKinds
        for r in 0..<Self.rows { for c in 0..<Self.cols { grid[r][c] = Gem(kind: kinds.randomElement()!) } }
        while let mg = findMatches(), !mg.isEmpty { removeGems(mg); gravity(); spawn(kinds) }
        rebuildPlacedGems()
    }

    func newGame() {
        // Save high score before resetting
        HighScoreManager.save(score, for: gameMode)
        let kinds = availableKinds
        grid = Array(repeating: Array(repeating: nil, count: Self.cols), count: Self.rows)
        for r in 0..<Self.rows { for c in 0..<Self.cols { grid[r][c] = Gem(kind: kinds.randomElement()!) } }
        selectedPosition = nil; matches = []; score = 0; combo = 0; isProcessing = false
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
        let va = grid[a.row][a.col]; let vb = grid[b.row][b.col]
        let isRainbowA = va?.kind.name == "rainbow"
        let isRainbowB = vb?.kind.name == "rainbow"

        if isRainbowA || isRainbowB {
            // Rainbow swap: clear entire board of the non-rainbow color, then replace rainbow with normal
            let rainbowPos = isRainbowA ? a : b
            let otherKind = (isRainbowA ? vb : va)?.kind
            guard let targetKind = otherKind else {
                isProcessing = false
                return
            }
            // Swap them so rainbow moves to other position
            grid[a.row][a.col] = vb; grid[b.row][b.col] = va
            swapPlacedGemsVisual(a, b)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self = self else { return }
                // Clear entire board of target color, then replace rainbow with random normal gem
                var allMatched: Set<Position> = []
                for r in 0..<Self.rows {
                    for c in 0..<Self.cols {
                        if let gem = self.grid[r][c], gem.kind.name == targetKind.name {
                            allMatched.insert(Position(row: r, col: c))
                        }
                    }
                }
                // Replace rainbow with normal gem (so it doesn't stay on board)
                let replacementKind = self.availableKinds.filter { $0.name != "rainbow" }.randomElement()!
                self.grid[rainbowPos.row][rainbowPos.col] = Gem(kind: replacementKind)
                // Process as match
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
            guard let self = self else { return }
            if let mg = self.findMatches(), !mg.isEmpty {
                self.failedSwaps = 0  // reset on success
                self.timeRemaining = 10
                self.processMatches(mg)
            } else {
                // No match — count as failed swap
                self.failedSwaps += 1
                if self.gameMode == .ranked && self.failedSwaps >= 5 {
                    self.gameOver = true
                    self.gameOverReason = "5次无效交换"
                    self.isProcessing = false
                    HighScoreManager.save(self.score, for: self.gameMode)
                    SoundEngine.shared.playGameOver()
                    HapticEngine.heavy()
                    return
                }
                // Animate back
                self.grid[a.row][a.col] = va; self.grid[b.row][b.col] = vb
                self.swapPlacedGemsVisual(a, b)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.isProcessing = false
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
        let allMatched = Set(groups.flatMap(\.positions))
        var extraClears = Set<Position>()
        var bombRings: [(CGFloat, CGFloat)] = []  // for visual flash rings
        var crossLines: [(Int, Int)] = []          // (row, col) of crosses

        for g in groups {
            if g.positions.count >= 4 {
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
            if g.positions.count >= 5 {
                // Rainbow gem: spawn at centroid (special behavior handled in swap)
                let rows = g.positions.map(\.row)
                let cols = g.positions.map(\.col)
                let cr = rows.reduce(0,+) / rows.count
                let cc = cols.reduce(0,+) / cols.count
                // Replace centroid gem with rainbow gem immediately
                grid[cr][cc] = Gem(kind: GemKind.rainbow)
                let bx = CGFloat(cc) * step + cellPx/2 + 6
                let by = CGFloat(cr) * step + cellPx/2 + 6
                bombRings.append((bx, by))
                SoundEngine.shared.playCrossClear()
                HapticEngine.heavy()
            }
        }

        // Cross: intersection of H and V match groups
        if groups.count >= 2 {
            for i in 0..<(groups.count-1) {
                for j in (i+1)..<groups.count {
                    let inter = groups[i].positions.intersection(groups[j].positions)
                    if !inter.isEmpty {
                        for pos in inter {
                            for r in 0..<Self.rows { extraClears.insert(Position(row: r, col: pos.col)) }
                            for c in 0..<Self.cols { extraClears.insert(Position(row: pos.row, col: c)) }
                            crossLines.append((pos.row, pos.col))
                        }
                        SoundEngine.shared.playCrossClear()
                        HapticEngine.heavy()
                    }
                }
            }
        }
        extraClears.subtract(allMatched)

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
        for (r, c) in crossLines {
            let cx = CGFloat(c) * step + cellPx/2 + 6
            let cy = CGFloat(r) * step + cellPx/2 + 6
            flashRings.append(FlashRing(x: cx, y: cy, color: .white, lineWidth: 8))
        }

        if nukeStyle == .missile {
            missile = Missile(x: tx + CGFloat.random(in: -60...60), y: -60, targetX: tx, targetY: ty)
            func flyMissile() {
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
            grid[pos.row][pos.col] = nil
        }
        // Score bonus for special clears
        let extraCount = extraClears.count
        if extraCount > 0 { score += extraCount * 15 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            let gravityDists = self.gravity()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.spawn(self.availableKinds, mergeDists: gravityDists)
                self.matches = []
                if let next = self.findMatches(), !next.isEmpty { self.processMatches(next) }
                else { self.isProcessing = false; self.combo = 0; self.checkAndFixDeadlock() }
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
        for g in groups { for p in g.positions { grid[p.row][p.col] = nil } }
    }

    @discardableResult
    private func gravity() -> [UUID: Int] {
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

    private func spawn(_ kinds: [GemKind], mergeDists: [UUID: Int] = [:]) {
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
        deadlockMessage = "No moves! Reshuffling..."
        SoundEngine.shared.playDeadlock()
        isProcessing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
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
            self.isProcessing = false
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
                gameOverReason = "超时"
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

// MARK: - Placed gem for animation

struct PlacedGem: Identifiable {
    var id: UUID { gem.id }
    let gem: Gem
    let row: Int
    let col: Int
    let dropDistance: Int  // rows dropped, for entry animation
}

// MARK: - Views

struct GemView: View {
    let kind: GemKind; let size: CGFloat
    let selected: Bool; let matched: Bool
    let dropDistance: Int

    var body: some View {
        ZStack {
            // Main body with explicit gradient
            RoundedRectangle(cornerRadius: size * 0.18)
                .fill(
                    LinearGradient(colors: [
                        kind.color.opacity(0.9),
                        kind.color.opacity(0.5),
                        kind.color.opacity(0.35)
                    ], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size, height: size)
                // Highlight shine
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.18)
                        .fill(
                            LinearGradient(colors: [
                                .white.opacity(0.35),
                                .white.opacity(0.05),
                                .clear
                            ], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                // Border
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.18)
                        .stroke(selected ? Color.yellow : .white.opacity(0.2), lineWidth: selected ? 3 : 1.5)
                )
                // Selection glow
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.18)
                        .fill(Color.white.opacity(selected ? 0.2 : 0))
                )
                .shadow(color: kind.color.opacity(0.5), radius: 4, y: 3)
                .scaleEffect(matched ? 0.01 : selected ? 1.08 : 1.0)
                .opacity(matched ? 0 : 1)

            // Icon
            Image(systemName: kind.icon)
                .font(.system(size: size * 0.4, weight: .heavy))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                .scaleEffect(matched ? 1.5 : 1)
                .opacity(matched ? 0 : 1)
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.45), value: matched)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected)
    }
}

struct ParticleCanvas: View {
    let particles: [Particle]
    let flashRings: [FlashRing]
    var missile: Missile? = nil

    private func shapePath(shape: ParticleShape, center: CGPoint, size: CGFloat, rotation: Double) -> Path {
        let r = size / 2
        var path = Path()
        switch shape {
        case .circle:
            path.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r*2, height: r*2))
        case .burst:
            for i in 0..<8 {
                let a = Double(i) * .pi/4 + rotation
                let rad = i % 2 == 0 ? r : r * 0.5
                path.move(to: CGPoint(x: center.x, y: center.y))
                path.addLine(to: CGPoint(x: center.x + cos(a)*rad, y: center.y + sin(a)*rad))
            }
        case .rect:
            let w = size; let h = size * 0.65
            let cosR = cos(rotation); let sinR = sin(rotation)
            let hw = w/2; let hh = h/2
            let corners = [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]
            for (i, (cx, cy)) in corners.enumerated() {
                let rx = center.x + cx * cosR - cy * sinR
                let ry = center.y + cx * sinR + cy * cosR
                if i == 0 { path.move(to: CGPoint(x: rx, y: ry)) }
                else { path.addLine(to: CGPoint(x: rx, y: ry)) }
            }
            path.closeSubpath()
        }
        return path
    }

    var body: some View {
        Canvas { ctx, size in
            // Flash rings
            for r in flashRings {
                let rect = CGRect(x: r.x - r.radius, y: r.y - r.radius,
                                  width: r.radius * 2, height: r.radius * 2)
                ctx.opacity = r.opacity * 0.7
                ctx.stroke(Path(ellipseIn: rect), with: .color(r.color), lineWidth: r.lineWidth)
            }
            // Particles
            for p in particles {
                let path = shapePath(shape: p.shape, center: CGPoint(x: p.x, y: p.y),
                                     size: p.size, rotation: p.rotation * .pi / 180)
                ctx.opacity = min(p.life * 1.5, 1.0)
                ctx.fill(path, with: .color(p.color))
            }

            // Missile (cruise missile shape)
            if let m = missile {
                let mx = m.x; let my = m.y
                let angle = atan2(m.targetY - my, m.targetX - mx)
                let cosA = cos(angle); let sinA = sin(angle)

                // Body (elongated capsule)
                let bodyLen: CGFloat = 32
                let bodyW: CGFloat = 6
                let noseLen: CGFloat = 10
                let rearX = mx - cosA * bodyLen
                let rearY = my - sinA * bodyLen
                let noseTipX = mx + cosA * (bodyLen + noseLen)
                let noseTipY = my + sinA * (bodyLen + noseLen)

                var missilePath = Path()
                // Nose cone
                missilePath.move(to: CGPoint(x: noseTipX, y: noseTipY))
                missilePath.addLine(to: CGPoint(x: mx + sinA * bodyW, y: my - cosA * bodyW))
                missilePath.addLine(to: CGPoint(x: rearX + sinA * bodyW, y: rearY - cosA * bodyW))
                // Fins
                let finLen: CGFloat = 10
                missilePath.addLine(to: CGPoint(x: rearX + sinA * (bodyW + finLen), y: rearY - cosA * (bodyW + finLen)))
                missilePath.addLine(to: CGPoint(x: rearX + sinA * 2, y: rearY - cosA * 2))
                missilePath.addLine(to: CGPoint(x: rearX - sinA * 2, y: rearY + cosA * 2))
                missilePath.addLine(to: CGPoint(x: rearX - sinA * (bodyW + finLen), y: rearY + cosA * (bodyW + finLen)))
                missilePath.addLine(to: CGPoint(x: rearX - sinA * bodyW, y: rearY + cosA * bodyW))
                missilePath.addLine(to: CGPoint(x: mx - sinA * bodyW, y: my + cosA * bodyW))
                missilePath.closeSubpath()

                ctx.fill(missilePath, with: .color(Color(red:0.25, green:0.28, blue:0.32)))
                ctx.stroke(missilePath, with: .color(.white.opacity(0.6)), lineWidth: 1.5)

                // Exhaust flame (at rear)
                var flamePath = Path()
                let flameBaseX = rearX; let flameBaseY = rearY
                flamePath.move(to: CGPoint(x: flameBaseX + sinA * 4, y: flameBaseY - cosA * 4))
                flamePath.addLine(to: CGPoint(x: flameBaseX - cosA * 18 + sinA * 8, y: flameBaseY - sinA * 18 - cosA * 8))
                flamePath.addLine(to: CGPoint(x: flameBaseX - cosA * 20, y: flameBaseY - sinA * 20))
                flamePath.addLine(to: CGPoint(x: flameBaseX - cosA * 18 - sinA * 8, y: flameBaseY - sinA * 18 + cosA * 8))
                flamePath.addLine(to: CGPoint(x: flameBaseX - sinA * 4, y: flameBaseY + cosA * 4))
                flamePath.closeSubpath()
                ctx.fill(flamePath, with: .color(.orange))
                ctx.opacity = 0.6
                ctx.fill(flamePath, with: .color(.yellow))

                // Small inner flame
                ctx.opacity = 0.9
                var innerFlame = Path()
                innerFlame.move(to: CGPoint(x: flameBaseX + sinA * 2, y: flameBaseY - cosA * 2))
                innerFlame.addLine(to: CGPoint(x: flameBaseX - cosA * 10, y: flameBaseY - sinA * 10))
                innerFlame.addLine(to: CGPoint(x: flameBaseX - sinA * 2, y: flameBaseY + cosA * 2))
                innerFlame.closeSubpath()
                ctx.fill(innerFlame, with: .color(.white))
            }
        }
        .allowsHitTesting(false)
    }
}

struct ScorePopOverlay: View {
    let pops: [ScorePop]

    var body: some View {
        ZStack {
            ForEach(pops) { pop in
                Text(pop.text)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange, .red], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .orange.opacity(0.6), radius: 8, x: 0, y: 0)
                    .opacity(pop.opacity)
                    .offset(y: pop.offset)
                    .position(pop.position)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Theme background

struct ThemeBackgroundView: View {
    let petals: [BgPetal]
    let theme: Theme

    var body: some View {
        Canvas { ctx, size in
            for p in petals {
                let cx = p.x; let cy = p.y
                ctx.opacity = p.opacity
                switch theme {
                case .sakura:
                    // Cherry blossom petal
                    let r = p.size / 2
                    var path = Path()
                    path.move(to: CGPoint(x: cx, y: cy - r))
                    path.addCurve(to: CGPoint(x: cx + r, y: cy),
                                  control1: CGPoint(x: cx + r*0.4, y: cy - r*0.6),
                                  control2: CGPoint(x: cx + r*0.7, y: cy - r*0.15))
                    path.addCurve(to: CGPoint(x: cx, y: cy + r*0.3),
                                  control1: CGPoint(x: cx + r*0.5, y: cy + r*0.2),
                                  control2: CGPoint(x: cx + r*0.1, y: cy + r*0.3))
                    path.addCurve(to: CGPoint(x: cx - r, y: cy),
                                  control1: CGPoint(x: cx - r*0.1, y: cy + r*0.3),
                                  control2: CGPoint(x: cx - r*0.5, y: cy + r*0.2))
                    path.addCurve(to: CGPoint(x: cx, y: cy - r),
                                  control1: CGPoint(x: cx - r*0.7, y: cy - r*0.15),
                                  control2: CGPoint(x: cx - r*0.4, y: cy - r*0.6))
                    ctx.fill(path, with: .color(Color(red:1, green:0.55, blue:0.7).opacity(p.opacity)))
                case .seaside:
                    // Filled bubble with highlight
                    let r = p.size / 2
                    let rect = CGRect(x: cx - r, y: cy - r, width: p.size, height: p.size)
                    // Outer bubble shell
                    ctx.opacity = p.opacity * 0.35
                    ctx.fill(Path(ellipseIn: rect), with: .color(Color(red:0.4, green:0.85, blue:1.0)))
                    // White highlight spot
                    let hx = cx - r * 0.3
                    let hy = cy - r * 0.35
                    let hr = r * 0.25
                    ctx.opacity = p.opacity * 0.7
                    ctx.fill(Path(ellipseIn: CGRect(x: hx - hr, y: hy - hr, width: hr*2, height: hr*2)),
                             with: .color(.white))
                    // Edge shimmer
                    ctx.opacity = p.opacity * 0.5
                    ctx.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.4)), lineWidth: 1)
                case .skynet:
                    // Glowing dot / spark
                    let rect = CGRect(x: cx - 1.5, y: cy - 1.5, width: 3, height: 3)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.red.opacity(p.opacity)))
                }
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var board = GameBoard()

    var body: some View {
        ZStack {
            LinearGradient(colors: board.theme.bgGradient,
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Background theme particles
            ThemeBackgroundView(petals: board.bgPetals, theme: board.theme)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { geo in
                let cellSize = min(geo.size.width, geo.size.height - 280) / CGFloat(GameBoard.cols) - 4
                let _ = { board.cellPx = cellSize }()
                let _ = { board.windowWidth = geo.size.width }()
                let _ = { board.windowHeight = geo.size.height }()

                VStack(spacing: 4) {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Match Three")
                                .font(.largeTitle.weight(.black))
                                .foregroundColor(board.theme.textColor)
                            HStack(spacing: 4) {
                                ForEach(0..<board.activeKinds, id:\.self) { i in
                                    Circle().fill(GemKind.normalKinds[i].color).frame(width: 8, height: 8)
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Picker("模式", selection: $board.gameMode) {
                                ForEach(GameMode.allCases, id: \.self) { m in
                                    Text(m.rawValue).tag(m)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(board.theme.textColor)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .onChange(of: board.gameMode) { _, _ in board.newGame() }

                            Picker("主题", selection: $board.theme) {
                                ForEach(Theme.allCases, id: \.self) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(board.theme.textColor)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())

                            Picker("特效", selection: $board.nukeStyle) {
                                ForEach(NukeStyle.allCases, id: \.self) { style in
                                    Text(style.rawValue).tag(style)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(board.theme.textColor)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())

                            Toggle(isOn: Binding(
                                get: { SoundEngine.isEnabled },
                                set: { SoundEngine.isEnabled = $0 }
                            )) {
                                Image(systemName: SoundEngine.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .foregroundColor(board.theme.textColor)
                            }
                            .toggleStyle(.button)
                            .buttonStyle(.plain)

                            Text("\(board.score)")
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundColor(board.theme.scoreColor)
                                .shadow(color: board.theme.isDark ? .orange.opacity(0.5) : .clear, radius: 4)
                            Text("Best \(board.highScore)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(board.highScore > 0 ? board.theme.dimColor : .clear)
                            Text("Combo x\(max(board.combo, 1))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.orange)
                                .scaleEffect(board.combo >= 3 ? 1.2 : 1)
                                .opacity(board.combo > 1 ? 1 : 0)
                        }
                    }
                    .padding(.horizontal, 8)

                    // Ranked mode status
                    if board.gameMode == .ranked {
                        HStack(spacing: 20) {
                            Label("失败 \(board.failedSwaps)/5", systemImage: "xmark.circle")
                                .foregroundColor(board.failedSwaps >= 3 ? .red : board.theme.textColor)
                            Spacer()
                            Label(String(format: "%.1fs", board.lastTimeDisplay), systemImage: "timer")
                                .foregroundColor(board.timeRemaining < 3 ? .red : board.theme.scoreColor)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 4)
                    }

                    // Deadlock notification (always occupies space)
                    Text(board.deadlockMessage ?? " ")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(board.theme.textColor)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(board.deadlockMessage != nil ? Color.orange.opacity(0.9) : Color.clear)
                        .clipShape(Capsule())
                        .opacity(board.deadlockMessage != nil ? 1 : 0)

                    // Grid
                    ZStack {
                        // Board background
                        RoundedRectangle(cornerRadius: 12)
                            .fill(board.theme.boardBg)
                            .frame(width: CGFloat(GameBoard.cols) * (cellSize + 2) + 8,
                                   height: CGFloat(GameBoard.rows) * (cellSize + 2) + 8)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(board.theme.boardStroke, lineWidth: 1))

                        // Gems positioned absolutely with spring animation
                        ForEach(board.placedGems) { placed in
                            let pos = Position(row: placed.row, col: placed.col)
                            let x = CGFloat(placed.col) * (cellSize + 2) + cellSize / 2 + 6
                            let y = CGFloat(placed.row) * (cellSize + 2) + cellSize / 2 + 6

                            GemView(kind: placed.gem.kind, size: cellSize,
                                    selected: board.selectedPosition == pos,
                                    matched: board.matches.contains(where: { $0.positions.contains(pos) }),
                                    dropDistance: placed.dropDistance)
                                .position(x: x, y: y)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.3).combined(with: .opacity),
                                    removal: .scale(scale: 0.01).combined(with: .opacity)
                                ))
                                .onTapGesture { board.tap(row: placed.row, col: placed.col) }
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 15)
                                        .onEnded { value in
                                            let dx = value.translation.width
                                            let dy = value.translation.height
                                            let fromRow = placed.row
                                            let fromCol = placed.col
                                            var toRow = fromRow
                                            var toCol = fromCol
                                            if abs(dx) > abs(dy) {
                                                toCol = dx > 0 ? fromCol + 1 : fromCol - 1
                                            } else {
                                                toRow = dy > 0 ? fromRow + 1 : fromRow - 1
                                            }
                                            guard toRow >= 0, toRow < GameBoard.rows,
                                                  toCol >= 0, toCol < GameBoard.cols else { return }
                                            board.tap(row: fromRow, col: fromCol)
                                            board.tap(row: toRow, col: toCol)
                                        }
                                )
                        }

                        // Game over overlay (on top of gems)
                        if board.gameOver {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.black)
                                .frame(width: CGFloat(GameBoard.cols) * (cellSize + 2) + 8,
                                       height: CGFloat(GameBoard.rows) * (cellSize + 2) + 8)
                            VStack(spacing: 20) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                                Text("游戏结束")
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(.white)
                                Text(board.gameOverReason)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.red)
                                Text("得分: \(board.score)")
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(.yellow)
                                Button {
                                    board.newGame()
                                } label: {
                                    Text("再来一局")
                                        .font(.system(size: 20, weight: .bold))
                                        .padding(.horizontal, 40).padding(.vertical, 14)
                                        .background(Color.orange)
                                        .clipShape(Capsule())
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(width: CGFloat(GameBoard.cols) * (cellSize + 2) + 8,
                           height: CGFloat(GameBoard.rows) * (cellSize + 2) + 8)
                    .overlay(
                        ParticleCanvas(particles: board.particles, flashRings: board.flashRings, missile: board.missile)
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        ScorePopOverlay(pops: board.scorePops)
                            .allowsHitTesting(false)
                    )

                    // Button
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { board.newGame() }
                    } label: {
                        Label("New Game", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .padding(.horizontal, 28).padding(.vertical, 10)
                            .background(board.theme.isDark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black.opacity(0.08)))
                            .clipShape(Capsule())
                            .foregroundColor(board.theme.textColor)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(12)
            }
        }
        .frame(minWidth: 400, minHeight: 650)
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
            board.tickParticles(dt: 0.016)
            board.tickScorePops()
            if board.tickFrame % 3 == 0 { board.tickBackground(dt: 0.05, width: board.windowWidth, height: board.windowHeight) }
        }
    }
}

// MARK: - App

@main
struct MatchThreeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentSize)
    }
}
