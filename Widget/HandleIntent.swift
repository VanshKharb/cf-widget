import AppIntents
import WidgetKit

/// Lets the user type a handle straight into the widget's edit sheet, so the
/// widget is useful before the app has ever been opened.
struct HandleIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Codeforces account" }
    static var description: IntentDescription? {
        IntentDescription("Show stats for a Codeforces handle.")
    }

    @Parameter(title: "Handle", description: "Leave empty to use the handle saved in the app.")
    var handle: String?

    init() {}

    init(handle: String?) {
        self.handle = handle
    }
}

/// Powers the in-widget refresh button. Widgets run in their own process, so
/// this must not try to open the app.
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource { "Refresh Codeforces stats" }
    static var description: IntentDescription? {
        IntentDescription("Fetch the latest Codeforces data right now.")
    }

    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Handle")
    var handle: String

    init() {}

    init(handle: String) {
        self.handle = handle
    }

    func perform() async throws -> some IntentResult {
        let handle = Handle.normalize(handle)
        guard !handle.isEmpty else { return .result() }

        if let fresh = try? await SnapshotLoader.load(handle: handle, options: .light) {
            // Goes through the merge, so this can never replace the app's more
            // accurate solved count with a shallower one.
            SharedStore.save(fresh)
        }

        return .result()
    }
}
