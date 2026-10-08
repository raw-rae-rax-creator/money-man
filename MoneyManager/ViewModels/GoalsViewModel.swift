import Foundation
import SwiftUI

@MainActor
class GoalsViewModel: ObservableObject {
    @Published var goals: [SavingsGoal] = []
    @Published var isLoading: Bool = false
    @Published var showAddSheet: Bool = false
    @Published var editingGoal: SavingsGoal?

    @Published var goalName: String = ""
    @Published var targetAmount: String = ""
    @Published var currentAmount: String = ""
    @Published var deadline: Date = Date().addingTimeInterval(60 * 60 * 24 * 365)
    @Published var goalIcon: String = "target"
    @Published var goalColor: String = "#3498DB"

    private let database = DatabaseService.shared
    private let goalsKey = ImportExportService.goalsKey

    let icons = ["target", "dollarsign.circle.fill", "house.fill", "car.fill", "airplane", "graduationcap.fill", "heart.fill", "gift.fill"]
    let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#F7DC6F", "#2ECC71", "#3498DB"]

    func loadGoals() {
        isLoading = true
        defer { isLoading = false }

        if let data = UserDefaults.standard.data(forKey: goalsKey),
           let decoded = try? JSONDecoder().decode([SavingsGoal].self, from: data) {
            goals = decoded.sorted { $0.progress < $1.progress }
        }
    }

    func saveGoals() {
        if let encoded = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encoded, forKey: goalsKey)
        }
    }

    var isFormValid: Bool {
        guard let target = AppCurrency.parseAmount(targetAmount), target > 0 else { return false }
        if !currentAmount.trimmed.isEmpty && AppCurrency.parseAmount(currentAmount) == nil { return false }
        return !goalName.trimmed.isEmpty
    }

    func addGoal() {
        guard isFormValid, let target = AppCurrency.parseAmount(targetAmount) else { return }

        let current = AppCurrency.parseAmount(currentAmount) ?? 0

        let goal = SavingsGoal(
            name: goalName.trimmed,
            targetAmount: target,
            currentAmount: current,
            deadline: deadline,
            icon: goalIcon,
            color: goalColor
        )

        goals.append(goal)
        saveGoals()
        Haptics.success()
        resetForm()
    }

    func updateGoal() {
        guard var goal = editingGoal else { return }
        guard isFormValid, let target = AppCurrency.parseAmount(targetAmount) else { return }

        goal.name = goalName.trimmed
        goal.targetAmount = target
        goal.currentAmount = AppCurrency.parseAmount(currentAmount) ?? goal.currentAmount
        goal.deadline = deadline
        goal.icon = goalIcon
        goal.color = goalColor

        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
            saveGoals()
            resetForm()
        }
    }

    func deleteGoal(_ goal: SavingsGoal) {
        goals.removeAll { $0.id == goal.id }
        saveGoals()
    }

    func addToGoal(_ goal: SavingsGoal, amount: Double) {
        guard let index = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        goals[index].currentAmount = max(goals[index].currentAmount + amount, 0)
        saveGoals()
        Haptics.success()
    }

    func editGoal(_ goal: SavingsGoal) {
        editingGoal = goal
        goalName = goal.name
        targetAmount = AppCurrency.editString(goal.targetAmount)
        currentAmount = AppCurrency.editString(goal.currentAmount)
        deadline = goal.deadline ?? Date()
        goalIcon = goal.icon
        goalColor = goal.color
        showAddSheet = true
    }

    func resetForm() {
        goalName = ""
        targetAmount = ""
        currentAmount = ""
        deadline = Date().addingTimeInterval(60 * 60 * 24 * 365)
        goalIcon = "target"
        goalColor = "#3498DB"
        editingGoal = nil
        showAddSheet = false
    }

    var totalSaved: Double {
        goals.reduce(0) { $0 + $1.currentAmount }
    }

    var totalTarget: Double {
        goals.reduce(0) { $0 + $1.targetAmount }
    }

    var completedGoals: Int {
        goals.filter { $0.isCompleted }.count
    }
}
