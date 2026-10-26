import Foundation

enum AppDefaults {
    /// Placeholder used for the very first launch. The app labels it clearly and
    /// does not fetch it; widgets fall back to it so they still show something
    /// before the app has been configured.
    static let handle = "tourist"

    /// Read from `AppGroupID` in Info.plist, which is filled in from `APP_GROUP`
    /// in `Config/Identity.xcconfig` at build time. That keeps "which App Group"
    /// out of the source, so anyone can build this repo with their own identity.
    static var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? fallbackAppGroupID
    }

    /// Used by the standalone test harness, which has no app bundle.
    static let fallbackAppGroupID = "group.com.vanshkharb.homejudge"
}

/// The bridge between the app and the widget extension.
///
/// `UserDefaults` backed by an App Group is the right tool here: the payload is
/// a few kilobytes of JSON and both processes read it constantly.
enum SharedStore {
    private static let snapshotsKey = "cf.snapshots"
    private static let primaryHandleKey = "cf.primaryHandle"

    /// Stops a user who tries a dozen handles from filling the container.
    private static let maxCachedHandles = 4

    /// `true` when the App Group is genuinely provisioned.
    ///
    /// This is the only reliable check: `UserDefaults(suiteName:)` returns a
    /// usable object even when the group does not exist, so it silently writes
    /// somewhere nobody else can read. Simulator builds without a development
    /// team have their entitlements stripped, and so does any build where the
    /// capability could not be added — in both cases the app and the widget
    /// cannot share a cache.
    static let isAppGroupAvailable: Bool =
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppDefaults.appGroupID) != nil

    /// Falls back to `.standard` when the group is unavailable. Widgets then do
    /// not see the app's cache, but each one still fetches for itself.
    static var defaults: UserDefaults {
        if isAppGroupAvailable, let shared = UserDefaults(suiteName: AppDefaults.appGroupID) {
            return shared
        }
        return .standard
    }

    // MARK: Handle

    static var primaryHandle: String {
        get {
            let stored = Handle.normalize(defaults.string(forKey: primaryHandleKey) ?? "")
            return stored.isEmpty ? AppDefaults.handle : stored
        }
        set {
            defaults.set(Handle.normalize(newValue), forKey: primaryHandleKey)
        }
    }

    /// `false` until the user actually saves a handle in the app, which is what
    /// lets the first launch explain itself instead of showing a stranger's stats.
    static var hasSavedHandle: Bool {
        !Handle.normalize(defaults.string(forKey: primaryHandleKey) ?? "").isEmpty
    }

    // MARK: Snapshots

    static func snapshot(for handle: String) -> StatsSnapshot? {
        allSnapshots()[Handle.normalize(handle)]
    }

    static func save(_ snapshot: StatsSnapshot) {
        var cache = allSnapshots()

        // A widget's light scan must not overwrite the app's exact solved count.
        let stored = cache[snapshot.handle]?.merging(newer: snapshot) ?? snapshot
        cache[snapshot.handle] = stored

        if cache.count > maxCachedHandles {
            let kept = cache
                .sorted { $0.value.generatedAt > $1.value.generatedAt }
                .prefix(maxCachedHandles)
            cache = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
        }

        persist(cache)
    }

    static func removeAll() {
        persist([:])
    }

    /// Handles with a cached snapshot, most recently refreshed first.
    static func cachedHandles() -> [String] {
        allSnapshots()
            .sorted { $0.value.generatedAt > $1.value.generatedAt }
            .map(\.key)
    }

    // MARK: Storage

    private static func allSnapshots() -> [String: StatsSnapshot] {
        guard let data = defaults.data(forKey: snapshotsKey) else { return [:] }
        return (try? JSONDecoder.cf.decode([String: StatsSnapshot].self, from: data)) ?? [:]
    }

    private static func persist(_ cache: [String: StatsSnapshot]) {
        guard let data = try? JSONEncoder.cf.encode(cache) else { return }
        defaults.set(data, forKey: snapshotsKey)
    }
}

// MARK: - Coders

extension JSONEncoder {
    static let cf: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension JSONDecoder {
    static let cf: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
