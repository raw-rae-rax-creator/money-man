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

            Section("Subscriptions") {
                if viewModel.subscriptions.isEmpty {
                    Text("No subscriptions")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.subscriptions) { subscription in
                        SubscriptionRowView(subscription: subscription, viewModel: viewModel)
                    }
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

struct BillRowView: View {
    let bill: Bill
    @ObservedObject var viewModel: BillsViewModel

    var body: some View {
        HStack {
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
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(bill.amount.formattedAsCurrency())
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundColor(bill.isOverdue ? .red : .primary)

                if bill.isOverdue {
                    Text("Overdue")
                        .font(.caption2.bold())
                        .foregroundColor(.red)
                } else if bill.isDueSoon {
                    Text("Due soon")
                        .font(.caption2.bold())
                        .foregroundColor(.orange)
                } else if bill.isPaid {
                    Text("Paid")
                        .font(.caption2.bold())
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .leading) {
            if !bill.isPaid {
                Button {
                    viewModel.markBillAsPaid(bill)
                } label: {
                    Label("Paid", systemImage: "checkmark.circle.fill")
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.subheadline.bold())

                Text("Next: \(subscription.nextBillingDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(subscription.amount.formattedAsCurrency())
                    .font(.subheadline.bold().monospacedDigit())

                Text("/ \(subscription.billingCycle.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .swipeActions {
            Button(role: .destructive) {
                viewModel.deleteSubscription(subscription)
            } label: {
                Label("Delete", systemImage: "trash")
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
                        TextField("Amount", text: $viewModel.billAmount)
                            .keyboardType(.decimalPad)
                        Text(AppCurrency.symbol)
                            .foregroundColor(.secondary)
                    }

                    DatePicker("Due Date", selection: $viewModel.billDueDate, displayedComponents: .date)
                }

                Section("Recurring") {
                    Toggle("Recurring Bill", isOn: $viewModel.billIsRecurring)

                    if viewModel.billIsRecurring {
                        Picker("Frequency", selection: $viewModel.billFrequency) {
                            ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue.capitalized).tag(freq)
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
                        TextField("Amount", text: $viewModel.subscriptionAmount)
                            .keyboardType(.decimalPad)
                        Text(AppCurrency.symbol)
                            .foregroundColor(.secondary)
                    }

                    Picker("Billing Cycle", selection: $viewModel.subscriptionCycle) {
                        ForEach(BillingCycle.allCases, id: \.self) { cycle in
                            Text(cycle.rawValue.capitalized).tag(cycle)
                        }
                    }
                    .pickerStyle(.menu)

                    DatePicker("Next Billing Date", selection: $viewModel.subscriptionNextDate, displayedComponents: .date)
                }
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
