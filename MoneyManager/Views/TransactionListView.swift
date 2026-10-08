import SwiftUI

struct TransactionListView: View {
    @StateObject private var viewModel = TransactionListViewModel()
    @State private var showAddTransaction = false
    @State private var editingTransaction: Transaction?

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
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Date Range", selection: $viewModel.dateRange) {
                            ForEach(TransactionListViewModel.DateRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                    } label: {
                        Label(viewModel.dateRange.rawValue, systemImage: "calendar")
                    }
                }

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
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: reload)
    }

    private func reload() {
        Task { await viewModel.loadTransactions() }
    }

    private var filterBar: some View {
        VStack(spacing: 10) {
            Picker("Filter", selection: $viewModel.selectedFilter) {
                ForEach(TransactionListViewModel.TransactionFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search notes, tags, categories", text: $viewModel.searchText)
                    .disableAutocorrection(true)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .onChange(of: viewModel.selectedFilter) { _ in viewModel.applyFilters() }
        .onChange(of: viewModel.searchText) { _ in viewModel.applyFilters() }
        .onChange(of: viewModel.dateRange) { _ in reload() }
    }

    private var summaryBar: some View {
        HStack {
            summaryItem("Income", viewModel.getTotalIncome(), .green, alignment: .leading)
            Spacer()
            summaryItem("Net", viewModel.getNetAmount(), viewModel.getNetAmount() >= 0 ? .green : .red, alignment: .center)
            Spacer()
            summaryItem("Expenses", viewModel.getTotalExpenses(), .red, alignment: .trailing)
        }
        .padding()
    }

    private func summaryItem(_ title: String, _ amount: Double, _ color: Color, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(amount.formattedAsCurrency())
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(color)
        }
    }

    private var transactionList: some View {
        List {
            ForEach(viewModel.groupedTransactions, id: \.day) { group in
                Section {
                    ForEach(group.items) { transaction in
                        TransactionRowView(
                            transaction: transaction,
                            category: viewModel.categoriesById[transaction.categoryId],
                            account: viewModel.accountsById[transaction.accountId]
                        )
                        .onTapGesture {
                            editingTransaction = transaction
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteTransaction(transaction) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    dayHeader(group.day, items: group.items)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.loadTransactions()
        }
    }

    private func dayHeader(_ day: Date, items: [Transaction]) -> some View {
        let net = items.reduce(0.0) { total, transaction in
            switch transaction.type {
            case .income: return total + transaction.amount
            case .expense: return total - transaction.amount
            case .transfer: return total
            }
        }
        return HStack {
            Text(dayTitle(day))
            Spacer()
            Text(net.formattedAsCurrency())
                .monospacedDigit()
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("No transactions found")
                .font(.headline)
                .foregroundColor(.secondary)

            Button("Add Transaction") {
                showAddTransaction = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TransactionListView()
}
