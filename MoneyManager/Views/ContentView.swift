import SwiftUI

struct ContentView: View {
    @StateObject private var router = TabRouter()
    @AppStorage(AppCurrency.storageKey) private var currencyCode: String = AppCurrency.defaultCode

    var body: some View {
        // Up to 4 user-chosen tabs + "More" (iOS fits five). Configured in More → Tab Bar.
        TabView(selection: $router.selection) {
            ForEach(router.tabs) { tab in
                AppScreen(tab: tab)
                    .tabItem {
                        Label(LocalizedStringKey(tab.tabTitle), systemImage: tab.icon)
                    }
                    .tag(tab)
            }

            SettingsView()
                .tabItem {
                    Label("More", systemImage: AppTab.more.icon)
                }
                .tag(AppTab.more)
        }
        // Rebuild screens so every amount is re-formatted after a currency change.
        .id(currencyCode)
        .environmentObject(router)
        .onChange(of: currencyCode) { _ in
            if AppIconManager.matchesCurrency {
                AppIconManager.applyCurrent()
            }
        }
    }
}

#Preview {
    ContentView()
}
