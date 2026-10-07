import SwiftUI

struct DebtsView: View {
    @StateObject private var viewModel = DebtsViewModel()
    @State private var selectedFilter: DebtFilter = .active
    @State private var selectedType: DebtType? = nil

    enum DebtFilter: String, CaseIterable {
        case active = "Active"
        case overdue = "Overdue"
        case returned = "Returned"
        case all = "All"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCards
                    filterSection
                    debtsList
                }
                .padding()
            }
            .navigationTitle("Debts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                DebtFormView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.loadDebts()
        }
    }

    private var summaryCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryCard(
                    title: "Given",
                    amount: viewModel.totalGiven,
                    icon: "arrow.up.circle.fill",
                    color: .orange
                )

                SummaryCard(
                    title: "Received",
                    amount: viewModel.totalReceived,
                    icon: "arrow.down.circle.fill",
                    color: .blue
                )
            }

            SummaryCard(
                title: "Net",
                amount: viewModel.netDebt,
                icon: "equal.circle.fill",
                color: viewModel.netDebt >= 0 ? .orange : .blue
            )

            HStack(spacing: 20) {
                Label("\(viewModel.activeDebts.count) Active", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("\(viewModel.overdueDebts.count) Overdue", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(viewModel.overdueDebts.isEmpty ? .secondary : .red)

                Label("\(viewModel.returnedDebts.count) Returned", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }

    private var filterSection: some View {
        VStack(spacing: 12) {
            Picker("Status", selection: $selectedFilter) {
                ForEach(DebtFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Picker("Type", selection: $selectedType) {
                Text("All").tag(nil as DebtType?)
                Text("Given").tag(DebtType.given as DebtType?)
                Text("Received").tag(DebtType.received as DebtType?)
            }
            .pickerStyle(.segmented)
        }
    }

    private var debtsList: some View {
        VStack(spacing: 12) {
            let filteredDebts = getFilteredDebts()

            if filteredDebts.isEmpty {
                emptyState
            } else {
                ForEach(filteredDebts) { debt in
                    DebtCardView(debt: debt, viewModel: viewModel)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No debts found")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Track money you've lent or borrowed")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { viewModel.showAddSheet = true }) {
                Text("Add Debt")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }

    private func getFilteredDebts() -> [Debt] {
        var filtered = viewModel.debts

        switch selectedFilter {
        case .active:
            filtered = filtered.filter { $0.status == .active }
        case .overdue:
            filtered = filtered.filter { $0.isOverdue }
        case .returned:
            filtered = filtered.filter { $0.status == .returned }
        case .all:
            break
        }

        if let type = selectedType {
            filtered = filtered.filter { $0.type == type }
        }

        return filtered
    }
}

struct DebtCardView: View {
    let debt: Debt
    @ObservedObject var viewModel: DebtsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: debt.type == .given ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(debt.type == .given ? .orange : .blue)
                    .frame(width: 50, height: 50)
                    .background((debt.type == .given ? Color.orange : Color.blue).opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(debt.personName)
                        .font(.headline)

                    HStack(spacing: 8) {
                        Text(debt.type == .given ? "Given" : "Received")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if debt.isOverdue {
                            Text("Overdue")
                                .font(.caption2.bold())
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        } else if debt.isDueSoon {
                            Text("Due soon")
                                .font(.caption2.bold())
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }

                        if debt.status == .returned {
                            Text("Returned")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(debt.amount))
                        .font(.title3.bold())
                        .foregroundColor(debt.type == .given ? .orange : .blue)

                    Text("Given \(debt.dateGiven, style: .date)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if let expectedDate = debt.expectedReturnDate {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if debt.status == .returned, let actualDate = debt.actualReturnDate {
                        Text("Returned on \(actualDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Expected by \(expectedDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(debt.isOverdue ? .red : .secondary)

                        if let days = debt.daysUntilDue, debt.status == .active {
                            Spacer()

                            if days >= 0 {
                                Text("in \(days) days")
                                    .font(.caption.bold())
                                    .foregroundColor(days <= 3 ? .orange : .secondary)
                            } else {
                                Text("\(abs(days)) days ago")
                                    .font(.caption.bold())
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            } else if debt.status == .active {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("No return date set")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(debt.daysActive) days active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !debt.note.isEmpty {
                Text(debt.note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                if debt.status == .active {
                    Button(action: {
                        viewModel.markAsReturned(debt)
                    }) {
                        Label("Mark Returned", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                } else {
                    Button(action: {
                        viewModel.markAsActive(debt)
                    }) {
                        Label("Mark Active", systemImage: "arrow.clockwise.circle.fill")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                    }
                }

                Spacer()

                Button(action: {
                    viewModel.editDebt(debt)
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .swipeActions {
            Button(role: .destructive) {
                viewModel.deleteDebt(debt)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

struct DebtFormView: View {
    @ObservedObject var viewModel: DebtsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Person") {
                    TextField("Name", text: $viewModel.personName)
                }

                Section("Amount") {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Amount", text: $viewModel.amount)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Type") {
                    Picker("Type", selection: $viewModel.debtType) {
                        Text("I Gave (They owe me)").tag(DebtType.given)
                        Text("I Received (I owe them)").tag(DebtType.received)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Dates") {
                    DatePicker("Date Given", selection: $viewModel.dateGiven, displayedComponents: .date)

                    Toggle("Set Expected Return Date", isOn: $viewModel.hasExpectedReturnDate)

                    if viewModel.hasExpectedReturnDate {
                        DatePicker("Expected Return", selection: $viewModel.expectedReturnDate, displayedComponents: .date)
                    }
                }

                Section("Reminders") {
                    Toggle("Enable Reminders", isOn: $viewModel.reminderEnabled)

                    if viewModel.reminderEnabled {
                        Stepper("Remind \(viewModel.reminderDaysBefore) days before", value: $viewModel.reminderDaysBefore, in: 1...30)
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $viewModel.note)
                }
            }
            .navigationTitle(viewModel.editingDebt != nil ? "Edit Debt" : "New Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if viewModel.editingDebt != nil {
                            viewModel.updateDebt()
                        } else {
                            viewModel.addDebt()
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DebtsView()
}
