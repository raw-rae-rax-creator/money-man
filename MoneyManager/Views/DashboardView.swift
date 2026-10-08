import SwiftUI

struct DashboardView: View {
    /// `false` when pushed from "More", which already provides navigation.
    var embedInNavigation: Bool = true

    @EnvironmentObject var router: TabRouter
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showAddTransaction = false
    @State private var editingTransaction: Transaction?
    /// Opened as a sheet when the target screen isn't in the tab bar.
    @State private var sheetScreen: AppTab?

    @AppStorage(AppPreferences.dashboardSectionsKey)
    private var sectionsRaw = DashboardSection.encode(DashboardSection.defaultOrder)
    @AppStorage(AppPreferences.dashboardCategoryStyleKey)
    private var categoryStyleRaw = CategoryChartStyle.donut.rawValue

    private var sections: [DashboardSection] {
        DashboardSection.decode(sectionsRaw)
    }

    private var categoryStyle: CategoryChartStyle {
        CategoryChartStyle(rawValue: categoryStyleRaw) ?? .donut
    }

    var body: some View {
        NavigationContainer(embed: embedInNavigation) {
            ScrollView {
                VStack(spacing: 16) {
                    balanceCard
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .refreshable {
                await viewModel.loadData()
            }
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddTransaction = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction, onDismiss: reload) {
                AddTransactionView()
            }
            .sheet(item: $editingTransaction, onDismiss: reload) { transaction in
                AddTransactionView(editing: transaction)
            }
            .sheet(item: $sheetScreen, onDismiss: reload) { screen in
                AppScreen(tab: screen)
            }
        }
        // onAppear (not .task) so the data refreshes every time the tab is opened.
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .moneyDataDidChange)) { _ in
            reload()
        }
    }

    private func reload() {
        Task { await viewModel.loadData() }
    }

    /// Switches tab when the screen is in the tab bar, otherwise shows it as a sheet.
    private func open(_ screen: AppTab) {
        if !router.show(screen) {
            sheetScreen = screen
        }
    }

    @ViewBuilder
    private func sectionView(_ section: DashboardSection) -> some View {
        switch section {
        case .accounts:
            if viewModel.accounts.count > 1 {
                accountsStrip
            }
        case .debts:
            debtsCard
        case .recent:
            recentTransactionsSection
        case .categories:
            categoryBreakdownSection
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))

            Text(viewModel.totalBalance.formattedAsCurrency())
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            HStack(spacing: 24) {
                summaryItem(
                    title: "Income",
                    amount: viewModel.monthlyIncome,
                    icon: "arrow.down.circle.fill"
                )
                summaryItem(
                    title: "Expenses",
                    amount: viewModel.monthlyExpenses,
                    icon: "arrow.up.circle.fill"
                )
            }

            let netAmount = viewModel.monthlyIncome - viewModel.monthlyExpenses
            HStack {
                Text(Date(), format: .dateTime.month(.wide).year())
                Spacer()
                Text("Net \(netAmount.signedCurrency)")
                    .fontWeight(.semibold)
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.85))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func summaryItem(title: LocalizedStringKey, amount: Double, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))
            Text(amount.formattedAsCurrency())
                .font(.headline.monospacedDigit())
                .foregroundColor(.white)
        }
    }

    private var accountsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.accounts) { account in
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: account.icon)
                            .foregroundColor(Color(hex: account.color))
                        Text(account.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text(account.balance.formattedAsCurrency())
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    .padding(12)
                    .frame(minWidth: 120, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var debtsCard: some View {
        Button {
            open(.debts)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Debts", systemImage: "person.2.fill")
                        .font(.headline)
                    Spacer()
                    if viewModel.overdueDebtsCount > 0 {
                        Text("\(viewModel.overdueDebtsCount) overdue")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.red)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }

                if viewModel.activeDebtsCount == 0 {
                    Text("No active debts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Owed to me")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.owedToMe.formattedAsCurrency())
                                .font(.headline.monospacedDigit())
                                .foregroundColor(.orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("I owe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(viewModel.iOwe.formattedAsCurrency())
                                .font(.headline.monospacedDigit())
                                .foregroundColor(.blue)
                        }
                    }
                }

                Text("Not included in balance or statistics")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                Button("See All") {
                    open(.transactions)
                }
                .font(.subheadline)
            }

            if viewModel.recentTransactions.isEmpty {
                VStack(spacing: 12) {
                    Text("No transactions yet")
                        .foregroundColor(.secondary)
                    Button("Add your first transaction") {
                        showAddTransaction = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(viewModel.recentTransactions.prefix(5)) { transaction in
                    TransactionRowView(
                        transaction: transaction,
                        category: viewModel.categoriesById[transaction.categoryId],
                        account: viewModel.accountsById[transaction.accountId]
                    )
                    .onTapGesture {
                        editingTransaction = transaction
                    }
                }
            }
        }
        .cardStyle()
    }

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Expenses This Month")
                    .font(.headline)
                Spacer()
                // Quick switch between the donut and the list; also in More → Overview Layout.
                Button {
                    withAnimation {
                        categoryStyleRaw = (categoryStyle == .donut ? CategoryChartStyle.list : .donut).rawValue
                    }
                } label: {
                    Image(systemName: categoryStyle == .donut ? CategoryChartStyle.list.icon : CategoryChartStyle.donut.icon)
                        .font(.subheadline.weight(.semibold))
                }
            }

            if viewModel.categoryBreakdown.isEmpty {
                Text("No expenses this month")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if categoryStyle == .donut {
                categoryDonut
            } else {
                categoryList
            }
        }
        .cardStyle()
    }

    /// Top categories, with everything else folded into "Other".
    private var donutItems: [(id: String, name: String, color: Color, amount: Double, percentage: Double)] {
        let top = viewModel.categoryBreakdown.prefix(5).map {
            (id: $0.category.id.uuidString, name: $0.category.displayName, color: Color(hex: $0.category.color),
             amount: $0.amount, percentage: $0.percentage)
        }
        let rest = viewModel.categoryBreakdown.dropFirst(5)
        guard !rest.isEmpty else { return top }
        let restAmount = rest.reduce(0) { $0 + $1.amount }
        let restPercentage = rest.reduce(0) { $0 + $1.percentage }
        return top + [(id: "other", name: "Other".localized, color: Color(.systemGray3),
                       amount: restAmount, percentage: restPercentage)]
    }

    private var categoryDonut: some View {
        let items = donutItems

        return HStack(alignment: .center, spacing: 16) {
            ZStack {
                DonutChart(segments: items.map { DonutSegment(id: $0.id, color: $0.color, value: $0.amount) })
                VStack(spacing: 2) {
                    Text("Spent")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(viewModel.monthlyExpenses.formattedAsCurrency())
                        .font(.caption.weight(.bold).monospacedDigit())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .padding(.horizontal, 30)
            }
            .frame(width: 150, height: 150)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.id) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 9, height: 9)
                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(Int(item.percentage.rounded()))%")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var categoryList: some View {
        ForEach(viewModel.categoryBreakdown.prefix(5), id: \.category.id) { item in
            VStack(spacing: 6) {
                HStack {
                    CategoryIconView(category: item.category, size: 28)
                        .frame(width: 28)

                    Text(item.category.displayName)
                        .font(.subheadline)

                    Spacer()

                    Text(item.amount.formattedAsCurrency())
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text("\(Int(item.percentage.rounded()))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }

                ProgressView(value: min(item.percentage, 100), total: 100)
                    .tint(Color(hex: item.category.color))
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(TabRouter())
}
