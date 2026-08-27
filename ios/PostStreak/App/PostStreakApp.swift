import SwiftUI

@main
struct PostStreakApp: App {
    @StateObject private var store: SessionStore

    init() {
        do {
            let configuration = try AppConfiguration.load()
            _store = StateObject(wrappedValue: SessionStore(client: NetworkClient(configuration: configuration)))
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(.green)
        }
    }
}

