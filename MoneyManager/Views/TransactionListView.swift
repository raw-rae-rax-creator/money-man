import SwiftUI

struct TransactionListView: View {
    @StateObject private var viewModel = TransactionListViewModel()
    @State private var showAddTransaction = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterBar
                summaryBar

                if viewModel.filteredTransactions.isEmpty {
                    emptyState
                } else {
                    transactionList
                }
            }
            .navigationTitle("Transactions")
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
            await viewModel.loadTransactions()
        }
        .refreshable {
            await viewModel.loadTransactions()
        }
    }

    private var filterBar: some View {
        VStack(spacing: 12) {
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(TransactionListViewModel.TransactionFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Picker("Date Range", selection: $viewModel.dateRange) {
                ForEach(TransactionListViewModel.DateRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search transactions...", text: $viewModel.searchText)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .onChange(of: viewModel.selectedFilter) { _ in viewModel.applyFilters() }
        .onChange(of: viewModel.searchText) { _ in viewModel.applyFilters() }
        .onChange(of: viewModel.dateRange) { _ in
            Task { await viewModel.loadTransactions() }
        }
    }

    private var summaryBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Income")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(viewModel.getTotalIncome()))
                    .font(.subheadline.bold())
                    .foregroundColor(.green)
            }

            Spacer()

            VStack(alignment: .center, spacing: 4) {
                Text("Net")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(viewModel.getNetAmount()))
                    .font(.subheadline.bold())
                    .foregroundColor(viewModel.getNetAmount() >= 0 ? .green : .red)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Expenses")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(viewModel.getTotalExpenses()))
                    .font(.subheadline.bold())
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var transactionList: some View {
        List {
            ForEach(viewModel.filteredTransactions) { transaction in
                TransactionRowView(transaction: transaction)
            }
            .onDelete { offsets in
                Task {
                    await viewModel.deleteTransaction(at: offsets)
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No transactions found")
                .font(.headline)
                .foregroundColor(.secondary)

            Button(action: { showAddTransaction = true }) {
                Text("Add Transaction")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

#Preview {
    TransactionListView()
}
