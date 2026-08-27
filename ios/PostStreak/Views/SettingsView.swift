import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var confirmingDeletion = false

    var body: some View {
        Form {
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
}
