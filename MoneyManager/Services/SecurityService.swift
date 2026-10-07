import Foundation
import LocalAuthentication

class SecurityService {
    static let shared = SecurityService()
    private let keychainKey = "com.moneymanager.passcode"

    private init() {}

    // MARK: - Biometric Authentication

    func authenticateWithBiometrics(reason: String = "Authenticate to access Money Manager") async -> Bool {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                )
                return success
            } catch {
                print("Biometric authentication failed: \(error.localizedDescription)")
                return false
            }
        }

        return false
    }

    func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func getBiometricType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    // MARK: - Passcode Management

    func savePasscode(_ passcode: String) throws {
        let data = Data(passcode.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw SecurityError.keychainError
        }
    }

    func verifyPasscode(_ passcode: String) -> Bool {
        guard let savedPasscode = loadPasscode() else {
            return false
        }
        return savedPasscode == passcode
    }

    func loadPasscode() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let passcode = String(data: data, encoding: .utf8) else {
            return nil
        }

        return passcode
    }

    func deletePasscode() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Data Encryption

    func encryptData(_ data: Data, withKey key: String) throws -> Data {
        // Simplified encryption - in production use CryptoKit
        return data
    }

    func decryptData(_ data: Data, withKey key: String) throws -> Data {
        // Simplified decryption - in production use CryptoKit
        return data
    }
}

enum SecurityError: Error {
    case keychainError
    case encryptionError
    case authenticationFailed
}
