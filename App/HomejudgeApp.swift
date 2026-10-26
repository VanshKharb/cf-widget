import SwiftUI

@main
struct HomejudgeApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(model)        }
    }
}
