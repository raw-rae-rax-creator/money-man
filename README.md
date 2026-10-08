# Money Manager - iOS Finance Tracker

A secure, offline-first personal finance manager for iOS built with Swift and SwiftUI.

## Features

### Core Functionality
- **Transaction Tracking**: Record income and expenses with categories, accounts, and notes
- **Category Management**: Customizable expense and income categories with icons and colors
- **Account Management**: Track multiple accounts (cash, bank, credit cards, investments)
- **Budget Planning**: Set and monitor budgets by category
- **Reports & Analytics**: Visual breakdown of spending patterns and trends
- **Recurring Transactions**: Automate regular income and expenses
- **Savings Goals**: Create and track savings goals with progress indicators
- **Bill Tracking**: Manage bills with due dates and reminders
- **Subscription Management**: Track subscriptions and their costs

### Security & Privacy
- **Offline First**: All data stored locally on device - no internet connection required
- **Biometric Authentication**: Face ID / Touch ID support
- **Passcode Protection**: Optional passcode lock
- **Keychain Storage**: Secure storage of sensitive data
- **No Data Collection**: Your financial data never leaves your device

### Data Management
- **Import/Export**: CSV and JSON formats supported
- **Backup & Restore**: Create backups of all your data
- **Multi-Currency Support**: Track finances in different currencies
- **Data Persistence**: CoreData for reliable local storage

### User Experience
- **Modern UI**: Clean, intuitive SwiftUI interface
- **Dark Mode**: Full dark mode support
- **Customizable**: Personalize categories, colors, and icons
- **Quick Actions**: Fast transaction entry with smart defaults
- **Search & Filter**: Find transactions quickly

## Architecture

### Project Structure
```
MoneyManager/
├── Models/              # Data models (Transaction, Category, Account, Budget)
├── Views/               # SwiftUI views
├── ViewModels/          # Business logic and state management
├── Services/            # Core services (Database, Security, Import/Export)
├── Utils/               # Extensions and helpers
└── Resources/           # Assets and configuration files
```

### Design Patterns
- **MVVM**: Clear separation of concerns
- **Repository Pattern**: Centralized data access
- **Dependency Injection**: Loose coupling between components
- **Observer Pattern**: Reactive UI updates

## Technical Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Minimum iOS**: 15.0
- **Data Storage**: CoreData
- **Security**: LocalAuthentication, Keychain
- **Architecture**: MVVM

## Installation

### Prerequisites
- Xcode 14.0 or later
- iOS 15.0+ deployment target
- Swift 5.9+

### Setup Steps

1. **Open Project in Xcode**
   ```bash
   cd MoneyManager
   open moneai.xcodeproj
   ```

2. **Configure Signing**
   - Select the project in Xcode
   - Go to "Signing & Capabilities"
   - Select your development team

3. **Create CoreData Model**
   - File > New > File > Data Model
   - Name: `MoneyManagerModel`
   - Add entities:
     - `TransactionEntity`
     - `CategoryEntity`
     - `AccountEntity`
     - `BudgetEntity`

4. **Build and Run**
   - Select your target device/simulator
   - Press Cmd+R or click Run

## CoreData Model Setup

Create the following entities in your `.xcdatamodeld` file:

### TransactionEntity
```
id: UUID
amount: Double
type: String
categoryId: UUID
accountId: UUID
note: String
date: Date
isRecurring: Boolean
recurringFrequency: String?
tags: String
createdAt: Date
updatedAt: Date
```

### CategoryEntity
```
id: UUID
name: String
icon: String
color: String
type: String
parentId: UUID?
budgetLimit: Double
isActive: Boolean
sortOrder: Integer
createdAt: Date
```

### AccountEntity
```
id: UUID
name: String
type: String
balance: Double
currency: String
icon: String
color: String
isActive: Boolean
includeInTotal: Boolean
createdAt: Date
```

### BudgetEntity
```
id: UUID
categoryId: UUID?
amount: Double
period: String
startDate: Date
endDate: Date?
isActive: Boolean
createdAt: Date
```

## Usage Guide

### First Launch
1. App initializes with default categories
2. Create your accounts (cash, bank, etc.)
3. Set your preferred currency
4. Optionally enable biometric security

### Adding Transactions
1. Tap the "+" tab or "+" button
2. Select transaction type (Income/Expense)
3. Enter amount
4. Choose category
5. Select account
6. Add note and tags (optional)
7. Set date
8. Mark as recurring if needed
9. Tap "Save"

### Managing Categories
1. Go to Settings > Categories
2. Add custom categories with icons and colors
3. Set budget limits per category
4. Organize with parent categories

### Viewing Reports
1. Navigate to "Reports" tab
2. Select time period (Week/Month/Year/All)
3. View spending breakdown by category
4. See income vs expenses summary
5. Identify top spending categories

### Import/Export
**Export:**
- Settings > Export Data
- Choose CSV or JSON format
- Share via AirDrop, email, or save to Files

**Import:**
- Settings > Import Data
- Select CSV or JSON file
- Data will be merged with existing records

### Security
**Enable Face ID/Touch ID:**
- Settings > Security > Enable Biometrics

**Set Passcode:**
- Settings > Security > Enable Passcode

## Data Formats

### CSV Export Format
```csv
Date,Type,Amount,Category,Account,Note,Tags
2024-01-15T10:30:00Z,expense,25.50,Food & Dining,Cash,Lunch with team,work;food
```

### JSON Export Format
```json
{
  "transactions": [...],
  "categories": [...],
  "accounts": [...],
  "budgets": [...],
  "exportDate": "2024-01-15T10:30:00Z",
  "version": "1.0"
}
```

## Security Considerations

- All data stored locally using CoreData
- Sensitive data (passcodes) stored in Keychain
- Biometric authentication via LocalAuthentication framework
- No network connections - fully offline
- No analytics or tracking
- No third-party dependencies that collect data

## Future Enhancements

- [ ] Advanced charts and graphs (Swift Charts)
- [ ] Budget alerts and notifications
- [ ] Receipt scanning (OCR)
- [ ] Multi-language support
- [ ] Custom date formats
- [ ] Recurring transaction automation
- [ ] Export to PDF reports
- [ ] Widget support
- [ ] Apple Watch companion app

## Privacy Policy

Money Manager is committed to your privacy:
- No data collection
- No internet connection required
- No third-party analytics
- No advertising
- All data stays on your device
- Your financial information is never shared

## License

This project is provided as-is for educational and personal use.

## Support

For issues, questions, or contributions, please create an issue in the project repository.

## Credits

Built with Swift and SwiftUI
Inspired by top finance apps: MoneyWiz, YNAB, Monarch Money, and others.
