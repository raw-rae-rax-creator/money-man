import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    @State private var category: Category?
    @State private var account: Account?

    private let database = DatabaseService.shared

    var body: some View {
        HStack(spacing: 12) {
            if let category = category {
                Image(systemName: category.icon)
                    .foregroundColor(Color(hex: category.color))
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color(hex: category.color).opacity(0.1))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                if let category = category {
                    Text(category.name)
                        .font(.subheadline.bold())
                }

                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let account = account {
                    Text(account.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.type == .income ? "+" : "-")\(formatCurrency(transaction.amount))")
                    .font(.subheadline.bold())
                    .foregroundColor(transaction.type == .income ? .green : .red)

                Text(transaction.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        do {
            let categories = try database.fetchCategories()
            category = categories.first { $0.id == transaction.categoryId }

            let accounts = try database.fetchAccounts()
            account = accounts.first { $0.id == transaction.accountId }
        } catch {
            print("Error loading transaction details: \(error)")
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
