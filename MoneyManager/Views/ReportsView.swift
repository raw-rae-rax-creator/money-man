import SwiftUI

struct ReportsView: View {
    @State private var selectedPeriod: ReportPeriod = .month
    @State private var categoryData: [(category: Category, amount: Double)] = []
    @State private var totalIncome: Double = 0
    @State private var totalExpenses: Double = 0
    @State private var trend: [TrendBucket] = []

    private let database = DatabaseService.shared

    enum ReportPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
    }

    struct TrendBucket: Identifiable {
        let id: Int
        let label: String
        let amount: Double
        let isCurrent: Bool
        let isFuture: Bool
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    periodPicker
                    summaryCards
                    trendChart
                    categoryBreakdownChart
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Reports")
        }
        .navigationViewStyle(.stack)
        .onAppear {
            loadData()
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
            loadData()
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
                icon: "equal.circle.fill",
                color: (totalIncome - totalExpenses) >= 0 ? .green : .red
            )
        }
    }

    private var trendChart: some View {
        let maxAmount = trend.map { $0.amount }.max() ?? 0
        // Average over elapsed buckets only, so future days don't drag it down.
        let elapsed = trend.filter { !$0.isFuture }
        let average = elapsed.isEmpty ? 0 : elapsed.reduce(0) { $0 + $1.amount } / Double(elapsed.count)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spending Trend")
                    .font(.headline)
                Spacer()
                if average > 0 {
                    Text("avg \(average.formattedAsCurrency()) / \(selectedPeriod == .week || selectedPeriod == .month ? "day" : "month")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if maxAmount <= 0 {
                Text("No expenses in this period")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                HStack(alignment: .bottom, spacing: trend.count > 12 ? 2 : 6) {
                    ForEach(trend) { bucket in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(bucket.isCurrent ? Color.accentColor : Color.accentColor.opacity(0.4))
                                .frame(height: bucket.amount > 0 ? max(CGFloat(bucket.amount / maxAmount) * 140, 3) : 0)
                            Text(bucket.label)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .fixedSize()
                                .frame(height: 12)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 160, alignment: .bottom)

                Text("Max \(maxAmount.formattedAsCurrency())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .cardStyle()
    }

    private var categoryBreakdownChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expenses by Category")
                .font(.headline)

            if categoryData.isEmpty {
                Text("No expenses in this period")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(categoryData.enumerated()), id: \.element.category.id) { index, item in
                    let share = totalExpenses > 0 ? item.amount / totalExpenses : 0

                    VStack(spacing: 6) {
                        HStack {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .frame(width: 18)

                            Image(systemName: item.category.icon)
                                .foregroundColor(Color(hex: item.category.color))
                                .frame(width: 24)

                            Text(item.category.name)
                                .font(.subheadline)

                            Spacer()

                            Text(item.amount.formattedAsCurrency())
                                .font(.subheadline.bold().monospacedDigit())

                            Text("\(Int((share * 100).rounded()))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }

                        ProgressView(value: share)
                            .tint(Color(hex: item.category.color))
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .cardStyle()
    }

    private func loadData() {
        do {
            let (from, to) = getDateRange()
            let transactions = try database.fetchTransactions(from: from, to: to)

            totalIncome = transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            totalExpenses = transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }

            var categoryTotals: [UUID: Double] = [:]
            for transaction in transactions where transaction.type == .expense {
                categoryTotals[transaction.categoryId, default: 0] += transaction.amount
            }

            let categories = try database.fetchCategories(type: .expense)
            var data: [(category: Category, amount: Double)] = []
            for category in categories {
                if let amount = categoryTotals[category.id], amount > 0 {
                    data.append((category: category, amount: amount))
                }
            }
            categoryData = data.sorted { $0.amount > $1.amount }

            trend = buildTrend(from: transactions.filter { $0.type == .expense })
        } catch {
            print("Error loading report data: \(error)")
        }
    }

    private func buildTrend(from expenses: [Transaction]) -> [TrendBucket] {
        let calendar = Calendar.current
        let now = Date()

        let start: Date
        let component: Calendar.Component
        let count: Int

        switch selectedPeriod {
        case .week:
            start = now.interval(of: .weekOfYear).start
            component = .day
            count = 7
        case .month:
            start = now.interval(of: .month).start
            component = .day
            count = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        case .year:
            start = now.interval(of: .year).start
            component = .month
            count = 12
        case .all:
            start = calendar.date(byAdding: .month, value: -11, to: now.interval(of: .month).start) ?? now
            component = .month
            count = 12
        }

        var buckets: [TrendBucket] = []
        for index in 0..<count {
            guard let bucketStart = calendar.date(byAdding: component, value: index, to: start),
                  let bucketEnd = calendar.date(byAdding: component, value: 1, to: bucketStart) else { continue }

            let amount = expenses
                .filter { $0.date >= bucketStart && $0.date < bucketEnd }
                .reduce(0) { $0 + $1.amount }

            let label: String
            switch selectedPeriod {
            case .week:
                label = bucketStart.formatted(.dateTime.weekday(.abbreviated))
            case .month:
                let day = calendar.component(.day, from: bucketStart)
                label = (day == 1 || day % 5 == 0) ? "\(day)" : ""
            case .year, .all:
                label = bucketStart.formatted(.dateTime.month(.narrow))
            }

            buckets.append(TrendBucket(
                id: index,
                label: label,
                amount: amount,
                isCurrent: calendar.isDate(bucketStart, equalTo: now, toGranularity: component),
                isFuture: bucketStart > now
            ))
        }
        return buckets
    }

    private func getDateRange() -> (Date?, Date?) {
        let now = Date()

        switch selectedPeriod {
        case .week:
            let week = now.interval(of: .weekOfYear)
            return (week.start, week.end)
        case .month:
            let month = now.interval(of: .month)
            return (month.start, month.end)
        case .year:
            let year = now.interval(of: .year)
            return (year.start, year.end)
        case .all:
            return (nil, nil)
        }
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(amount.formattedAsCurrency())
                    .font(.headline.monospacedDigit())
                    .foregroundColor(color)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .cardStyle()
    }
}

#Preview {
    ReportsView()
}
