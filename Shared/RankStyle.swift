import SwiftUI

/// Codeforces' real rank ladder, colours and rating bands, so the widgets speak
/// the same visual language as the site.
enum RankStyle {
    struct Info: Sendable {
        let key: String
        let title: String
        let short: String
        let light: UInt32
        let dark: UInt32
    }

    static let unrated = Info(key: "unrated", title: "Unrated", short: "—", light: 0x8A8A8E, dark: 0x9AA0A6)

    static let ladder: [Info] = [
        Info(key: "newbie", title: "Newbie", short: "N", light: 0x808080, dark: 0x9AA0A6),
        Info(key: "pupil", title: "Pupil", short: "P", light: 0x008000, dark: 0x4CAF50),
        Info(key: "specialist", title: "Specialist", short: "S", light: 0x03A89E, dark: 0x2BC4BA),
        // Codeforces' pure #0000FF is unreadable on a dark widget.
        Info(key: "expert", title: "Expert", short: "E", light: 0x1F5FE0, dark: 0x6E9BFF),
        Info(key: "candidate master", title: "Candidate Master", short: "CM", light: 0xAA00AA, dark: 0xE060E0),
        Info(key: "master", title: "Master", short: "M", light: 0xFF8C00, dark: 0xFFA733),
        Info(key: "international master", title: "International Master", short: "IM", light: 0xFF8C00, dark: 0xFFA733),
        Info(key: "grandmaster", title: "Grandmaster", short: "GM", light: 0xFF0000, dark: 0xFF5252),
        Info(key: "international grandmaster", title: "International Grandmaster", short: "IGM", light: 0xFF0000, dark: 0xFF5252),
        Info(key: "legendary grandmaster", title: "Legendary Grandmaster", short: "LGM", light: 0xFF0000, dark: 0xFF5252),
    ]

    /// `(minimum rating, rank)` — the bands Codeforces actually uses.
    private static let bands: [(threshold: Int, rank: Info)] = [
        (0, ladder[0]),
        (1200, ladder[1]),
        (1400, ladder[2]),
        (1600, ladder[3]),
        (1900, ladder[4]),
        (2100, ladder[5]),
        (2300, ladder[6]),
        (2400, ladder[7]),
        (2600, ladder[8]),
        (3000, ladder[9]),
    ]

    static func info(for rank: String?) -> Info {
        guard let key = rank?.lowercased(), !key.isEmpty else { return unrated }
        // Codeforces reports titles as free text ("legendary grandmaster").
        return ladder.first { $0.key == key } ?? unrated
    }

    static func title(for rank: String?) -> String { info(for: rank).title }

    static func short(for rank: String?) -> String { info(for: rank).short }

    static func color(for rank: String?) -> Color {
        let info = info(for: rank)
        return .adaptive(light: info.light, dark: info.dark)
    }

    // MARK: Rating bands

    static func currentBand(for rating: Int?) -> (threshold: Int, rank: Info) {
        guard let rating else { return bands[0] }
        return bands.last { $0.threshold <= rating } ?? bands[0]
    }

    static func nextBand(for rating: Int?) -> (threshold: Int, rank: Info)? {
        guard let rating else { return nil }
        return bands.first { $0.threshold > rating }
    }

    /// Progress from the current band's floor to the next band, `0...1`.
    /// `nil` for an unrated user or a legendary grandmaster with nothing left to climb.
    static func progress(for rating: Int?) -> Double? {
        guard let rating, let next = nextBand(for: rating) else { return nil }
        let current = currentBand(for: rating)
        let span = Double(next.threshold - current.threshold)
        guard span > 0 else { return nil }
        return min(max(Double(rating - current.threshold) / span, 0), 1)
    }
}
