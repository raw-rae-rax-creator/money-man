import SwiftUI

/// Pushed from the "More" tab, so it relies on the parent NavigationView.
struct GoalsView: View {
    @StateObject private var viewModel = GoalsViewModel()
    @State private var selectedGoal: SavingsGoal?
    @State private var addAmount: String = ""
    @State private var goalToDelete: SavingsGoal?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                goalsList
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Savings Goals")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.resetForm()
                    viewModel.showAddSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddSheet, onDismiss: { viewModel.resetForm() }) {
            GoalFormView(viewModel: viewModel)
        }
        .sheet(item: $selectedGoal) { goal in
            AddAmountView(goal: goal, viewModel: viewModel, amount: $addAmount)
        }
        .confirmationDialog(
            "Delete \(goalToDelete?.name ?? "")?",
            isPresented: Binding(
                get: { goalToDelete != nil },
                set: { if !$0 { goalToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let goal = goalToDelete {
                    viewModel.deleteGoal(goal)
                }
                goalToDelete = nil
            }
        }
        .onAppear {
            viewModel.loadGoals()
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.totalSaved.formattedAsCurrency())
                        .font(.title.bold())
                        .foregroundColor(.accentColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.totalTarget.formattedAsCurrency())
                        .font(.title3.bold())
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.totalTarget > 0 {
                ProgressView(value: min(viewModel.totalSaved, viewModel.totalTarget), total: viewModel.totalTarget)
                    .progressViewStyle(.linear)
            }

            HStack(spacing: 20) {
                Label("\(viewModel.goals.count) Goals", systemImage: "target")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("\(viewModel.completedGoals) Completed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)

                Spacer()
            }
        }
        .cardStyle()
    }

    private var goalsList: some View {
        VStack(spacing: 12) {
            if viewModel.goals.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.goals) { goal in
                    GoalCardView(goal: goal) {
                        addAmount = ""
                        selectedGoal = goal
                    }
                    .contextMenu {
                        Button {
                            addAmount = ""
                            selectedGoal = goal
                        } label: {
                            Label("Add Funds", systemImage: "plus.circle")
                        }
                        Button {
                            viewModel.editGoal(goal)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            goalToDelete = goal
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Text("Touch and hold a goal to edit or delete it.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("No savings goals yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Create goals to track your savings progress")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Create Goal") {
                viewModel.resetForm()
                viewModel.showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct GoalCardView: View {
    let goal: SavingsGoal
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: goal.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: goal.color))
                    .frame(width: 48, height: 48)
                    .background(Color(hex: goal.color).opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name)
                        .font(.headline)

                    if let deadline = goal.deadline {
                        Text("Due \(deadline.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(goal.progress))%")
                        .font(.headline)
                        .foregroundColor(goal.isCompleted ? .green : Color(hex: goal.color))

                    if goal.isCompleted {
                        Text("Completed!")
                            .font(.caption2.bold())
                            .foregroundColor(.green)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(goal.currentAmount.formattedAsCurrency())
                        .font(.subheadline.bold().monospacedDigit())

                    Spacer()

                    Text(goal.targetAmount.formattedAsCurrency())
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                ProgressView(value: min(goal.progress, 100), total: 100)
                    .progressViewStyle(.linear)
                    .tint(Color(hex: goal.color))

                HStack {
                    if !goal.isCompleted {
                        Text("Remaining: \(goal.remaining.formattedAsCurrency())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: onAdd) {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .cardStyle()
    }
}

struct GoalFormView: View {
    @ObservedObject var viewModel: GoalsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Goal Details") {
                    TextField("Goal Name", text: $viewModel.goalName)

                    HStack {
                        TextField("Target Amount", text: $viewModel.targetAmount.amountFormatted())
                            .keyboardType(.decimalPad)
                        Text(AppCurrency.symbol)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        TextField("Already Saved", text: $viewModel.currentAmount.amountFormatted())
                            .keyboardType(.decimalPad)
                        Text(AppCurrency.symbol)
                            .foregroundColor(.secondary)
                    }

                    DatePicker("Deadline", selection: $viewModel.deadline, displayedComponents: .date)
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.icons, id: \.self) { icon in
                                Button(action: {
                                    viewModel.goalIcon = icon
                                }) {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(viewModel.goalIcon == icon ? .white : .primary)
                                        .background(viewModel.goalIcon == icon ? Color(hex: viewModel.goalColor) : Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
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
                                    viewModel.goalColor = color
                                }) {
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: viewModel.goalColor == color ? 3 : 0)
                                                .padding(-4)
                                        )
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(viewModel.editingGoal != nil ? LocalizedStringKey("Edit Goal") : LocalizedStringKey("New Goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.editingGoal != nil {
                            viewModel.updateGoal()
                        } else {
                            viewModel.addGoal()
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

struct AddAmountView: View {
    let goal: SavingsGoal
    @ObservedObject var viewModel: GoalsViewModel
    @Binding var amount: String
    @Environment(\.dismiss) var dismiss
    @FocusState private var focused: Bool

    private var value: Double? { AppCurrency.parseAmount(amount) }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        TextField("0", text: $amount.amountFormatted())
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .focused($focused)
                        Text(AppCurrency.symbol)
                            .foregroundColor(.secondary)
                            .font(.title2)
                    }
                } header: {
                    Text(goal.name)
                } footer: {
                    Text("Saved \(goal.currentAmount.formattedAsCurrency()) of \(goal.targetAmount.formattedAsCurrency())")
                }

                Section {
                    Button(action: {
                        if let value = value, value > 0 {
                            viewModel.addToGoal(goal, amount: value)
                            amount = ""
                            dismiss()
                        }
                    }) {
                        Text("Add \((value ?? 0).formattedAsCurrency())")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled((value ?? 0) <= 0)

                    Button(role: .destructive, action: {
                        if let value = value, value > 0 {
                            viewModel.addToGoal(goal, amount: -value)
                            amount = ""
                            dismiss()
                        }
                    }) {
                        Text("Withdraw \((value ?? 0).formattedAsCurrency())")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled((value ?? 0) <= 0)
                }
            }
            .navigationTitle("Add Funds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear { focused = true }
        }
    }
}

#Preview {
    NavigationView {
        GoalsView()
    }
}
