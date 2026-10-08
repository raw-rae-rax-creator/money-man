import SwiftUI

/// Pushed from the "More" tab, so it relies on the parent NavigationView.
struct BillsView: View {
    @StateObject private var viewModel = BillsViewModel()

    var body: some View {
        List {
            Section {
                subscriptionsSummary
            }

            if !viewModel.overdueBills.isEmpty {
                Section {
                    ForEach(viewModel.overdueBills) { bill in
                        BillRowView(bill: bill, viewModel: viewModel)
                    }
                } header: {
                    Text("Overdue")
                        .foregroundColor(.red)
                }
            }

            Section("Upcoming Bills") {
                if viewModel.upcomingBills.isEmpty {
                    Text("No upcoming bills")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.upcomingBills) { bill in
                        BillRowView(bill: bill, viewModel: viewModel)
                    }
                }
            }

            Section {
                if viewModel.subscriptions.isEmpty {
                    Text("No subscriptions")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.subscriptions) { subscription in
                        SubscriptionRowView(subscription: subscription, viewModel: viewModel)
                    }
                }
            } header: {
                Text("Subscriptions")
            } footer: {
                if !viewModel.subscriptions.isEmpty {
                    Text("Tap Pay when a subscription is charged: the amount is added to expenses and taken from the account. Swipe left to skip a period.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Bills & Subscriptions")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        viewModel.resetBillForm()
                        viewModel.showAddBillSheet = true
                    }) {
                        Label("Add Bill", systemImage: "doc.text.fill")
                    }
                    Button(action: {
                        viewModel.resetSubscriptionForm()
                        viewModel.showAddSubscriptionSheet = true
                    }) {
                        Label("Add Subscription", systemImage: "repeat")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddBillSheet) {
            BillFormView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAddSubscriptionSheet) {
            SubscriptionFormView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.paymentRequest) { request in
            PaymentSheet(
                request: request,
                accounts: viewModel.accounts,
                categories: viewModel.expenseCategories,
                defaultCategoryId: viewModel.defaultCategoryId
            ) { result in
                viewModel.completePayment(request, result)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    private var subscriptionsSummary: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subscriptions / month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.totalMonthlySubscriptions.formattedAsCurrency())
                        .font(.title2.bold())
                        .foregroundColor(.accentColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Per year")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.totalYearlySubscriptions.formattedAsCurrency())
                        .font(.title3.bold())
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            HStack {
                Label("Due this month", systemImage: "calendar")
                Spacer()
                Text(viewModel.totalDueThisMonth.formattedAsCurrency())
                    .fontWeight(.semibold)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Rows

/// "≈ $9.99" under the amount for items priced in another currency.
private func foreignPriceText(amount: Double?, currency: String?) -> String? {
    guard let amount = amount, let currency = currency else { return nil }
    return AppCurrency.format(amount, code: currency)
}

/// "Last paid 4 650 ₸ · 12 Sep"
private func lastPaymentText(amount: Double?, date: Date?) -> String? {
    guard let amount = amount, let date = date else { return nil }
    return "Last paid %@ · %@".localizedFormat(
        amount.formattedAsCurrency(),
        date.formatted(.dateTime.day().month(.abbreviated))
    )
}

struct PayButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Pay")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundColor(.white)
                .background(Color.green)
                .clipShape(Capsule())
        }
        // Borderless: only the capsule is tappable, not the whole row.
        .buttonStyle(.borderless)
    }
}

struct BillRowView: View {
    let bill: Bill
    @ObservedObject var viewModel: BillsViewModel

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(bill.name)
                        .font(.subheadline.bold())
                    if bill.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Due \(bill.dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(bill.isOverdue ? .red : (bill.isDueSoon ? .orange : .secondary))

                if let last = lastPaymentText(amount: bill.lastPaidAmount, date: bill.lastPaidAt) {
                    Text(last)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(bill.amount.formattedAsCurrency())
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundColor(bill.isOverdue ? .red : .primary)

                if let foreign = foreignPriceText(amount: bill.foreignAmount, currency: bill.foreignCurrency) {
                    Text(verbatim: "≈ " + foreign)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if !bill.isPaid {
                PayButton {
                    viewModel.requestPayment(for: bill)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading) {
            if !bill.isPaid {
                Button {
                    viewModel.requestPayment(for: bill)
                } label: {
                    Label("Pay", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.deleteBill(bill)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct SubscriptionRowView: View {
    let subscription: Subscription
    @ObservedObject var viewModel: BillsViewModel

    private var days: Int { subscription.daysUntilBilling }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.subheadline.bold())

                statusText
                    .font(.caption)

                if let last = lastPaymentText(amount: subscription.lastPaidAmount, date: subscription.lastPaidAt) {
                    Text(last)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(subscription.amount.formattedAsCurrency())
                    .font(.subheadline.bold().monospacedDigit())

                if let foreign = foreignPriceText(amount: subscription.foreignAmount, currency: subscription.foreignCurrency) {
                    Text(verbatim: "≈ " + foreign)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text(verbatim: "/ " + subscription.billingCycle.title.lowercased())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // The Pay button shows up from 3 days before the charge.
            if days <= 3 {
                PayButton {
                    viewModel.requestPayment(for: subscription)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading) {
            Button {
                viewModel.requestPayment(for: subscription)
            } label: {
                Label("Pay", systemImage: "checkmark.circle.fill")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.deleteSubscription(subscription)
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                viewModel.skip(subscription)
            } label: {
                Label("Skip", systemImage: "forward.end.fill")
            }
            .tint(.gray)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        let date = subscription.nextBillingDate.formatted(date: .abbreviated, time: .omitted)
        if days < 0 {
            Text("Overdue since \(date)")
                .foregroundColor(.red)
        } else if days == 0 {
            Text("Charged today")
                .foregroundColor(.orange)
        } else if days <= 3 {
            Text("Next: \(date)")
                .foregroundColor(.orange)
        } else {
            Text("Next: \(date)")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Payment sheet

/// Confirms a bill/subscription payment. By default the expected amount is paid;
/// "Different amount" is for when the charge differs (exchange rate, tariff change...).
struct PaymentSheet: View {
    let request: PaymentRequest
    let accounts: [Account]
    let categories: [Category]
    let onPay: (PaymentResult) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var chargedDifferently = false
    @State private var actualText = ""
    @State private var accountId: UUID?
    @State private var categoryId: UUID?
    @State private var date = Date()
    @State private var rememberAmount = false
    @FocusState private var actualFocused: Bool

    init(
        request: PaymentRequest,
        accounts: [Account],
        categories: [Category],
        defaultCategoryId: UUID?,
        onPay: @escaping (PaymentResult) -> Void
    ) {
        self.request = request
        self.accounts = accounts
        self.categories = categories
        self.onPay = onPay
        let savedAccount = accounts.first { $0.id == request.accountId }?.id
        _accountId = State(initialValue: savedAccount ?? accounts.first?.id)
        let savedCategory = categories.first { $0.id == request.categoryId }?.id
        _categoryId = State(initialValue: savedCategory ?? defaultCategoryId)
    }

    private var expected: Double {
        request.suggestedAmount
    }

    /// What gets recorded: the expected amount, or what was actually charged.
    private var amount: Double? {
        chargedDifferently ? AppCurrency.parseAmount(actualText) : expected
    }

    /// Actual minus expected, when the user entered a different amount.
    private var difference: Double? {
        guard chargedDifferently, let amount = amount else { return nil }
        let difference = amount - expected
        return abs(difference) >= 0.005 ? difference : nil
    }

    private var isValid: Bool {
        guard let amount = amount, amount > 0 else { return false }
        // An expense needs a category; without an account it's only marked as paid.
        return accountId == nil || categoryId != nil
    }

    var body: some View {
        NavigationView {
            Form {
                amountSection

                Section {
                    AccountPickerRow(title: "From Account", accounts: accounts, selection: $accountId)

                    if accountId != nil {
                        Picker("Category", selection: $categoryId) {
                            ForEach(categories) { category in
                                Text(category.displayName).tag(Optional(category.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                } footer: {
                    if accountId == nil {
                        Text("Only marks it as paid; no expense is recorded.")
                    } else {
                        Text("An expense is added to Transactions and the account balance goes down.")
                    }
                }

                if difference != nil {
                    Section {
                        Toggle("Expect this amount next time", isOn: $rememberAmount)
                    }
                }

                Section {
                    Button(action: pay) {
                        Text("Pay \((amount ?? 0).formattedAsCurrency())")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle(request.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: chargedDifferently) { isDifferent in
                actualFocused = isDifferent
            }
        }
    }

    private var amountSection: some View {
        Section {
            VStack(spacing: 4) {
                Text("Due \(request.dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(verbatim: expected.formattedAsCurrency())
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(chargedDifferently ? .secondary : .primary)
                    .strikethrough(difference != nil)

                if let foreign = request.foreignAmount, let currency = request.foreignCurrency {
                    Text(verbatim: "≈ " + AppCurrency.format(foreign, code: currency))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            Picker("Charged", selection: $chargedDifferently.animation()) {
                Text("As expected").tag(false)
                Text("Different amount").tag(true)
            }
            .pickerStyle(.segmented)

            if chargedDifferently {
                HStack {
                    Text("Actually charged")
                    Spacer()
                    TextField("0", text: $actualText.amountFormatted())
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .focused($actualFocused)
                    Text(AppCurrency.symbol)
                        .foregroundColor(.secondary)
                }

                if let last = request.lastPaidAmount, abs(last - expected) >= 0.005 {
                    Button {
                        actualText = AppCurrency.editString(last)
                    } label: {
                        Label("Same as last time: \(last.formattedAsCurrency())", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        } footer: {
            differenceFooter
        }
    }

    @ViewBuilder
    private var differenceFooter: some View {
        if let difference = difference {
            VStack(alignment: .leading, spacing: 2) {
                if difference > 0 {
                    Text("\(difference.formattedAsCurrency()) more than expected")
                        .foregroundColor(.red)
                } else {
                    Text("\(abs(difference).formattedAsCurrency()) less than expected")
                        .foregroundColor(.green)
                }

                // For a foreign price, the implied rate — remembered for the next estimate.
                if let foreign = request.foreignAmount, foreign > 0, let amount = amount {
                    let symbol = AppCurrency.info(for: request.foreignCurrency ?? "").symbol
                    Text(verbatim: "1 \(symbol) ≈ \((amount / foreign).formattedAsCurrency())")
                }
            }
        }
    }

    private func pay() {
        guard let amount = amount, isValid else { return }
        onPay(PaymentResult(
            amount: amount,
            accountId: accountId,
            categoryId: accountId == nil ? nil : categoryId,
            date: date,
            rememberAmount: difference != nil && rememberAmount
        ))
        dismiss()
    }
}

// MARK: - Forms

/// Optional price in another currency; the regular amount field is then the estimate.
struct ForeignPriceSection: View {
    @Binding var isEnabled: Bool
    @Binding var currency: String
    @Binding var amount: String
    let currencies: [CurrencyInfo]

    var body: some View {
        Section {
            Toggle("Priced in Another Currency", isOn: $isEnabled.animation())

            if isEnabled {
                Picker("Currency", selection: $currency) {
                    ForEach(currencies) { info in
                        Text(verbatim: "\(info.code) (\(info.symbol))").tag(info.code)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    TextField("Price", text: $amount.amountFormatted())
                        .keyboardType(.decimalPad)
                    Text(AppCurrency.info(for: currency).symbol)
                        .foregroundColor(.secondary)
                }
            }
        } footer: {
            if isEnabled {
                Text("Enter the approximate amount in %@ above. When you pay, you'll enter what was actually charged and the rate is remembered.".localizedFormat(AppCurrency.code))
            } else {
                Text("For example, a subscription billed in dollars.")
            }
        }
    }
}

struct BillFormView: View {
    @ObservedObject var viewModel: BillsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Bill Details") {
                    TextField("Bill Name", text: $viewModel.billName)

                    HStack {
                        TextField("Amount", text: $viewModel.billAmount.amountFormatted())
                            .keyboardType(.decimalPad)
                        Text(AppCurrency.symbol)
                            .foregroundColor(.secondary)
                    }

                    DatePicker("Due Date", selection: $viewModel.billDueDate, displayedComponents: .date)
                }

                ForeignPriceSection(
                    isEnabled: $viewModel.billHasForeignPrice,
                    currency: $viewModel.billForeignCurrency,
                    amount: $viewModel.billForeignAmount,
                    currencies: viewModel.foreignCurrencies
                )

                Section("Recurring") {
                    Toggle("Recurring Bill", isOn: $viewModel.billIsRecurring)

                    if viewModel.billIsRecurring {
                        Picker("Frequency", selection: $viewModel.billFrequency) {
                            ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                                Text(freq.title).tag(freq)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Reminders") {
                    Stepper("Remind \(viewModel.billReminderDays) days before", value: $viewModel.billReminderDays, in: 0...30)
                }
            }
            .navigationTitle("New Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.addBill()
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .disabled(!viewModel.isBillFormValid)
                }
            }
        }
    }
}

struct SubscriptionFormView: View {
    @ObservedObject var viewModel: BillsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Subscription Details") {
                    TextField("Subscription Name", text: $viewModel.subscriptionName)

                    HStack {
                        TextField("Amount", text: $viewModel.subscriptionAmount.amountFormatted())
                            .keyboardType(.decimalPad)
                        Text(AppCurrency.symbol)
                            .foregroundColor(.secondary)
                    }

                    Picker("Billing Cycle", selection: $viewModel.subscriptionCycle) {
                        ForEach(BillingCycle.allCases, id: \.self) { cycle in
                            Text(cycle.title).tag(cycle)
                        }
                    }
                    .pickerStyle(.menu)

                    DatePicker("Next Billing Date", selection: $viewModel.subscriptionNextDate, displayedComponents: .date)
                }

                ForeignPriceSection(
                    isEnabled: $viewModel.subscriptionHasForeignPrice,
                    currency: $viewModel.subscriptionForeignCurrency,
                    amount: $viewModel.subscriptionForeignAmount,
                    currencies: viewModel.foreignCurrencies
                )
            }
            .navigationTitle("New Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.addSubscription()
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .disabled(!viewModel.isSubscriptionFormValid)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        BillsView()
    }
}
