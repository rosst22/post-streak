import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var reportingPost: Post?
    @State private var blockingPost: Post?
    @State private var showingFriends = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-screenshot-friends")
        #else
        return false
        #endif
    }()

    var body: some View {
        Group {
            if store.feed.isEmpty {
                ContentUnavailableView(
                    "No friend posts yet",
                    systemImage: "person.2",
                    description: Text("Accepted friends’ newest posts appear here.")
                )
            } else {
                List(store.feed) { post in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Label(post.platform.label, systemImage: post.platform.symbol)
                                .font(.headline)
                            Spacer()
                            Text(post.postedAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Menu("Post actions", systemImage: "ellipsis") {
                                Button("Report post", systemImage: "exclamationmark.bubble") {
                                    reportingPost = post
                                }
                                Button("Block user", systemImage: "hand.raised", role: .destructive) {
                                    blockingPost = post
                                }
                            }
                            .labelStyle(.iconOnly)
                        }
                        Text(post.author?.displayName ?? "Friend")
                            .font(.subheadline.weight(.medium))
                        if let title = post.title, !title.isEmpty { Text(title) }
                        if let url = post.url {
                            Link(url.host ?? "Open post", destination: url)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing) {
                        Button("Block", systemImage: "hand.raised.fill", role: .destructive) {
                            blockingPost = post
                        }
                        Button("Report", systemImage: "exclamationmark.bubble.fill") {
                            reportingPost = post
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        Button("Report post", systemImage: "exclamationmark.bubble") {
                            reportingPost = post
                        }
                        Button("Block user", systemImage: "hand.raised", role: .destructive) {
                            blockingPost = post
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Friends")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Manage friends", systemImage: "person.badge.plus") {
                    showingFriends = true
                }
            }
        }
        .sheet(isPresented: $showingFriends) {
            NavigationStack { FriendManagerView() }
        }
        .refreshable { await store.refresh() }
        .confirmationDialog(
            "Why are you reporting this post?",
            isPresented: Binding(
                get: { reportingPost != nil },
                set: { if !$0 { reportingPost = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(ReportReason.allCases) { reason in
                Button(reason.label) {
                    guard let post = reportingPost else { return }
                    reportingPost = nil
                    Task { await store.report(post, reason: reason) }
                }
            }
        }
        .confirmationDialog(
            "Block this user?",
            isPresented: Binding(
                get: { blockingPost != nil },
                set: { if !$0 { blockingPost = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Block user", role: .destructive) {
                guard let post = blockingPost else { return }
                blockingPost = nil
                Task { await store.block(post) }
            }
        } message: {
            Text("You will no longer be friends or see each other’s posts.")
        }
    }
}
