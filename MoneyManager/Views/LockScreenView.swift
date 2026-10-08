import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var securityManager: SecurityManager
    @State private var passcode = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var passcodeFocused: Bool

    private let security = SecurityService.shared
    private let settings = AppSettings.load()

    private var usesPasscode: Bool {
        settings.passcodeEnabled && security.loadPasscode() != nil
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("Money Manager")
                .font(.title.bold())

            if usesPasscode {
                Text("Enter your passcode")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(spacing: 16) {
                    SecureField("Passcode", text: $passcode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .font(.title2.monospacedDigit())
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(maxWidth: 220)
                        .focused($passcodeFocused)
                        .onSubmit { verifyPasscode() }

                    Button(action: verifyPasscode) {
                        Text("Unlock")
                            .font(.headline)
                            .frame(maxWidth: 220)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(passcode.isEmpty)
                }
            }

            if settings.biometricEnabled {
                Button(action: authenticateWithDevice) {
                    Label("Unlock with Face ID / Touch ID", systemImage: "faceid")
                }
                .buttonStyle(.bordered)
            }

            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            if settings.biometricEnabled {
                authenticateWithDevice()
            } else {
                passcodeFocused = true
            }
        }
    }

    private func verifyPasscode() {
        if security.verifyPasscode(passcode) {
            securityManager.unlock()
        } else {
            Haptics.error()
            showError = true
            errorMessage = "Invalid passcode"
            passcode = ""
        }
    }

    private func authenticateWithDevice() {
        Task {
            let success = await security.authenticateDeviceOwner()
            await MainActor.run {
                if success {
                    securityManager.unlock()
                } else if usesPasscode {
                    passcodeFocused = true
                }
            }
        }
    }
}

#Preview {
    LockScreenView()
        .environmentObject(SecurityManager())
}
