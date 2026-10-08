import SwiftUI

struct DebtsView: View {
    @StateObject private var viewModel = DebtsViewModel()
    @State private var selectedFilter: DebtFilter = .active
    @State private var selectedType: DebtType? = nil
    @State private var selectedDebt: Debt?
    @State private var debtToDelete: Debt?

    enum DebtFilter: String, CaseIterable {
        case active = "Active"
        case overdue = "Overdue"
        case returned = "Returned"
        case all = "All"
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    summaryHeader
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    Picker("Status", selection: $selectedFilter) {
                        ForEach(DebtFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Type", selection: $selectedType) {
                        Text("All").tag(nil as DebtType?)
                        Text("Owed to me").tag(DebtType.given as DebtType?)
                        Text("I owe").tag(DebtType.received as DebtType?)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                if selectedFilter == .active && selectedType == nil && viewModel.balancesByPerson.count > 1 {
                    Section("By Person") {
                        ForEach(viewModel.balancesByPerson.prefix(5), id: \.name) { person in
                            HStack {
                                Text(person.name)
                                Spacer()
                                Text(person.balance >= 0 ? "owes you" : "you owe")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(abs(person.balance).formattedAsCurrency())
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundColor(person.balance >= 0 ? .orange : .blue)
                            }
                        }
                    }
                }

                debtsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Debts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.prepareNew()
                        viewModel.showAddSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet, onDismiss: { viewModel.resetForm() }) {
                DebtFormView(viewModel: viewModel)
            }
            .sheet(item: $selectedDebt) { debt in
                DebtDetailView(debtId: debt.id, viewModel: viewModel)
            }
            .confirmationDialog(
                "Delete this debt?",
                isPresented: Binding(
                    get: { debtToDelete != nil },
                    set: { if !$0 { debtToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let debt = debtToDelete {
                        viewModel.deleteDebt(debt)
                    }
                    debtToDelete = nil
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            viewModel.loadDebts()
        }
    }

    private var summaryHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryCard(
                    title: "Owed to me",
                    amount: viewModel.totalGiven,
                    icon: "arrow.up.right.circle.fill",
                    color: .orange
                )

                SummaryCard(
                    title: "I owe",
                    amount: viewModel.totalReceived,
                    icon: "arrow.down.left.circle.fill",
                    color: .blue
                )
            }

            HStack(spacing: 16) {
                Label("\(viewModel.activeDebts.count) active", systemImage: "clock")
                    .foregroundColor(.secondary)

                Label("\(viewModel.overdueDebts.count) overdue", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(viewModel.overdueDebts.isEmpty ? .secondary : .red)

                Spacer()

                Text("Net \(viewModel.netDebt >= 0 ? "+" : "")\(viewModel.netDebt.formattedAsCurrency())")
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.netDebt >= 0 ? .orange : .blue)
            }
            .font(.caption)
            .padding(.horizontal, 4)

            Text("Debts don't affect your balance or income/expense statistics.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var debtsSection: some View {
        let filteredDebts = getFilteredDebts()

        if filteredDebts.isEmpty {
            Section {
                emptyState
            }
        } else {
            Section {
                ForEach(filteredDebts) { debt in
                    DebtRowView(debt: debt)
                        .onTapGesture {
                            selectedDebt = debt
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                debtToDelete = debt
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                viewModel.editDebt(debt)
                                viewModel.showAddSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.gray)
                        }
                        .swipeActions(edge: .leading) {
                            if debt.status == .active {
                                Button {
                                    viewModel.markAsReturned(debt)
                                } label: {
                                    Label("Returned", systemImage: "checkmark.circle.fill")
                                }
                                .tint(.green)
                            } else {
                                Button {
                                    viewModel.markAsActive(debt)
                                } label: {
                                    Label("Reopen", systemImage: "arrow.uturn.backward.circle")
                                }
                                .tint(.blue)
                            }
                        }
                }
            } footer: {
                Text("Swipe right to mark as returned, tap for details and partial repayments.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No debts found")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Track money you've lent or borrowed")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Add Debt") {
                viewModel.prepareNew()
                viewModel.showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
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

// MARK: - Row

struct DebtRowView: View {
    let debt: Debt

    private var color: Color { debt.type == .given ? .orange : .blue }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(String(debt.personName.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(color)
                    .frame(width: 42, height: 42)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(debt.personName)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(debt.type == .given ? "Owes me" : "I owe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        statusBadge
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(debt.remainingAmount > 0 ? debt.remainingAmount.formattedAsCurrency() : debt.amount.formattedAsCurrency())
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundColor(debt.status == .returned ? .secondary : color)
                        .strikethrough(debt.status == .returned)

                    if debt.repaidAmount > 0 && debt.status == .active {
                        Text("of \(debt.amount.formattedAsCurrency())")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if debt.repaidAmount > 0 && debt.status == .active {
                ProgressView(value: debt.repaidFraction)
                    .tint(.green)
            }

            dueInfo
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var statusBadge: some View {
        if debt.status == .returned {
            badge("Returned", .green)
        } else if debt.isOverdue {
            badge("Overdue", .red)
        } else if debt.isDueSoon {
            badge("Due soon", .orange)
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var dueInfo: some View {
        if debt.status == .returned, let actualDate = debt.actualReturnDate {
            Label("Returned \(actualDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundColor(.green)
        } else if let expectedDate = debt.expectedReturnDate, let days = debt.daysUntilDue {
            HStack {
                Label("Due \(expectedDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                Spacer()
                if days > 0 {
                    Text("in \(days) d")
                        .foregroundColor(days <= 3 ? .orange : .secondary)
                } else if days == 0 {
                    Text("today")
                        .foregroundColor(.orange)
                } else {
                    Text("\(abs(days)) d overdue")
                        .foregroundColor(.red)
                }
            }
            .font(.caption)
            .foregroundColor(debt.isOverdue ? .red : .secondary)
        } else {
            Label("No due date · \(debt.daysActive) d ago", systemImage: "clock")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Detail

struct DebtDetailView: View {
    let debtId: UUID
    @ObservedObject var viewModel: DebtsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var repaymentAmount = ""
    @State private var repaymentDate = Date()
    @State private var showEdit = false
    @State private var showDeleteConfirmation = false
    @FocusState private var amountFocused: Bool

    private var debt: Debt? {
        viewModel.debts.first { $0.id == debtId }
    }

    var body: some View {
        NavigationView {
            Group {
                if let debt = debt {
                    content(debt)
                } else {
                    Text("Debt not found")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(debt?.personName ?? "Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if let debt = debt {
                        Button("Edit") {
                            viewModel.editDebt(debt)
                            showEdit = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showEdit, onDismiss: { viewModel.resetForm() }) {
                DebtFormView(viewModel: viewModel)
            }
            .confirmationDialog("Delete this debt?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let debt = debt {
                        viewModel.deleteDebt(debt)
                    }
                    dismiss()
                }
            }
        }
    }

    private func content(_ debt: Debt) -> some View {
        let color: Color = debt.type == .given ? .orange : .blue

        return Form {
            Section {
                VStack(spacing: 8) {
                    Text(debt.type == .given ? "\(debt.personName) owes me" : "I owe \(debt.personName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(debt.remainingAmount.formattedAsCurrency())
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(debt.status == .returned ? .green : color)
                    if debt.status == .returned {
                        Label("Fully returned", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.green)
                    } else if debt.repaidAmount > 0 {
                        ProgressView(value: debt.repaidFraction)
                            .tint(.green)
                        Text("\(debt.repaidAmount.formattedAsCurrency()) of \(debt.amount.formattedAsCurrency()) returned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if debt.status == .active {
                Section {
                    HStack {
                        TextField("Amount", text: $repaymentAmount)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                        Text(AppCurrency.symbol)
                            .foregroundColor(.secondary)
                        Button("All") {
                            repaymentAmount = AppCurrency.editString(debt.remainingAmount)
                        }
                        .buttonStyle(.bordered)
                    }
                    DatePicker("Date", selection: $repaymentDate, displayedComponents: .date)
                    Button {
                        if let value = AppCurrency.parseAmount(repaymentAmount) {
                            viewModel.addRepayment(to: debt, amount: value, date: repaymentDate)
                            repaymentAmount = ""
                            amountFocused = false
                        }
                    } label: {
                        Label("Add Repayment", systemImage: "plus.circle.fill")
                    }
                    .disabled((AppCurrency.parseAmount(repaymentAmount) ?? 0) <= 0)
                } header: {
                    Text("Partial Repayment")
                }

                Section {
                    Button {
                        viewModel.markAsReturned(debt)
                    } label: {
                        Label("Mark as Fully Returned", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }

            if !debt.repayments.isEmpty {
                Section("Repayments") {
                    ForEach(debt.repayments.sorted { $0.date > $1.date }) { repayment in
                        HStack {
                            Text(repayment.date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(repayment.amount.formattedAsCurrency())
                                .monospacedDigit()
                                .foregroundColor(.green)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.deleteRepayment(repayment, from: debt)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section("Details") {
                row("Amount", debt.amount.formattedAsCurrency())
                row("Date", debt.dateGiven.formatted(date: .long, time: .omitted))
                if let expected = debt.expectedReturnDate {
                    row("Due", expected.formatted(date: .long, time: .omitted))
                }
                if debt.reminderEnabled {
                    row("Reminder", "\(debt.reminderDaysBefore) days before")
                }
                if !debt.note.isEmpty {
                    Text(debt.note)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                if debt.status == .returned {
                    Button {
                        viewModel.markAsActive(debt)
                    } label: {
                        Label("Reopen Debt", systemImage: "arrow.uturn.backward.circle")
                    }
                }
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Debt", systemImage: "trash")
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Form

struct DebtFormView: View {
    @ObservedObject var viewModel: DebtsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Type", selection: $viewModel.debtType) {
                        Text("I lent").tag(DebtType.given)
                        Text("I borrowed").tag(DebtType.received)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(viewModel.debtType == .given ? "Someone owes you money." : "You owe someone money.")
                }

                Section("Person") {
                    TextField("Name", text: $viewModel.personName)
                        .textContentType(.name)

                    let suggestions = viewModel.knownPeople.filter {
                        viewModel.personName.isEmpty || $0.localizedCaseInsensitiveContains(viewModel.personName)
                    }.filter { $0 != viewModel.personName }

                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions.prefix(10), id: \.self) { name in
                                    Button(name) {
                                        viewModel.personName = name
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }

                Section("Amount") {
                    HStack {
                        TextField("0", text: $viewModel.amount)
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.semibold))
                        Text(AppCurrency.symbol)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Dates") {
                    DatePicker("Date", selection: $viewModel.dateGiven, displayedComponents: .date)

                    Toggle("Set Return Date", isOn: $viewModel.hasExpectedReturnDate)

                    if viewModel.hasExpectedReturnDate {
                        DatePicker("Return By", selection: $viewModel.expectedReturnDate, in: viewModel.dateGiven..., displayedComponents: .date)
                    }
                }

                if viewModel.hasExpectedReturnDate {
                    Section("Reminder") {
                        Toggle("Remind Me", isOn: $viewModel.reminderEnabled)

                        if viewModel.reminderEnabled {
                            Stepper("\(viewModel.reminderDaysBefore) days before", value: $viewModel.reminderDaysBefore, in: 0...30)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $viewModel.note)
                }
            }
            .navigationTitle(viewModel.editingDebt != nil ? "Edit Debt" : "New Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.editingDebt != nil {
                            viewModel.updateDebt()
                        } else {
                            viewModel.addDebt()
                        }
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .disabled(!viewModel.isFormValid)
                }
            }
        }
    }
}

#Preview {
    DebtsView()
}
