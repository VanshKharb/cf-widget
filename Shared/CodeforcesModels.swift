import Foundation

// MARK: - Envelope

/// Every Codeforces API call returns `{"status": "OK", "result": ...}`.
/// On failure `result` is absent and `comment` explains what went wrong.
struct CFEnvelope<Result: Decodable>: Decodable {
    let status: String
    let comment: String?
    let result: Result?
}

// MARK: - user.info

struct CFUser: Decodable, Sendable {
    let handle: String
    let firstName: String?
    let lastName: String?
    let country: String?
    let city: String?
    let organization: String?
    let contribution: Int?
    let friendOfCount: Int?
    let rating: Int?
    let maxRating: Int?
    let rank: String?
    let maxRank: String?
    let avatar: String?
    let titlePhoto: String?
    let registrationTimeSeconds: Int?

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? handle : parts.joined(separator: " ")
    }

    var isRated: Bool { (rating ?? 0) > 0 }
}

// MARK: - user.rating

struct CFRatingChange: Decodable, Sendable {
    let contestId: Int
    let contestName: String
    let rank: Int
    let ratingUpdateTimeSeconds: Int
    let oldRating: Int
    let newRating: Int
}

// MARK: - user.status

/// Only the handful of fields the widget needs are declared. Swift's synthesized
/// `Decodable` ignores everything else, which keeps a 10 000-submission payload
/// cheap to decode and light on memory.
struct CFSubmission: Decodable, Sendable {
    struct Problem: Decodable, Sendable {
        let contestId: Int?
        let index: String?
        let name: String?
        let rating: Int?
    }

    let creationTimeSeconds: Int
    let verdict: String?
    let problem: Problem

    var isAccepted: Bool { verdict == "OK" }

    /// Stable identity of a problem, e.g. `2271-H1`. `nil` for problems that
    /// belong to no contest (Polygon drafts, some gym entries).
    var problemKey: String? {
        guard let contestId = problem.contestId, let index = problem.index else { return nil }
        return "\(contestId)-\(index)"
    }
}

// MARK: - contest.list

struct CFContest: Decodable, Sendable {
    let id: Int
    let name: String
    let phase: String
    let durationSeconds: Int
    let startTimeSeconds: Int?

    var isUpcoming: Bool { phase == "BEFORE" }
}
