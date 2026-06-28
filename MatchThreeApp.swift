import SwiftUI

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
