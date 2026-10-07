import SwiftUI

struct CategoryListView: View {
    @StateObject private var viewModel = CategoryViewModel()

    var body: some View {
        NavigationView {
            List {
                if !viewModel.expenseCategories.isEmpty {
                    Section("Expense Categories") {
                        ForEach(viewModel.expenseCategories) { category in
                            CategoryRowView(category: category)
                                .onTapGesture {
                                    viewModel.editCategory(category)
                                }
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
                }

                if !viewModel.incomeCategories.isEmpty {
                    Section("Income Categories") {
                        ForEach(viewModel.incomeCategories) { category in
                            CategoryRowView(category: category)
                                .onTapGesture {
                                    viewModel.editCategory(category)
                                }
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
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                CategoryFormView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadCategories()
            await viewModel.initializeDefaultCategories()
        }
        .refreshable {
            await viewModel.loadCategories()
        }
    }
}

struct CategoryRowView: View {
    let category: Category

    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundColor(Color(hex: category.color))
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color(hex: category.color).opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.subheadline.bold())

                if let budget = category.budgetLimit {
                    Text("Budget: \(budget.formattedAsCurrency())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct CategoryFormView: View {
    @ObservedObject var viewModel: CategoryViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Basic Info") {
                    TextField("Category Name", text: $viewModel.categoryName)

                    Picker("Type", selection: $viewModel.categoryType) {
                        Text("Expense").tag(CategoryType.expense)
                        Text("Income").tag(CategoryType.income)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.icons, id: \.self) { icon in
                                Button(action: {
                                    viewModel.categoryIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .frame(width: 50, height: 50)
                                        .background(viewModel.categoryIcon == icon ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.colors, id: \.self) { color in
                                Button(action: {
                                    viewModel.categoryColor = color
                                }) {
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(viewModel.categoryColor == color ? Color.primary : .clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Budget (Optional)") {
                    TextField("Budget Limit", text: $viewModel.budgetLimit)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(viewModel.editingCategory != nil ? "Edit Category" : "New Category")
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
                            if viewModel.editingCategory != nil {
                                await viewModel.updateCategory()
                            } else {
                                await viewModel.addCategory()
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    CategoryListView()
}
