import SwiftUI

enum AppTab: Hashable {
    case dashboard, transactions, debts, reports, more
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .dashboard
    @AppStorage(AppCurrency.storageKey) private var currencyCode: String = AppCurrency.defaultCode

    var body: some View {
        // iOS shows at most 5 tabs; the rest live in "More".
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Overview", systemImage: "house.fill")
                }
                .tag(AppTab.dashboard)

            TransactionListView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle")
                }
                .tag(AppTab.transactions)

            DebtsView()
                .tabItem {
                    Label("Debts", systemImage: "person.2.fill")
                }
                .tag(AppTab.debts)

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.pie.fill")
                }
                .tag(AppTab.reports)

            SettingsView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(AppTab.more)
        }
        // Rebuild screens so every amount is re-formatted after a currency change.
        .id(currencyCode)
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
