import SwiftUI

@main
struct CFWidgetApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(model)        }
    }
}
