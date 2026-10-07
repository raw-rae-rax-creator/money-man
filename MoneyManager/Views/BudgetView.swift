import SwiftUI

struct BudgetView: View {
    @StateObject private var viewModel = BudgetViewModel()
    @State private var categories: [Category] = []

    private let database = DatabaseService.shared

    var body: some View {
        NavigationView {
            List {
                if viewModel.budgetSummaries.isEmpty {
                    emptyState
                } else {
                    budgetList
                }
            }
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                BudgetFormView(viewModel: viewModel, categories: categories)
            }
        }
        .task {
            await viewModel.loadBudgets()
            await loadCategories()
        }
        .refreshable {
            await viewModel.loadBudgets()
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                Text("No budgets yet")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Create budgets to track your spending limits")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: { viewModel.showAddSheet = true }) {
                    Text("Create Budget")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    private var budgetList: some View {
        Section("Monthly Budgets") {
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

    private func loadCategories() async {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let category = summary.category {
                    Image(systemName: category.icon)
                        .foregroundColor(Color(hex: category.color))
                        .font(.title2)

                    Text(category.name)
                        .font(.headline)
                } else {
                    Text("Total Budget")
                        .font(.headline)
                }

                Spacer()

                Text(formatCurrency(summary.budget.amount))
                    .font(.headline)
            }

            ProgressView(value: min(summary.percentage, 100), total: 100)
                .progressViewStyle(.linear)
                .tint(progressColor)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(summary.spent))
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(summary.remaining))
                        .font(.caption.bold())
                        .foregroundColor(summary.remaining >= 0 ? .green : .red)
                }
            }

            Text("\(Int(summary.percentage))% used")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
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

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
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
                        Text("Total Budget").tag(nil as Category?)
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Budget Amount") {
                    HStack {
                        Text("$")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $viewModel.budgetAmount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                }

                Section("Period") {
                    Picker("Period", selection: $viewModel.budgetPeriod) {
                        ForEach(BudgetPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue.capitalized).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.addBudget()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    BudgetView()
}
