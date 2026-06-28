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

    func playRainbow() {
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

    var isRainbow: Bool { name == "rainbow" }

    static let normalKinds: [GemKind] = [
        GemKind(name: "ruby",    color: Color(red: 1.00, green: 0.08, blue: 0.15), icon: "heart.fill"),
        GemKind(name: "emerald", color: Color(red: 0.05, green: 0.95, blue: 0.25), icon: "leaf.fill"),
        GemKind(name: "sapphire",color: Color(red: 0.10, green: 0.50, blue: 1.00), icon: "drop.fill"),
        GemKind(name: "topaz",   color: Color(red: 1.00, green: 0.55, blue: 0.00), icon: "flame.fill"),
        GemKind(name: "amethyst",color: Color(red: 0.75, green: 0.05, blue: 1.00), icon: "star.fill"),
        GemKind(name: "diamond", color: Color(red: 0.80, green: 0.95, blue: 1.00), icon: "sparkles"),
        GemKind(name: "obsidian",color: Color(red: 0.30, green: 0.30, blue: 0.38), icon: "moon.fill"),
    ]
    static let rainbow: GemKind = GemKind(name: "rainbow", color: Color(red: 1.00, green: 0.50, blue: 0.00), icon: "star.circle.fill")
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
    case missile = "Missile"
    case blocks = "Blocks"
}

enum GameMode: String, CaseIterable {
    case casual = "Casual"
    case ranked = "Ranked"
}

enum Theme: String, CaseIterable {
    case skynet = "Skynet"
    case sakura = "Sakura"
    case seaside = "Seaside"

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

// MARK: - Placed gem for animation

struct PlacedGem: Identifiable {
    var id: UUID { gem.id }
    let gem: Gem
    let row: Int
    let col: Int
    let dropDistance: Int  // rows dropped, for entry animation
}
