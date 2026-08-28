import SwiftUI

struct MainTabView: View {
    private enum Tab: Hashable { case home, friends, settings }

    @State private var selection: Tab = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-screenshot-feed") || arguments.contains("-screenshot-friends")
            ? .friends
            : .home
        #else
        return .home
        #endif
    }()

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "flame.fill") }
                .tag(Tab.home)
            NavigationStack { FeedView() }
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
                .tag(Tab.friends)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
    }
}
