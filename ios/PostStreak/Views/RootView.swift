import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: SessionStore

    var body: some View {
        Group {
            switch store.authState {
            case .checking:
                ProgressView("Restoring session…")
            case .signedOut:
                AuthView()
            case .signedIn:
                MainTabView()
            }
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "Unknown error")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}

