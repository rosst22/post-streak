import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var choosingPlatform = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let stats = store.stats {
                    HStack(spacing: 12) {
                        MetricCard(
                            value: "\(stats.currentStreak)",
                            label: "week streak",
                            symbol: "flame.fill"
                        )
                        MetricCard(
                            value: "\(stats.currentWeekPosts)/\(stats.weeklyTarget)",
                            label: "this week",
                            symbol: "target"
                        )
                    }

                    ProgressView(
                        value: min(Double(stats.currentWeekPosts), Double(stats.weeklyTarget)),
                        total: Double(stats.weeklyTarget)
                    )
                    .tint(.green)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("365 days").font(.headline)
                        HeatmapView(days: stats.heatmap)
                        Text("Longest streak: \(stats.longestStreak) weeks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !store.posts.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Recent posts")
                                .font(.headline)
                                .padding(.bottom, 6)
                            ForEach(Array(store.posts.prefix(5).enumerated()), id: \.element.id) { index, post in
                                HStack(spacing: 12) {
                                    Image(systemName: post.platform.symbol)
                                        .foregroundStyle(.green)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(post.platform.label)
                                            .font(.subheadline.weight(.medium))
                                        Text(post.postedAt, style: .relative)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Menu("Post actions", systemImage: "ellipsis") {
                                        Button("Delete post", systemImage: "trash", role: .destructive) {
                                            Task { await store.delete(post) }
                                        }
                                    }
                                    .labelStyle(.iconOnly)
                                }
                                .padding(.vertical, 10)
                                if index < min(store.posts.count, 5) - 1 { Divider() }
                            }
                        }
                        .padding()
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }
                } else {
                    ContentUnavailableView(
                        "No stats yet",
                        systemImage: "chart.bar",
                        description: Text("Pull to refresh after logging your first post.")
                    )
                }

                Button {
                    choosingPlatform = true
                } label: {
                    Label("Log a post", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .confirmationDialog("Where did you post?", isPresented: $choosingPlatform) {
                    ForEach(Platform.allCases) { platform in
                        Button(platform.label) { Task { await store.quickLog(platform) } }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Post Streak")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await store.refresh() }
                    }
                    Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        Task { await store.signOut() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .refreshable { await store.refresh() }
        .overlay(alignment: .bottom) {
            if let message = store.successMessage {
                Text(message)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 8)
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        store.successMessage = nil
                    }
            }
        }
    }
}

private struct MetricCard: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(.green)
            Text(value).font(.system(size: 32, weight: .bold, design: .rounded))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}
