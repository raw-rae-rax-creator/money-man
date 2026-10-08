import SwiftUI

/// Pushed from the "More" tab, so it relies on the parent NavigationView.
struct AccountsView: View {
    @StateObject private var viewModel = AccountViewModel()
    @State private var accountToDelete: Account?

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    Text(viewModel.totalBalance.formattedAsCurrency())
                        .font(.headline.monospacedDigit())
                }
            } footer: {
                Text("Debts are tracked separately and are not included here.")
            }

            Section("Accounts") {
                if viewModel.accounts.isEmpty {
                    Text("No accounts yet")
                        .foregroundColor(.secondary)
                }

                ForEach(viewModel.accounts) { account in
                    Button {
                        viewModel.edit(account)
                    } label: {
                        AccountRowView(account: account)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            accountToDelete = account
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.prepareNew()
                    viewModel.showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddSheet, onDismiss: { viewModel.prepareNew() }) {
            AccountFormView(viewModel: viewModel)
        }
        .confirmationDialog(
            "Delete \(accountToDelete?.displayName ?? "")?",
            isPresented: Binding(
                get: { accountToDelete != nil },
                set: { if !$0 { accountToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let account = accountToDelete {
                    viewModel.delete(account)
                }
                accountToDelete = nil
            }
        } message: {
            Text("Existing transactions are kept.")
        }
        .onAppear {
            viewModel.loadAccounts()
        }
    }
}

struct AccountRowView: View {
    let account: Account

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: account.icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color(hex: account.color))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.body)
                Text(account.includeInTotal ? account.type.displayName : "%@ · not in total".localizedFormat(account.type.displayName))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(account.balance.formattedAsCurrency())
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundColor(account.balance < 0 ? .red : .primary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct AccountFormView: View {
    @ObservedObject var viewModel: AccountViewModel
    var onSaved: ((Account) -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.type.icon)
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(hex: viewModel.color))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        TextField("Account Name", text: $viewModel.name)
                    }

                    Picker("Type", selection: $viewModel.type) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                }

                Section {
                    HStack {
                        TextField("0", text: $viewModel.balance.amountFormatted(allowsNegative: true))
                            .keyboardType(.numbersAndPunctuation)
                        Text(AppCurrency.symbol)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(viewModel.editingAccount == nil ? LocalizedStringKey("Starting Balance") : LocalizedStringKey("Balance"))
                } footer: {
                    Text("Use a minus sign for credit card debt.")
                }

                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.colors, id: \.self) { color in
                                Button {
                                    viewModel.color = color
                                } label: {
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: viewModel.color == color ? 3 : 0)
                                                .padding(-4)
                                        )
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Include in Total Balance", isOn: $viewModel.includeInTotal)
                }
            }
            .navigationTitle(viewModel.editingAccount == nil ? LocalizedStringKey("New Account") : LocalizedStringKey("Edit Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let account = viewModel.save() {
                            onSaved?(account)
                            dismiss()
                        }
                    }
                    .font(.body.weight(.semibold))
                    .disabled(!viewModel.isFormValid)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        AccountsView()
    }
}
