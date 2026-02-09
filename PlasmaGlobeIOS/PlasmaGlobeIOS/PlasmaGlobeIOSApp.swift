import SwiftUI

@main
struct PlasmaGlobeIOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .ignoresSafeArea()
                .persistentSystemOverlays(.hidden)
                .statusBarHidden(true)
        }
    }
}
