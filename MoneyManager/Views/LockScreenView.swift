import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var securityManager: SecurityManager
    @State private var passcode = ""
    @State private var showError = false
    @State private var errorMessage = ""

    private let security = SecurityService.shared

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Money Manager")
                .font(.title.bold())

            Text("Enter your passcode")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                SecureField("Passcode", text: $passcode)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Button(action: { verifyPasscode() }) {
                    Text("Unlock")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .frame(maxWidth: 200)
            }

            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }

    private func verifyPasscode() {
        if security.verifyPasscode(passcode) {
            securityManager.unlock()
        } else {
            showError = true
            errorMessage = "Invalid passcode"
            passcode = ""
        }
    }
}

#Preview {
    LockScreenView()
}
