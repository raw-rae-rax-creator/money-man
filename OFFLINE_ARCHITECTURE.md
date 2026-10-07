# Offline-First Architecture Documentation

## Overview

Money Manager is designed as a fully offline-first application. All data is stored locally on the device and no internet connection is required for any functionality.

## Offline Capabilities

### ✅ Fully Offline Features

All core features work without internet connection:

1. **Transaction Management**
   - Create, read, update, delete transactions
   - Categorize expenses and income
   - Add notes, tags, and attachments
   - Recurring transactions

2. **Account Management**
   - Multiple account tracking
   - Balance calculations
   - Account transfers

3. **Budget Planning**
   - Create and manage budgets
   - Track spending against budgets
   - Budget alerts and notifications

4. **Reports & Analytics**
   - Spending breakdown by category
   - Income vs expense summaries
   - Historical trends
   - Custom date ranges

5. **Data Management**
   - Import from CSV/JSON files
   - Export to CSV/JSON files
   - Local backup and restore
   - File sharing via AirDrop, Files app

6. **Security**
   - Face ID / Touch ID authentication
   - Passcode protection
   - Keychain storage
   - Local data encryption

### ❌ No Internet Required

The app does NOT require internet for:
- Data storage (uses CoreData)
- Calculations and aggregations
- Import/Export operations
- Notifications and reminders
- Security features
- UI rendering

### ❌ No Network Code

The codebase contains:
- No `URLSession` usage
- No `URLRequest` calls
- No network APIs
- No cloud sync
- No remote analytics
- No crash reporting services
- No third-party SDKs that require network

## Data Storage Architecture

### Local Storage Stack

```
┌─────────────────────────────────────┐
│         SwiftUI Views               │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      ViewModels (ObservableObject)  │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      Services Layer                 │
│  - DatabaseService                  │
│  - SecurityService                  │
│  - ImportExportService              │
│  - NotificationService              │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│      CoreData (SQLite)              │
│  - TransactionEntity                │
│  - CategoryEntity                   │
│  - AccountEntity                    │
│  - BudgetEntity                     │
└─────────────────────────────────────┘
```

### Storage Locations

| Data Type | Storage | Encrypted | Location |
|-----------|---------|-----------|----------|
| Transactions | CoreData | No | App Sandbox |
| Categories | CoreData | No | App Sandbox |
| Accounts | CoreData | No | App Sandbox |
| Budgets | CoreData | No | App Sandbox |
| Passcodes | Keychain | Yes | Secure Enclave |
| Settings | UserDefaults | No | App Sandbox |
| Export Files | File System | No | App Sandbox / Files |

## Security Model

### No Network Attack Surface

Since the app has no network connectivity:
- No man-in-the-middle attacks possible
- No data interception during transmission
- No remote code execution vectors
- No API endpoint vulnerabilities
- No cloud storage breaches

### Local Security

- **CoreData**: Stored in app sandbox, protected by iOS security
- **Keychain**: Hardware-backed encryption for sensitive data
- **Biometrics**: LocalAuthentication framework, no biometric data stored
- **File Protection**: iOS file system encryption

## Import/Export Without Internet

### Export Flow

```
User Action → Export Data → Generate CSV/JSON → Save to Temp Directory → Share Sheet → User chooses destination (Files, AirDrop, etc.)
```

**Key Points:**
- Files generated locally
- No upload to servers
- User controls where file goes
- AirDrop uses local Bluetooth/WiFi (no internet)

### Import Flow

```
User Action → File Picker → Select Local File → Parse CSV/JSON → Validate Data → Insert into CoreData → Show Results
```

**Key Points:**
- Files read from local storage
- No server validation
- All processing done on device
- No data sent anywhere

## Privacy Guarantees

### What We DON'T Do

- ❌ Collect user data
- ❌ Send analytics
- ❌ Track user behavior
- ❌ Require account creation
- ❌ Sync to cloud
- ❌ Share data with third parties
- ❌ Require internet connection
- ❌ Store data on remote servers

