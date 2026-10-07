import SwiftUI

struct GoalsView: View {
    @StateObject private var viewModel = GoalsViewModel()
    @State private var showAddAmount = false
    @State private var selectedGoal: SavingsGoal?
    @State private var addAmount: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCard
                    goalsList
                }
                .padding()
            }
            .navigationTitle("Savings Goals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                GoalFormView(viewModel: viewModel)
            }
            .sheet(item: $selectedGoal) { goal in
                AddAmountView(goal: goal, viewModel: viewModel, amount: $addAmount)
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
                    Text(formatCurrency(viewModel.totalSaved))
                        .font(.title.bold())
                        .foregroundColor(.blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(viewModel.totalTarget))
                        .font(.title3.bold())
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.totalTarget > 0 {
                ProgressView(value: viewModel.totalSaved, total: viewModel.totalTarget)
                    .progressViewStyle(.linear)
                    .tint(.blue)
            }

            HStack(spacing: 20) {
                Label("\(viewModel.goals.count) Goals", systemImage: "target")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("\(viewModel.completedGoals) Completed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }

    private var goalsList: some View {
        VStack(spacing: 12) {
            if viewModel.goals.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.goals) { goal in
                    GoalCardView(goal: goal, viewModel: viewModel)
                        .onTapGesture {
                            selectedGoal = goal
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No savings goals yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Create goals to track your savings progress")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: { viewModel.showAddSheet = true }) {
                Text("Create Goal")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

struct GoalCardView: View {
    let goal: SavingsGoal
    @ObservedObject var viewModel: GoalsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: goal.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: goal.color))
                    .frame(width: 50, height: 50)
                    .background(Color(hex: goal.color).opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name)
                        .font(.headline)

                    if let deadline = goal.deadline {
                        Text("Due \(deadline, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(goal.progress))%")
                        .font(.headline)
                        .foregroundColor(goal.isCompleted ? .green : .blue)

                    if goal.isCompleted {
                        Text("Completed!")
                            .font(.caption2.bold())
                            .foregroundColor(.green)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(formatCurrency(goal.currentAmount))
                        .font(.subheadline.bold())
                        .foregroundColor(.blue)

                    Spacer()

                    Text(formatCurrency(goal.targetAmount))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: min(goal.progress, 100), total: 100)
                    .progressViewStyle(.linear)
                    .tint(Color(hex: goal.color))

                HStack {
                    Text("Remaining: \(formatCurrency(goal.remaining))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: {
                        // Add amount action
                    }) {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .swipeActions {
            Button(role: .destructive) {
                viewModel.deleteGoal(goal)
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

struct GoalFormView: View {
    @ObservedObject var viewModel: GoalsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Goal Details") {
                    TextField("Goal Name", text: $viewModel.goalName)

                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Target Amount", text: $viewModel.targetAmount)
                            .keyboardType(.decimalPad)
                    }

                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("Current Amount", text: $viewModel.currentAmount)
                            .keyboardType(.decimalPad)
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
                                        .background(viewModel.goalIcon == icon ? Color.blue.opacity(0.2) : Color(.systemGray6))
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
                                    viewModel.goalColor = color
                                }) {
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(viewModel.goalColor == color ? Color.primary : .clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(viewModel.editingGoal != nil ? "Edit Goal" : "New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if viewModel.editingGoal != nil {
                            viewModel.updateGoal()
                        } else {
                            viewModel.addGoal()
                        }
                        dismiss()
                    }
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

    var body: some View {
        NavigationView {
            Form {
                Section("Add to \(goal.name)") {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                            .font(.title2)
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                }

                Section {
                    Button(action: {
                        if let amountValue = Double(amount), amountValue > 0 {
                            viewModel.addToGoal(goal, amount: amountValue)
                            amount = ""
                            dismiss()
                        }
                    }) {
                        Text("Add \(formatCurrency(Double(amount) ?? 0))")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(Double(amount) == nil || (Double(amount) ?? 0) <= 0)
                }
            }
            .navigationTitle("Add Funds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
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

#Preview {
    GoalsView()
}
