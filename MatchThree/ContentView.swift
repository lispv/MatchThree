import SwiftUI

struct ContentView: View {
    @StateObject private var board = GameBoard()

    var body: some View {
        GeometryReader { geo in
            let cellSize = min(geo.size.width, geo.size.height - 100) / CGFloat(GameBoard.cols) - 4

            VStack(spacing: 16) {
                Text("Match Three")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                Text("Score: \(board.score)")
                    .font(.title2)
                    .foregroundColor(.yellow)

                GameGridView(board: board, cellSize: cellSize)
                    .frame(maxWidth: min(geo.size.width, geo.size.height - 100))

                Button(action: { board.score = 0; resetBoard() }) {
                    Text("New Game")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.3),
                                    Color(red: 0.05, green: 0.05, blue: 0.15)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func resetBoard() {
        // Simple reset: create new board
        board.grid = Array(repeating: Array(repeating: nil, count: GameBoard.cols), count: GameBoard.rows)
        board.selectedPosition = nil
        board.matches = []
        board.isProcessing = false
        for r in 0..<GameBoard.rows {
            for c in 0..<GameBoard.cols {
                board.grid[r][c] = Gem.random()
            }
        }
        // Resolve initial matches
        Task { @MainActor in
            board.isProcessing = true
            board.processMatchChain()
        }
    }
}
