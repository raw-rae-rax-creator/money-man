import SwiftUI

struct BillsView: View {
    @StateObject private var viewModel = BillsViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    subscriptionsSummary
                    upcomingBillsSection
                    subscriptionsList
                    overdueBillsSection
                }
                .padding()
            }
            .navigationTitle("Bills & Subscriptions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.showAddBillSheet = true }) {
                            Label("Add Bill", systemImage: "doc.text.fill")
                        }
                        Button(action: { viewModel.showAddSubscriptionSheet = true }) {
                            Label("Add Subscription", systemImage: "repeat")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddBillSheet) {
                BillFormView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showAddSubscriptionSheet) {
                SubscriptionFormView(viewModel: viewModel)
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
                    Text("Monthly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(viewModel.totalMonthlySubscriptions))
                        .font(.title2.bold())
                        .foregroundColor(.blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Yearly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(viewModel.totalYearlySubscriptions))
                        .font(.title3.bold())
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            HStack {
                Label("\(viewModel.subscriptions.count) Subscriptions", systemImage: "repeat")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Label("\(viewModel.bills.filter { !$0.isPaid }.count) Pending Bills", systemImage: "doc.text.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    private var upcomingBillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Bills")
                    .font(.headline)
                Spacer()
            }

            if viewModel.upcomingBills.isEmpty {
                Text("No upcoming bills")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.upcomingBills) { bill in
                    BillRowView(bill: bill, viewModel: viewModel)
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

    private var overdueBillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Overdue")
                    .font(.headline)
                    .foregroundColor(.red)
                Spacer()
            }

            if viewModel.overdueBills.isEmpty {
                Text("No overdue bills")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.overdueBills) { bill in
                    BillRowView(bill: bill, viewModel: viewModel)
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

    private var subscriptionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Subscriptions")
                    .font(.headline)
                Spacer()
            }

            if viewModel.subscriptions.isEmpty {
                Text("No subscriptions")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.subscriptions) { subscription in
                    SubscriptionRowView(subscription: subscription, viewModel: viewModel)
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

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

struct BillRowView: View {
    let bill: Bill
    @ObservedObject var viewModel: BillsViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(bill.name)
                    .font(.subheadline.bold())

                Text("Due \(bill.dueDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(bill.amount))
                    .font(.subheadline.bold())
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

            if !bill.isPaid {
                Button(action: {
                    viewModel.markBillAsPaid(bill)
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions {
            Button(role: .destructive) {
                viewModel.deleteBill(bill)
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

struct SubscriptionRowView: View {
    let subscription: Subscription
    @ObservedObject var viewModel: BillsViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .font(.subheadline.bold())

                Text("Next: \(subscription.nextBillingDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(subscription.amount))
                    .font(.subheadline.bold())

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

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
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
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Amount", text: $viewModel.billAmount)
                            .keyboardType(.decimalPad)
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
                    Stepper("Remind \(viewModel.billReminderDays) days before", value: $viewModel.billReminderDays, in: 1...30)
                }
            }
            .navigationTitle("New Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.addBill()
                        dismiss()
                    }
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
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Amount", text: $viewModel.subscriptionAmount)
                            .keyboardType(.decimalPad)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.addSubscription()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    BillsView()
}
