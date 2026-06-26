import SwiftUI

struct GameGridView: View {
    @ObservedObject var board: GameBoard
    let cellSize: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<GameBoard.rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<GameBoard.cols, id: \.self) { col in
                        if let gem = board.grid[row][col] {
                            let pos = Position(row: row, col: col)
                            let isSelected = board.selectedPosition == pos
                            let isMatched = board.matches.contains(where: { $0.positions.contains(pos) })

                            GemView(gem: gem, size: cellSize,
                                    isSelected: isSelected,
                                    isMatched: isMatched)
                                .onTapGesture {
                                    board.tap(row: row, col: col)
                                }
                        } else {
                            Color.clear
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
