import SwiftUI

struct FriendManagerView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var friendCode = ""

    private var incoming: [Friend] {
        store.friends.filter { $0.status == .pending && $0.direction == .incoming }
    }

    private var accepted: [Friend] {
        store.friends.filter { $0.status == .accepted }
    }

    private var outgoing: [Friend] {
        store.friends.filter { $0.status == .pending && $0.direction == .outgoing }
    }

    var body: some View {
        Form {
            if let profile = store.profile {
                Section("Your friend code") {
                    HStack {
                        Text(profile.friendCode.uppercased())
                            .font(.system(.title3, design: .monospaced, weight: .semibold))
                            .textSelection(.enabled)
                        Spacer()
                        ShareLink(item: profile.friendCode.uppercased()) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    Text("Share this code with people you know. Your email stays private.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Add a friend") {
                TextField("12-character friend code", text: $friendCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                Button("Send friend request", systemImage: "paperplane.fill") {
                    let code = friendCode
                    friendCode = ""
                    Task { await store.sendFriendRequest(code: code) }
                }
                .disabled(friendCode.trimmingCharacters(in: .whitespacesAndNewlines).count != 12)
            }

            if !incoming.isEmpty {
                Section("Requests") {
                    ForEach(incoming) { friend in
                        HStack {
                            Text(friend.displayName)
                            Spacer()
                            Button("Accept") {
                                Task { await store.accept(friend) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }

            if !accepted.isEmpty {
                Section("Friends") {
                    ForEach(accepted) { friend in
                        Label(friend.displayName, systemImage: "person.fill.checkmark")
                    }
                }
            }

            if !outgoing.isEmpty {
                Section("Sent") {
                    ForEach(outgoing) { friend in
                        HStack {
                            Text(friend.displayName)
                            Spacer()
                            Text("Pending")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .overlay { if store.isLoading { ProgressView() } }
    }
}
