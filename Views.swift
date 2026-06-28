import SwiftUI

// MARK: - Gem View

struct GemView: View {
    let kind: GemKind; let size: CGFloat
    let selected: Bool; let matched: Bool
    let dropDistance: Int

    var body: some View {
        ZStack {
            // Main body — rainbow gets multi-color gradient, normal gets single color
            Group {
                if kind.name == "rainbow" {
                    RoundedRectangle(cornerRadius: size * 0.18)
                        .fill(
                            LinearGradient(colors: [
                                Color(red: 1, green: 0.2, blue: 0.2),
                                Color(red: 1, green: 0.7, blue: 0),
                                Color(red: 0.1, green: 0.9, blue: 0.3),
                                Color(red: 0.1, green: 0.5, blue: 1),
                                Color(red: 0.7, green: 0.1, blue: 0.9),
                            ], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                } else {
                    RoundedRectangle(cornerRadius: size * 0.18)
                        .fill(
                            LinearGradient(colors: [
                                kind.color.opacity(0.9),
                                kind.color.opacity(0.5),
                                kind.color.opacity(0.35)
                            ], startPoint: .top, endPoint: .bottom)
                        )
                }
            }
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
        // Rainbow gem overlay: multi-color gradient + special icon
        .overlay {
            if kind.isRainbow {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.18)
                        .fill(
                            LinearGradient(colors: [
                                Color(red: 1, green: 0.2, blue: 0.2),
                                Color(red: 1, green: 0.7, blue: 0),
                                Color(red: 0.1, green: 0.9, blue: 0.3),
                                Color(red: 0.1, green: 0.5, blue: 1),
                                Color(red: 0.7, green: 0.1, blue: 0.9),
                            ], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .opacity(0.85)
                        .frame(width: size, height: size)
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: size * 0.4, weight: .heavy))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.45), value: matched)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected)
    }
}

// MARK: - Particle Canvas

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

// MARK: - Score Pop Overlay

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

// MARK: - Content View

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
                        Button {
                            HighScoreManager.save(board.score, for: board.gameMode)
                            withAnimation(.easeInOut(duration: 0.3)) { board.newGame() }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(board.theme.textColor)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Picker("Mode", selection: $board.gameMode) {
                                ForEach(GameMode.allCases, id: \.self) { m in
                                    Text(m.rawValue).tag(m)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(board.theme.textColor)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .disabled(board.isProcessing || board.gameOver)
                            .onChange(of: board.gameMode) { oldMode, _ in
                                // Score so far was earned in the OLD mode; save it
                                // before the new game resets under the new mode.
                                HighScoreManager.save(board.score, for: oldMode)
                                board.newGame()
                            }

                            Picker("Theme", selection: $board.theme) {
                                ForEach(Theme.allCases, id: \.self) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(board.theme.textColor)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .disabled(board.isProcessing || board.gameOver)

                            Picker("Effect", selection: $board.nukeStyle) {
                                ForEach(NukeStyle.allCases, id: \.self) { style in
                                    Text(style.rawValue).tag(style)
                                }
                            }
                            .pickerStyle(.menu)
                            .foregroundColor(board.theme.textColor)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .disabled(board.isProcessing || board.gameOver)

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
                            Text("Best: \(board.highScore)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(board.highScore > 0 ? board.theme.dimColor : .clear)
                            Text("Combo ×\(max(board.combo, 1))")
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
                            Label("Failed \(board.failedSwaps)/5", systemImage: "xmark.circle")
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
                                Text("Game Over")
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(.white)
                                Text(board.gameOverReason)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.red)
                                Text("Score: \(board.score)")
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(.yellow)
                                Button {
                                    HighScoreManager.save(board.score, for: board.gameMode)
                                    board.newGame()
                                } label: {
                                    Text("Play Again")
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

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(12)
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                board.windowWidth = size.width
                board.windowHeight = size.height
                board.cellPx = min(size.width, size.height - 280) / CGFloat(GameBoard.cols) - 4
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
