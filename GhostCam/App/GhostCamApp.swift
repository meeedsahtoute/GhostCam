import SwiftUI

@main
struct GhostCamApp: App {
    init() {
        // Prepare haptics and motion updates on launch
        _ = HapticsManager.shared
        _ = MotionManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .statusBar(hidden: true)
        }
    }
}
