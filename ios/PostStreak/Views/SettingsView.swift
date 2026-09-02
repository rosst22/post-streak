import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var confirmingDeletion = false
    @State private var displayName = ""
    @State private var weeklyTarget = 3

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Display name", text: $displayName)
                    .textContentType(.name)
                Stepper("Weekly target: \(weeklyTarget)", value: $weeklyTarget, in: 1...14)
                Button("Save profile") {
                    Task {
                        await store.updateProfile(
                            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                            weeklyTarget: weeklyTarget
                        )
                    }
                }
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isLoading)
            }

            Section("Help and legal") {
                Link("Support", destination: store.supportURL)
                Link("Privacy Policy", destination: store.privacyURL)
                Link("Terms and Community Standards", destination: store.termsURL)
            }

            Section {
                Button("Sign out") { Task { await store.signOut() } }
                Button("Delete account", role: .destructive) {
                    confirmingDeletion = true
                }
            } header: {
                Text("Account")
            } footer: {
                Text("Deleting your account permanently removes your profile, posts, friendships, reports, and sign-in access.")
            }
        }
        .navigationTitle("Settings")
        .onAppear { loadProfile() }
        .onChange(of: store.profile?.displayName) { _, _ in loadProfile() }
        .overlay { if store.isLoading { ProgressView() } }
        .confirmationDialog(
            "Permanently delete your account?",
            isPresented: $confirmingDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete account and data", role: .destructive) {
                Task { await store.deleteAccount() }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func loadProfile() {
        guard let profile = store.profile else { return }
        displayName = profile.displayName
        weeklyTarget = profile.weeklyTarget
    }
}
