import SwiftUI

/// Pushed from the "More" tab, so it relies on the parent NavigationView.
struct CategoryListView: View {
    @StateObject private var viewModel = CategoryViewModel()
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            Section {
                ForEach(viewModel.expenseCategories) { category in
                    categoryRow(category)
                }
                .onMove { source, destination in
                    viewModel.moveCategories(type: .expense, from: source, to: destination)
                }
            } header: {
                sectionHeader("Expense Categories", type: .expense)
            }

            Section {
                ForEach(viewModel.incomeCategories) { category in
                    categoryRow(category)
                }
                .onMove { source, destination in
                    viewModel.moveCategories(type: .income, from: source, to: destination)
                }
            } header: {
                sectionHeader("Income Categories", type: .income)
            } footer: {
                Text("Tap Edit and drag categories to reorder them. Categories at the top are shown first when you add a transaction.")
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button(editMode.isEditing ? LocalizedStringKey("Done") : LocalizedStringKey("Edit")) {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    }

                    Button(action: {
                        viewModel.prepareNew()
                        viewModel.showAddSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(editMode.isEditing)
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddSheet, onDismiss: { viewModel.resetForm() }) {
            CategoryFormView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadCategories()
        }
        .refreshable {
            await viewModel.loadCategories()
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey, type: CategoryType) -> some View {
        HStack {
            Text(title)
            Spacer()
            Menu {
                Button {
                    withAnimation { viewModel.sortByUsage(type: type) }
                } label: {
                    Label("Sort by usage", systemImage: "chart.bar.xaxis")
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    private func categoryRow(_ category: Category) -> some View {
        Button {
            if !editMode.isEditing {
                viewModel.editCategory(category)
            }
        } label: {
            CategoryRowView(category: category, showsChevron: !editMode.isEditing)
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteCategory(category)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct CategoryRowView: View {
    let category: Category
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(category: category, size: 36)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.body)

                if let budget = category.budgetLimit {
                    Text("Budget: \(budget.formattedAsCurrency())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(Color(.tertiaryLabel))
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

struct CategoryFormView: View {
    @ObservedObject var viewModel: CategoryViewModel
    var onSaved: ((Category) -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    private let columns = [GridItem(.adaptive(minimum: 48), spacing: 12)]

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.categoryIcon)
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(hex: viewModel.categoryColor))
                            .clipShape(Circle())

                        TextField("Category Name", text: $viewModel.categoryName)
                    }

                    Picker("Type", selection: $viewModel.categoryType) {
                        Text("Expense").tag(CategoryType.expense)
                        Text("Income").tag(CategoryType.income)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Icon") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.icons, id: \.self) { icon in
                            Button(action: {
                                viewModel.categoryIcon = icon
                            }) {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 48, height: 48)
                                    .foregroundColor(viewModel.categoryIcon == icon ? .white : .primary)
                                    .background(viewModel.categoryIcon == icon ? Color(hex: viewModel.categoryColor) : Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.colors, id: \.self) { color in
                            Button(action: {
                                viewModel.categoryColor = color
                            }) {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: viewModel.categoryColor == color ? 3 : 0)
                                            .padding(-4)
                                    )
                                    .frame(width: 48, height: 48)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if viewModel.categoryType == .expense {
                    Section {
                        HStack {
                            TextField("Monthly limit", text: $viewModel.budgetLimit.amountFormatted())
                                .keyboardType(.decimalPad)
                            Text(AppCurrency.symbol)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Budget (Optional)")
                    }
                }
            }
            .navigationTitle(viewModel.editingCategory != nil ? LocalizedStringKey("Edit Category") : LocalizedStringKey("New Category"))
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
                            if viewModel.editingCategory != nil {
                                await viewModel.updateCategory()
                            } else if let category = await viewModel.addCategory() {
                                onSaved?(category)
                            }
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
        CategoryListView()
    }
}
