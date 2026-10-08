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

    init(editing transaction: Transaction? = nil) {
        _viewModel = StateObject(wrappedValue: AddTransactionViewModel(editing: transaction))
    }

    var body: some View {
        NavigationView {
            Form {
                typeSection
                amountSection
                categorySection
                accountSection
                detailsSection
                tagsSection
                recurringSection
                if viewModel.isEditing {
                    deleteSection
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Transaction" : "New Transaction")
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
                    .disabled(viewModel.isSaving)
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
            .confirmationDialog("Delete this transaction?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        if await viewModel.delete() {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("The account balance will be adjusted.")
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
                TextField("0", text: $viewModel.amount)
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(viewModel.categories) { category in
                        CategoryChip(
                            category: category,
                            isSelected: viewModel.selectedCategory?.id == category.id
                        ) {
                            Haptics.tap()
                            viewModel.selectedCategory = category
                        }
                    }

                    NewItemChip(title: "New") {
                        categoryViewModel.prepareNew(type: viewModel.type == .income ? .income : .expense)
                        showNewCategory = true
                    }
                }
                .padding(.vertical, 4)
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
                        Label(account.name, systemImage: account.icon)
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
                                Text("#\(tag)")
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
                        Text(freq.rawValue.capitalized).tag(freq)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Transaction", systemImage: "trash")
            }
        }
    }
}

struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : Color(hex: category.color))
                    .frame(width: 50, height: 50)
                    .background(isSelected ? Color(hex: category.color) : Color(hex: category.color).opacity(0.15))
                    .clipShape(Circle())

                Text(category.name)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
    }
}

struct NewItemChip: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    )

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddTransactionView()
}
