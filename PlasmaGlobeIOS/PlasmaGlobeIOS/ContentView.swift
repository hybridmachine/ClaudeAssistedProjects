import SwiftUI

struct ContentView: View {
    @StateObject private var touchHandler = TouchHandler()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        MetalView(touchHandler: touchHandler)
            .ignoresSafeArea()
            .onChange(of: scenePhase) { newPhase in
                touchHandler.isActive = (newPhase == .active)
            }
    }
}
