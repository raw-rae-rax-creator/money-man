import SwiftUI

struct ReportsView: View {
    @State private var selectedPeriod: ReportPeriod = .month
    @State private var transactions: [Transaction] = []
    @State private var categoryData: [(category: Category, amount: Double)] = []
    @State private var totalIncome: Double = 0
    @State private var totalExpenses: Double = 0

    private let database = DatabaseService.shared

    enum ReportPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    periodPicker
                    summaryCards
                    categoryBreakdownChart
                    topCategoriesList
                    dailySpendingChart
                }
                .padding()
            }
            .navigationTitle("Reports")
        }
        .task {
            await loadData()
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(ReportPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedPeriod) { _ in
            Task { await loadData() }
        }
    }

    private var summaryCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryCard(
                    title: "Income",
                    amount: totalIncome,
                    icon: "arrow.down.circle.fill",
                    color: .green
                )

                SummaryCard(
                    title: "Expenses",
                    amount: totalExpenses,
                    icon: "arrow.up.circle.fill",
                    color: .red
                )
            }

            SummaryCard(
                title: "Net",
                amount: totalIncome - totalExpenses,
                icon: "dollarsign.circle.fill",
                color: (totalIncome - totalExpenses) >= 0 ? .green : .red
            )
        }
    }

    private var categoryBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expense Breakdown")
                .font(.headline)

            if categoryData.isEmpty {
                Text("No expenses in this period")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(categoryData, id: \.category.id) { item in
                    HStack {
                        Image(systemName: item.category.icon)
                            .foregroundColor(Color(hex: item.category.color))
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.category.name)
                                .font(.subheadline)

                            GeometryReader { geometry in
                                let percentage = totalExpenses > 0 ? item.amount / totalExpenses : 0
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: item.category.color))
                                    .frame(width: geometry.size.width * percentage)
                            }
                            .frame(height: 8)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatCurrency(item.amount))
                                .font(.subheadline.bold())

                            Text("\(Int((item.amount / totalExpenses) * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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

    private var topCategoriesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Spending Categories")
                .font(.headline)

            if categoryData.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(categoryData.prefix(5).enumerated()), id: \.element.category.id) { index, item in
                    HStack {
                        Text("#\(index + 1)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .frame(width: 30)

                        Image(systemName: item.category.icon)
                            .foregroundColor(Color(hex: item.category.color))

                        Text(item.category.name)
                            .font(.subheadline)

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

    private var dailySpendingChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Spending")
                .font(.headline)

            Text("Chart visualization would go here")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    private func loadData() async {
        do {
            let (from, to) = getDateRange()
            transactions = try database.fetchTransactions(from: from, to: to)

            totalIncome = transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            totalExpenses = transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

            let categoryTotals = try database.getTransactionsByCategory(from: from ?? .distantPast, to: to ?? .distantFuture)
            let categories = try database.fetchCategories(type: .expense)

            categoryData = categories.compactMap { category in
                if let amount = categoryTotals[category.id], amount > 0 {
                    return (category: category, amount: amount)
                }
                return nil
            }.sorted { $0.amount > $1.amount }

        } catch {
            print("Error loading report data: \(error)")
        }
    }

    private func getDateRange() -> (Date?, Date?) {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .week:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (start, now)
        case .month:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (start, now)
        case .year:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return (start, now)
        case .all:
            return (nil, nil)
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatCurrency(amount))
                    .font(.title3.bold())
                    .foregroundColor(color)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
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
    ReportsView()
}
