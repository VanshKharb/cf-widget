import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    accountCard(handle: $model.handle)

                    if let message = model.errorMessage {
                        errorCard(message)
                    }

                    if let snapshot = model.snapshot {
                        profileCard(snapshot)

                        if let last = snapshot.lastContest {
                            lastContestCard(last)
                        }

                        ratingsCard(snapshot)
                        heatmapCard(snapshot)
                        activityCard(snapshot)
                        contestsCard(snapshot)
                    } else if !model.isLoading {
                        emptyCard
                    }

                    homeScreenHintCard
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Homejudge")
            .refreshable { await model.refresh() }
            .task { await model.refreshIfStale() }
        }
    }

    // MARK: - Account

    private func accountCard(handle: Binding<String>) -> some View {
        Card(title: "Account") {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(.secondary)

                TextField("Codeforces handle", text: handle)
                    .font(.system(size: 15, weight: .medium))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { Task { await model.refresh() } }

                if model.isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                Color(uiColor: .tertiarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )

            Button {
                Task { await model.refresh() }
            } label: {
                Label(
                    model.isLoading ? "Scanning up to 10,000 submissions…" : "Refresh stats",
                    systemImage: "arrow.clockwise"
                )
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.isLoading)

            if let snapshot = model.snapshot {
                Text("Last updated \(Fmt.relativePast(snapshot.generatedAt)) · \(Fmt.compact(snapshot.scannedSubmissions)) submissions scanned")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if !SharedStore.isAppGroupAvailable {
                Label(
                    "App Group unavailable on this build, so widgets can't read this cache — they fetch their own data instead.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Profile

    private func profileCard(_ snapshot: StatsSnapshot) -> some View {
        Card(title: "Profile") {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.rating.map(String.init) ?? "–")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(RankStyle.color(for: snapshot.rank))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    HStack(spacing: 6) {
                        Text(RankStyle.title(for: snapshot.rank))
                            .font(.system(size: 12, weight: .semibold))
                        Text("max \(snapshot.maxRating.map(String.init) ?? "–")")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(snapshot.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    if let country = snapshot.country {
                        Text(country)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Text("\(snapshot.friendOfCount ?? 0) friends")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            if let progress = RankStyle.progress(for: snapshot.rating),
               let next = RankStyle.nextBand(for: snapshot.rating),
               let rating = snapshot.rating {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .tint(RankStyle.color(for: next.rank.key))
                    Text("\(next.threshold - rating) points to \(next.rank.title)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
    }

    private func lastContestCard(_ last: ContestResult) -> some View {
        Card(title: "Last contest") {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(last.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                    Text("Rank \(last.rankDisplay) · \(Fmt.relativePast(last.date))")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(last.delta >= 0 ? "+" : "")\(last.delta)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(last.isGain ? Color.green : Color.red)
                    Text("\(last.oldRating) → \(last.newRating)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Ratings

    private func ratingsCard(_ snapshot: StatsSnapshot) -> some View {
        let change = snapshot.ratingChangeOverHistory

        return Card(title: "Rating") {
            if let change {
                Text("\(change >= 0 ? "+" : "")\(change) over the last \(snapshot.ratingHistory.count) contests")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(change >= 0 ? Color.green : Color.red)
            }

            RatingChart(points: snapshot.ratingHistory, accent: RankStyle.color(for: snapshot.rank))
        }
    }

    // MARK: - Heatmap

    private func heatmapCard(_ snapshot: StatsSnapshot) -> some View {
        let grid = snapshot.heatmap(weeks: 26)

        return Card(title: "Submissions") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Fmt.compact(grid.totalSubmissions))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("submissions in 26 weeks")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                StreakBadge(days: grid.currentStreak)
            }

            // Sizing off a fixed height makes the grid collapse into a small
            // centred block on a wide screen. A ratio lets the cells scale with
            // the card's width instead. 26 columns by 7 rows, plus room for the
            // month-label strip.
            HeatmapGridView(grid: grid, spacing: 2.5, cornerRadius: 2, showsMonthLabels: true)
                .aspectRatio(3.2, contentMode: .fit)
                .padding(.vertical, 2)

            HStack(spacing: 10) {
                Text("\(grid.activeDays) active days")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("longest streak \(grid.longestStreak)d")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                HeatmapLegend()
            }

            if grid.isTruncated || snapshot.isPartialScan {
                Text("Based on the \(Fmt.compact(snapshot.scannedSubmissions)) most recent submissions, so older activity may be missing.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Activity

    private func activityCard(_ snapshot: StatsSnapshot) -> some View {
        let grid = snapshot.heatmap(weeks: 26)

        return Card(title: "Activity") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                MetricTile(value: Fmt.compact(snapshot.solvedCount), label: snapshot.isPartialScan ? "solved (partial)" : "solved")
                MetricTile(value: Fmt.compact(snapshot.scannedSubmissions), label: "submissions")
                MetricTile(value: snapshot.acceptanceRate.map { "\(Int($0 * 100))%" } ?? "–", label: "accepted")
                MetricTile(value: "\(snapshot.ratedContestCount)", label: "contests")
                MetricTile(value: "\(grid.currentStreak)d", label: "current streak", tint: .orange)
                MetricTile(value: "\(grid.longestStreak)d", label: "longest streak", tint: .orange)
            }
        }
    }

    // MARK: - Contests

    private func contestsCard(_ snapshot: StatsSnapshot) -> some View {
        Card(title: "Upcoming contests") {
            if snapshot.upcoming.isEmpty {
                Text("No rounds announced right now.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(snapshot.upcoming) { contest in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contest.name)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(2)
                            HStack(spacing: 6) {
                                Text(Fmt.countdown(to: contest.start))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.blue)
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text(Fmt.shortDateTime(contest.start))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text("· \(Fmt.duration(contest.durationSeconds))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty / error / hint

    private var emptyCard: some View {
        Card(title: model.showsPlaceholderHandle ? "Set your handle" : "No data yet") {
            VStack(alignment: .leading, spacing: 6) {
                if model.showsPlaceholderHandle {
                    Text("“\(model.handle)” is just a placeholder. Replace it above with your own Codeforces handle and tap Refresh.")
                } else {
                    Text("Type your Codeforces handle above and tap Refresh.")
                }
                Text("Everything comes from the public Codeforces API, so there is no login and no password.")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 13))
        }
    }

    private func errorCard(_ message: String) -> some View {
        Card(title: "Could not refresh") {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var homeScreenHintCard: some View {
        Card(title: "Put it on your Home Screen") {
            VStack(alignment: .leading, spacing: 6) {
                hintRow(1, "Touch and hold an empty spot on your Home Screen.")
                hintRow(2, "Tap Edit, then Add Widget, and search for Homejudge.")
                hintRow(3, "Choose Stats, Heatmap or Upcoming Contests.")
            }
            Text("Each widget can point at a different handle — edit it after placing it.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private func hintRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 17, height: 17)
                .background(Color.blue, in: Circle())
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
