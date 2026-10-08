import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    let category: Category?
    let account: Account?

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(category: category)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(category?.displayName ?? "Uncategorized".localized)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    if transaction.isCancelled {
                        Text("Cancelled")
                            .font(.caption2.bold())
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    if let account = account {
                        Text(account.displayName)
                    }
                    if transaction.isRecurring {
                        Image(systemName: "repeat")
                    }
                    if transaction.hasLocation {
                        Image(systemName: "location.fill")
                    }
                    if !transaction.tags.isEmpty {
                        Text(transaction.tags.map { "#\($0)" }.joined(separator: " "))
                            .lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(verbatim: (transaction.type == .income ? "+" : "−") + transaction.amount.formattedAsCurrency())
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(amountColor)
                    .strikethrough(transaction.isCancelled)

                Text(transaction.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(transaction.isCancelled ? 0.55 : 1)
        .contentShape(Rectangle())
    }

    private var amountColor: Color {
        if transaction.isCancelled { return .secondary }
        return transaction.type == .income ? .green : .primary
    }
}
