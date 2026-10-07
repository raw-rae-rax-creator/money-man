# Quick Start Guide

## Option 1: Using Xcodegen (Recommended)

### Prerequisites
```bash
brew install xcodegen
```

### Generate Project
```bash
cd MoneyManager
chmod +x setup.sh
./setup.sh
```

### Open and Run
```bash
open MoneyManager.xcodeproj
```

---

## Option 2: Manual Setup in Xcode

### Step 1: Create New Project
1. Open Xcode
2. File → New → Project
3. Select "iOS" tab → "App"
4. Click "Next"

### Step 2: Configure Project
- **Product Name**: MoneyManager
- **Team**: Your development team
- **Organization Identifier**: com.moneymanager
- **Interface**: SwiftUI
- **Language**: Swift
- **Storage**: CoreData (check this option)

### Step 3: Replace Generated Files
1. In Xcode, delete the default generated files:
   - ContentView.swift (we have our own)
   - MoneyManagerApp.swift (we have our own)

2. Drag and drop ALL Swift files from `MoneyManager/` folder:
   - Models/ (all files)
   - Views/ (all files)
   - ViewModels/ (all files)
   - Services/ (all files)
   - Utils/ (all files)
   - MoneyManagerApp.swift
   - ContentView.swift

3. Make sure "Copy items if needed" is checked
4. Make sure "Create groups" is selected
5. Add to target: MoneyManager

### Step 4: Add CoreData Model
1. File → New → File
2. Search for "Data Model"
3. Name: MoneyManagerModel
4. Save to MoneyManager folder
5. Add entities (see CoreData Model Setup in README.md)

### Step 5: Configure Info.plist
The Info.plist is already configured with:
- Face ID usage description
- File sharing enabled
- Document support

### Step 6: Build and Run
1. Select your simulator or device
2. Press Cmd+R or click Run button

---

## Option 3: Using Existing .xcodeproj (Minimal)

The included .xcodeproj is minimal. You need to:

1. Open MoneyManager.xcodeproj in Xcode
2. Add all Swift files manually:
   - Right-click on MoneyManager group
   - Add Files to "MoneyManager"...
   - Select all .swift files from MoneyManager/ folder
   - Check "Copy items if needed"
   - Click "Add"

3. Add CoreData model:
   - File → New → File → Data Model
   - Name: MoneyManagerModel
   - Add entities as described in README.md

4. Build and run

---

## Troubleshooting

### "No such module" errors
- Make sure all files are added to the target
- Clean build folder (Cmd+Shift+K)
- Build again (Cmd+B)

### CoreData errors
- Make sure MoneyManagerModel.xcdatamodeld exists
- Verify all entities are created
- Check entity names match code (TransactionEntity, CategoryEntity, etc.)

### Build fails
- Check deployment target is iOS 15.0+
- Verify Swift version is 5.9+
- Clean and rebuild

---

## File Structure

```
MoneyManager/
├── MoneyManager.xcodeproj/          # Xcode project
├── MoneyManager/
│   ├── Models/                      # Data models
│   │   ├── Transaction.swift
│   │   ├── Category.swift
│   │   ├── Account.swift
│   │   ├── Budget.swift
│   │   ├── SavingsGoal.swift
│   │   ├── Bill.swift
│   │   └── AppSettings.swift
│   ├── Views/                       # SwiftUI views
│   │   ├── ContentView.swift
│   │   ├── DashboardView.swift
│   │   ├── TransactionListView.swift
│   │   ├── AddTransactionView.swift
│   │   ├── GoalsView.swift
│   │   ├── BillsView.swift
│   │   ├── ReportsView.swift
│   │   ├── SettingsView.swift
│   │   └── ... (other views)
│   ├── ViewModels/                  # Business logic
│   │   ├── DashboardViewModel.swift
│   │   ├── TransactionListViewModel.swift
│   │   ├── AddTransactionViewModel.swift
│   │   ├── GoalsViewModel.swift
│   │   ├── BillsViewModel.swift
│   │   └── ... (other viewmodels)
│   ├── Services/                    # Core services
│   │   ├── DatabaseService.swift
│   │   ├── SecurityService.swift
│   │   ├── ImportExportService.swift
│   │   └── NotificationService.swift
│   ├── Utils/                       # Extensions
│   │   └── Extensions.swift
│   ├── Assets.xcassets/             # Images and colors
│   ├── MoneyManagerModel.xcdatamodeld/  # CoreData model
│   ├── Info.plist                   # App configuration
│   └── MoneyManagerApp.swift        # App entry point
├── project.yml                      # Xcodegen config
├── setup.sh                         # Setup script
├── README.md
├── FEATURES_COMPARISON.md
└── OFFLINE_ARCHITECTURE.md
```

---

## Next Steps

After successful setup:

1. **Run the app** on simulator or device
2. **Create your first account** (cash, bank, etc.)
3. **Add categories** (or use defaults)
4. **Create transactions**
5. **Set up budgets**
6. **Create savings goals**
7. **Track bills and subscriptions**

Enjoy your offline-first money manager! 💰

---

## Support

If you encounter issues:
1. Check Troubleshooting section above
2. Clean build folder (Cmd+Shift+K)
3. Delete derived data (Window → Projects → Delete Derived Data)
4. Try building again