### What We DO

- ✅ Store data locally only
- ✅ Encrypt sensitive data
- ✅ Respect user privacy
- ✅ Work offline completely
- ✅ Give user full control
- ✅ Allow data export
- ✅ Support local backups

## Info.plist Configuration

### Network Permissions

**NOT PRESENT (intentionally):**
- `NSAppTransportSecurity` - No network access needed
- `UIBackgroundModes` with `fetch` - No background fetch
- `UIBackgroundModes` with `remote-notification` - No push notifications

**PRESENT:**
- `UIFileSharingEnabled` - Allow file import/export
- `LSSupportsOpeningDocumentsInPlace` - Access files from Files app
- `NSFaceIDUsageDescription` - Biometric authentication

### Capabilities

**Required (in Xcode project):**
- Keychain Sharing (for passcode storage)

**NOT Required:**
- Push Notifications
- Background Modes (network)
- iCloud (no cloud sync)
- Associated Domains
- Network Extensions

## Testing Offline Functionality

### Test Scenarios

1. **Airplane Mode Test**
   - Enable Airplane Mode
   - Verify all features work
   - Create transactions
   - View reports
   - Export data
   - Import data

2. **No SIM Card Test**
   - Remove SIM card
   - Boot app
   - Verify full functionality

3. **WiFi Disabled Test**
   - Disable WiFi
   - Disable cellular data
   - Use app normally
   - Verify no network errors

### Expected Behavior

- ✅ App launches without network
- ✅ All CRUD operations work
- ✅ Reports generate successfully
- ✅ Import/Export functions work
- ✅ Notifications fire locally
- ✅ Security features work
- ✅ No error messages about connectivity

## Comparison with Other Apps

| Feature | Money Manager | MoneyWiz | YNAB | Monarch |
|---------|---------------|----------|------|---------|
| Offline Storage | ✅ CoreData | ✅ Local | ❌ Cloud | ❌ Cloud |
| Bank Sync | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| Cloud Sync | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| Internet Required | ❌ No | ⚠️ Partial | ✅ Yes | ✅ Yes |
| Privacy | ✅ 100% | ⚠️ Partial | ⚠️ Partial | ⚠️ Partial |
| Data Collection | ❌ None | ⚠️ Some | ⚠️ Some | ⚠️ Some |

## Trade-offs

### Advantages of Offline-First

1. **Privacy**: Complete control over data
2. **Speed**: Instant access, no network latency
3. **Reliability**: Works anywhere, anytime
4. **Security**: No network attack vectors
5. **No Subscriptions**: No server costs to pass on

### Limitations

1. **No Multi-Device Sync**: Data stays on one device
2. **No Bank Integration**: Manual entry only
3. **No Cross-Platform**: iOS only (by design)
4. **Local Backups Only**: User responsible for backups
5. **No Real-Time Updates**: All manual

## Future Considerations

### Potential Additions (Optional)

If network features are added in the future:
- Make them strictly opt-in
- Keep core functionality offline
- Use end-to-end encryption
- Open-source sync server
- Self-hosting option

### Won't Add

- Mandatory cloud sync
- Bank account integration
- Advertising
- Analytics tracking
- User accounts requirement

## Compliance

### GDPR

- ✅ No data collection
- ✅ No data processing
- ✅ No data transmission
- ✅ User has full control

### CCPA

- ✅ No personal information collected
- ✅ No data sold
- ✅ No data shared

### App Store Privacy Labels

**Data Not Collected:**
- No Usage Data
- No Financial Information
- No Contact Information
- No Identifiers
- No Location
- No Sensitive Info

## Conclusion

Money Manager is a truly offline-first application that prioritizes user privacy and data security. All functionality works without internet connection, and no data ever leaves the device. This architecture ensures maximum privacy, security, and reliability while providing all essential personal finance management features.
