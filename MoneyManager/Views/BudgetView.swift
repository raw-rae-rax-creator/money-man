import SwiftUI

/// Pushed from the "More" tab, so it relies on the parent NavigationView.
struct BudgetView: View {
    @StateObject private var viewModel = BudgetViewModel()
    @State private var categories: [Category] = []

    private let database = DatabaseService.shared

    var body: some View {
        List {
            if viewModel.budgetSummaries.isEmpty {
                emptyState
            } else {
                budgetList
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Budgets")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.resetForm()
                    viewModel.showAddSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            BudgetFormView(viewModel: viewModel, categories: categories)
        }
        .task {
            loadCategories()
        }
        .onAppear {
            Task { await viewModel.loadBudgets() }
        }
        .refreshable {
            await viewModel.loadBudgets()
        }
        .onReceive(NotificationCenter.default.publisher(for: .moneyDataDidChange)) { _ in
            Task { await viewModel.loadBudgets() }
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.secondary)

                Text("No budgets yet")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Create budgets to track your spending limits")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Create Budget") {
                    viewModel.resetForm()
                    viewModel.showAddSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    private var budgetList: some View {
        Section {
            ForEach(viewModel.budgetSummaries) { summary in
                BudgetRowView(summary: summary)
                    .swipeActions {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteBudget(summary.budget)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private func loadCategories() {
        do {
            categories = try database.fetchCategories(type: .expense)
        } catch {
            print("Error loading categories: \(error)")
        }
    }
}

struct BudgetRowView: View {
    let summary: BudgetSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let category = summary.category {
                    CategoryIconView(category: category, size: 30)

                    Text(category.displayName)
                        .font(.headline)
                } else {
                    Image(systemName: "sum")
                        .foregroundColor(.accentColor)
                        .font(.title3)

                    Text("All Expenses")
                        .font(.headline)
                }

                Text(summary.budget.period.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())

                Spacer()

                Text(summary.budget.amount.formattedAsCurrency())
                    .font(.headline.monospacedDigit())
            }

            ProgressView(value: min(summary.percentage, 100), total: 100)
                .progressViewStyle(.linear)
                .tint(progressColor)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(summary.spent.formattedAsCurrency())
                        .font(.caption.bold().monospacedDigit())
                        .foregroundColor(.red)
                }

                Spacer()

                Text("\(Int(summary.percentage))% used")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(summary.remaining >= 0 ? LocalizedStringKey("Remaining") : LocalizedStringKey("Over budget"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(abs(summary.remaining).formattedAsCurrency())
                        .font(.caption.bold().monospacedDigit())
                        .foregroundColor(summary.remaining >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var progressColor: Color {
        if summary.percentage >= 100 {
            return .red
        } else if summary.percentage >= 80 {
            return .orange
        } else {
            return .green
        }
    }
}

struct BudgetFormView: View {
    @ObservedObject var viewModel: BudgetViewModel
    let categories: [Category]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Category") {
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        Text("All Expenses").tag(nil as Category?)
                        ForEach(categories) { category in
                            Text(category.displayName).tag(Optional(category))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Limit") {
                    HStack {
                        TextField("0", text: $viewModel.budgetAmount.amountFormatted())
                            .keyboardType(.decimalPad)
                            .font(.title2)
                        Text(AppCurrency.symbol)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Period") {
                    Picker("Period", selection: $viewModel.budgetPeriod) {
                        ForEach(BudgetPeriod.allCases, id: \.self) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.addBudget()
                            dismiss()
                        }
                    }
                    .font(.body.weight(.semibold))
                    .disabled(!viewModel.isFormValid)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        BudgetView()
    }
}
