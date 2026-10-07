import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showAddTransaction = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    balanceCard
                    monthlySummaryCard
                    recentTransactionsSection
                    categoryBreakdownSection
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddTransaction = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(formatCurrency(viewModel.totalBalance))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                        Text("Income")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(formatCurrency(viewModel.monthlyIncome))
                        .font(.headline)
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.red)
                        Text("Expenses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(formatCurrency(viewModel.monthlyExpenses))
                        .font(.headline)
                        .foregroundColor(.red)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    private var monthlySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Monthly Summary")
                    .font(.headline)
                Spacer()
                Text(Date(), format: .dateTime.month(.wide).year())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let netAmount = viewModel.monthlyIncome - viewModel.monthlyExpenses
            HStack {
                Text("Net")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatCurrency(netAmount))
                    .font(.title3.bold())
                    .foregroundColor(netAmount >= 0 ? .green : .red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: TransactionListView()) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if viewModel.recentTransactions.isEmpty {
                Text("No transactions yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.recentTransactions.prefix(5)) { transaction in
                    TransactionRowView(transaction: transaction)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Categories")
                .font(.headline)

            if viewModel.categoryBreakdown.isEmpty {
                Text("No expenses this month")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.categoryBreakdown.prefix(5), id: \.category.id) { item in
                    HStack {
                        Image(systemName: item.category.icon)
                            .foregroundColor(Color(hex: item.category.color))
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.category.name)
                                .font(.subheadline)
                            Text("\(Int(item.percentage))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(formatCurrency(item.amount))
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

#Preview {
    DashboardView()
}
