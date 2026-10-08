import SwiftUI

struct AddTransactionView: View {
    @StateObject private var viewModel: AddTransactionViewModel
    @StateObject private var categoryViewModel = CategoryViewModel()
    @StateObject private var accountViewModel = AccountViewModel()
    @Environment(\.dismiss) var dismiss
    @FocusState private var amountFocused: Bool
    @State private var showNewCategory = false
    @State private var showNewAccount = false
    @State private var showDeleteConfirmation = false
    @State private var showCancelConfirmation = false

    init(editing transaction: Transaction? = nil) {
        _viewModel = StateObject(wrappedValue: AddTransactionViewModel(editing: transaction))
    }

    var body: some View {
        NavigationView {
            Form {
                if viewModel.isCancelled {
                    cancelledSection
                }
                Group {
                    typeSection
                    amountSection
                    categorySection
                    accountSection
                    detailsSection
                    locationSection
                    tagsSection
                    recurringSection
                }
                // A cancelled transaction is read-only until it is restored.
                .disabled(viewModel.isCancelled)

                if viewModel.isEditing {
                    deleteSection
                }
            }
            .navigationTitle(viewModel.isEditing ? LocalizedStringKey("Edit Transaction") : LocalizedStringKey("New Transaction"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .font(.body.weight(.semibold))
                    .disabled(viewModel.isSaving || viewModel.isCancelled)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        amountFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .confirmationDialog("Void this transaction?", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
                Button("Void Transaction", role: .destructive) {
                    Task {
                        if await viewModel.cancelTransaction() {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("The amount goes back to the account. The transaction stays in the list marked as cancelled and no longer counts in statistics.")
            }
            .confirmationDialog("Delete permanently?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        if await viewModel.delete() {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("The transaction will disappear from the list. This can't be undone.")
            }
            .sheet(isPresented: $showNewCategory) {
                CategoryFormView(viewModel: categoryViewModel) { category in
                    viewModel.selectedCategory = category
                    Task { await viewModel.loadData() }
                }
            }
            .sheet(isPresented: $showNewAccount) {
                AccountFormView(viewModel: accountViewModel) { account in
                    viewModel.selectedAccount = account
                    Task { await viewModel.loadData() }
                }
            }
        }
        .task {
            await viewModel.loadData()
            if !viewModel.isEditing {
                amountFocused = true
            }
            await viewModel.captureLocationIfNeeded()
        }
    }

    private var typeSection: some View {
        Section {
            Picker("Type", selection: $viewModel.type) {
                Text("Expense").tag(TransactionType.expense)
                Text("Income").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.type) { _ in
                Task { await viewModel.loadData() }
            }
        }
    }

    private var amountSection: some View {
        Section("Amount") {
            HStack {
                TextField("0", text: $viewModel.amount.amountFormatted())
                    .keyboardType(.decimalPad)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.type == .income ? .green : .primary)
                    .focused($amountFocused)
                Text(AppCurrency.symbol)
                    .font(.title)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var categorySection: some View {
        Section("Category") {
            CategoryPicker(categories: viewModel.categories, selection: $viewModel.selectedCategory) {
                categoryViewModel.prepareNew(type: viewModel.type == .income ? .income : .expense)
                showNewCategory = true
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            if viewModel.accounts.isEmpty {
                Button {
                    accountViewModel.prepareNew()
                    showNewAccount = true
                } label: {
                    Label("Create an account", systemImage: "plus.circle.fill")
                }
            } else {
                Picker("Account", selection: $viewModel.selectedAccount) {
                    ForEach(viewModel.accounts) { account in
                        Label(account.displayName, systemImage: account.icon)
                            .tag(Optional(account))
                    }
                }
                .pickerStyle(.menu)

                Button {
                    accountViewModel.prepareNew()
                    showNewAccount = true
                } label: {
                    Label("New account", systemImage: "plus")
                        .font(.subheadline)
                }
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)

            TextField("Note (optional)", text: $viewModel.note)
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        if viewModel.isLocating || viewModel.hasLocation {
            Section("Location") {
                if let latitude = viewModel.latitude, let longitude = viewModel.longitude {
                    LocationMapPreview(latitude: latitude, longitude: longitude)
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))

                    if let placeName = viewModel.placeName {
                        Label(placeName, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                    }

                    if let url = LocationMapPreview.mapsURL(latitude: latitude, longitude: longitude) {
                        Link(destination: url) {
                            Label("Open in Maps", systemImage: "map")
                        }
                    }

                    Button(role: .destructive) {
                        viewModel.removeLocation()
                    } label: {
                        Label("Remove Location", systemImage: "location.slash")
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Determining location…")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            HStack {
                TextField("Add tag", text: $viewModel.newTag)
                    .onSubmit {
                        viewModel.addTag()
                    }
                Button(action: { viewModel.addTag() }) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(viewModel.newTag.trimmed.isEmpty)
            }

            if !viewModel.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(verbatim: "#\(tag)")
                                    .font(.caption)
                                Button(action: { viewModel.removeTag(tag) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var recurringSection: some View {
        Section("Recurring") {
            Toggle("Recurring Transaction", isOn: $viewModel.isRecurring)

            if viewModel.isRecurring {
                Picker("Frequency", selection: $viewModel.recurringFrequency) {
                    ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                        Text(freq.title).tag(freq)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var cancelledSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Label("Cancelled", systemImage: "xmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.orange)
                if let cancelledAt = viewModel.editingTransaction?.cancelledAt {
                    Text("Cancelled on \(cancelledAt.formatted(date: .abbreviated, time: .shortened)). It doesn't affect balances or statistics.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)

            Button {
                Task {
                    if await viewModel.restoreTransaction() {
                        dismiss()
                    }
                }
            } label: {
                Label("Restore Transaction", systemImage: "arrow.uturn.backward.circle")
            }
        }
    }

    @ViewBuilder
    private var deleteSection: some View {
        Section {
            if viewModel.isCancelled {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Permanently", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    showCancelConfirmation = true
                } label: {
                    Label("Void Transaction", systemImage: "xmark.circle")
                }
            }
        }
    }
}

#Preview {
    AddTransactionView()
}
