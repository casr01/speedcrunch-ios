// SpeedCrunchApp.swift — app entry point.

import SwiftUI

@main
struct SpeedCrunchApp: App {
    @StateObject private var model = CalculatorModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                model.save()
            }
        }
    }
}
