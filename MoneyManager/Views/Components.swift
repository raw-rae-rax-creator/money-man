import SwiftUI
import MapKit

// MARK: - Category icon

/// Category icon in a tinted circle, or just a color dot when icons are turned off in Settings.
struct CategoryIconView: View {
    let category: Category?
    var size: CGFloat = 40
    @AppStorage(AppPreferences.showCategoryIconsKey) private var showIcons = true

    private var tint: Color { category.map { Color(hex: $0.color) } ?? .gray }

    var body: some View {
        if showIcons {
            Image(systemName: category?.icon ?? "questionmark.circle")
                .font(.system(size: size * 0.45))
                .foregroundColor(tint)
                .frame(width: size, height: size)
                .background(tint.opacity(0.15))
                .clipShape(Circle())
        } else {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
        }
    }
}

// MARK: - Category picker

/// Category selection for the transaction form. Shows either a horizontal carousel or a
/// compact grid of three + "⋯" that expands in place, depending on Settings.
struct CategoryPicker: View {
    let categories: [Category]
    @Binding var selection: Category?
    let onNewCategory: () -> Void

    @AppStorage(AppPreferences.categoryPickerStyleKey) private var styleRaw = CategoryPickerStyle.carousel.rawValue
    @State private var isExpanded = false

    private var style: CategoryPickerStyle {
        CategoryPickerStyle(rawValue: styleRaw) ?? .carousel
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4)

    var body: some View {
        switch style {
        case .carousel:
            carousel
        case .grid:
            grid
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(categories) { category in
                    chip(category)
                        .frame(width: 70)
                }
                NewItemChip(title: "New", action: onNewCategory)
                    .frame(width: 70)
            }
            .padding(.vertical, 4)
        }
    }

    /// The first three in the user's order; a selection further down replaces the third
    /// so the chosen category is always visible.
    private var compactCategories: [Category] {
        var visible = Array(categories.prefix(3))
        if let selected = selection,
           !visible.contains(where: { $0.id == selected.id }),
           categories.contains(where: { $0.id == selected.id }) {
            if visible.count == 3 {
                visible[2] = selected
            } else {
                visible.append(selected)
            }
        }
        return visible
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            if isExpanded {
                ForEach(categories) { category in
                    chip(category)
                }
                NewItemChip(title: "New", action: onNewCategory)
                MoreChip(isExpanded: true) {
                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded = false }
                }
            } else {
                ForEach(compactCategories) { category in
                    chip(category)
                }
                if categories.count > 3 {
                    MoreChip(isExpanded: false) {
                        withAnimation(.easeInOut(duration: 0.25)) { isExpanded = true }
                    }
                } else {
                    NewItemChip(title: "New", action: onNewCategory)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func chip(_ category: Category) -> some View {
        CategoryChip(category: category, isSelected: selection?.id == category.id) {
            Haptics.tap()
            selection = category
            if style == .grid && isExpanded {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded = false }
            }
        }
    }
}

struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    @AppStorage(AppPreferences.showCategoryIconsKey) private var showIcons = true

    private var color: Color { Color(hex: category.color) }

    var body: some View {
        Button(action: action) {
            if showIcons {
                VStack(spacing: 6) {
                    Image(systemName: category.icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : color)
                        .frame(width: 50, height: 50)
                        .background(isSelected ? color : color.opacity(0.15))
                        .clipShape(Circle())

                    Text(category.displayName)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text(category.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(isSelected ? color : color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }
}

struct NewItemChip: View {
    let title: LocalizedStringKey
    let action: () -> Void
    @AppStorage(AppPreferences.showCategoryIconsKey) private var showIcons = true

    var body: some View {
        Button(action: action) {
            if showIcons {
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
                .frame(maxWidth: .infinity)
            } else {
                Label(title, systemImage: "plus")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

/// "⋯" cell that expands / collapses the category grid in place.
struct MoreChip: View {
    let isExpanded: Bool
    let action: () -> Void
    @AppStorage(AppPreferences.showCategoryIconsKey) private var showIcons = true

    var body: some View {
        Button(action: action) {
            if showIcons {
                VStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.up" : "ellipsis")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 50, height: 50)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())

                    Text(isExpanded ? LocalizedStringKey("Less") : LocalizedStringKey("More"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                Image(systemName: isExpanded ? "chevron.up" : "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Map

struct LocationMapPreview: View {
    let latitude: Double
    let longitude: Double

    private struct Pin: Identifiable {
        let id = 0
        let coordinate: CLLocationCoordinate2D
    }

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        Map(
            coordinateRegion: .constant(MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 600,
                longitudinalMeters: 600
            )),
            annotationItems: [Pin(coordinate: coordinate)]
        ) { pin in
            MapMarker(coordinate: pin.coordinate, tint: .red)
        }
        .allowsHitTesting(false)
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    static func mapsURL(latitude: Double, longitude: Double) -> URL? {
        URL(string: "http://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(latitude),\(longitude)")
    }
}

// MARK: - Navigation

/// Wraps a screen in its own NavigationView when it's a tab, and leaves it bare when
/// it's pushed from "More" (a nested NavigationView would show two navigation bars).
struct NavigationContainer<Content: View>: View {
    let embed: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        if embed {
            NavigationView {
                content()
            }
            .navigationViewStyle(.stack)
        } else {
            content()
        }
    }
}

/// A screen of the app by tab identifier, used both for tabs and for "More" links.
struct AppScreen: View {
    let tab: AppTab
    var embedInNavigation: Bool = true

    var body: some View {
        switch tab {
        case .dashboard:
            DashboardView(embedInNavigation: embedInNavigation)
        case .transactions:
            TransactionListView(embedInNavigation: embedInNavigation)
        case .debts:
            DebtsView(embedInNavigation: embedInNavigation)
        case .reports:
            ReportsView(embedInNavigation: embedInNavigation)
        case .accounts:
            NavigationContainer(embed: embedInNavigation) { AccountsView() }
        case .categories:
            NavigationContainer(embed: embedInNavigation) { CategoryListView() }
        case .budgets:
            NavigationContainer(embed: embedInNavigation) { BudgetView() }
        case .goals:
            NavigationContainer(embed: embedInNavigation) { GoalsView() }
        case .bills:
            NavigationContainer(embed: embedInNavigation) { BillsView() }
        case .more:
            SettingsView()
        }
    }
}

// MARK: - Donut chart

struct DonutSegment: Identifiable {
    let id: String
    let color: Color
    let value: Double
}

/// Ring chart where each segment's length is its share of the total.
struct DonutChart: View {
    let segments: [DonutSegment]
    var lineWidth: CGFloat = 22
    @State private var progress: CGFloat = 0

    private var total: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    /// Fraction of the ring where the segment at `index` starts.
    private func start(of index: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(segments.prefix(index).reduce(0) { $0 + $1.value } / total)
    }

    var body: some View {
        // A small gap between segments keeps neighbouring colors apart.
        let gap: CGFloat = segments.count > 1 ? 0.006 : 0

        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: lineWidth)

            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                let from = start(of: index)
                let to = total > 0 ? from + CGFloat(segment.value / total) : from

                Circle()
                    .trim(from: from * progress, to: max(from, to - gap) * progress)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(lineWidth / 2)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                progress = 1
            }
        }
    }
}

// MARK: - Account picker

/// Menu picker of accounts with a "don't change balance" option (`nil`).
struct AccountPickerRow: View {
    let title: LocalizedStringKey
    let accounts: [Account]
    @Binding var selection: UUID?

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Don't change balance").tag(UUID?.none)
            ForEach(accounts) { account in
                Text(account.displayName).tag(Optional(account.id))
            }
        }
        .pickerStyle(.menu)
    }
}
