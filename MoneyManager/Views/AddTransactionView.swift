import SwiftUI

struct AddTransactionView: View {
    @StateObject private var viewModel = AddTransactionViewModel()
    @Environment(\.dismiss) var dismiss

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
            }
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            let success = await viewModel.save()
                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .task {
            await viewModel.loadData()
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
                Text("$")
                    .font(.title2)
                    .foregroundColor(.secondary)
                TextField("0.00", text: $viewModel.amount)
                    .keyboardType(.decimalPad)
                    .font(.title2)
            }
        }
    }

    private var categorySection: some View {
        Section("Category") {
            if viewModel.categories.isEmpty {
                Text("No categories available")
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.categories) { category in
                            CategoryChip(
                                category: category,
                                isSelected: viewModel.selectedCategory?.id == category.id
                            ) {
                                viewModel.selectedCategory = category
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            if viewModel.accounts.isEmpty {
                Text("No accounts available")
                    .foregroundColor(.secondary)
            } else {
                Picker("Account", selection: $viewModel.selectedAccount) {
                    ForEach(viewModel.accounts) { account in
                        Text(account.name).tag(account)
                    }
                }
                .pickerStyle(.menu)
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
                        .foregroundColor(.blue)
                }
            }

            if !viewModel.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption)
                                Button(action: { viewModel.removeTag(tag) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
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
}

struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: category.color))
                    .frame(width: 50, height: 50)
                    .background(Color(hex: category.color).opacity(isSelected ? 0.2 : 0.1))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color(hex: category.color) : .clear, lineWidth: 2)
                    )

                Text(category.name)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 70)
        }
        .buttonStyle(.plain)
    }
}

struct FlowLayout: View {
    let spacing: CGFloat = 8
    let content: () -> AnyView

    init<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        self.content = { AnyView(content()) }
    }

    var body: some View {
        HStack(spacing: spacing) {
            content()
        }
    }
}

#Preview {
    AddTransactionView()
}
