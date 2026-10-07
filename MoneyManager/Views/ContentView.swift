import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)

            TransactionListView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle")
                }
                .tag(1)

            GoalsView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag(2)

            BillsView()
                .tabItem {
                    Label("Bills", systemImage: "doc.text.fill")
                }
                .tag(3)

            DebtsView()
                .tabItem {
                    Label("Debts", systemImage: "person.2.circle")
                }
                .tag(4)

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.pie.fill")
                }
                .tag(5)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(6)
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
}
