import SwiftUI

struct SettingsView: View {
    @State private var openRouterKey: String = ""
    @State private var statusMessage: String?
    @State private var isSaving = false
    @AppStorage(DefaultKey.userDisplayName) private var userDisplayName: String = ""
    @AppStorage(DefaultKey.colorNegativeRed) private var colorNegativeRed: Bool = false
    @AppStorage(DefaultKey.colorPositiveGreen) private var colorPositiveGreen: Bool = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Color Negative Values Red", isOn: $colorNegativeRed)
                Toggle("Color Positive Values Green", isOn: $colorPositiveGreen)
            }
            
            Section("Identity") {
                TextField("Your name or company", text: $userDisplayName)

                Text("Used to determine incoming vs outgoing invoices and to avoid using your name as vendor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("OCR") {
                SecureField("OpenRouter API Key", text: $openRouterKey)
                    .textContentType(.password)

                HStack {
                    Button("Save") {
                        saveKey()
                    }
                    .disabled(isSaving)

                    Button("Clear") {
                        openRouterKey = ""
                        saveKey()
                    }
                    .disabled(isSaving)

                    if let statusMessage {
                        Text(statusMessage)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            openRouterKey = APIKeyStore.loadOpenRouterKey() ?? ""
        }
    }

    private func saveKey() {
        isSaving = true
        defer { isSaving = false }

        do {
            try APIKeyStore.saveOpenRouterKey(openRouterKey.trimmingCharacters(in: .whitespacesAndNewlines))
            statusMessage = "Saved"
        } catch {
            statusMessage = "Failed to save key"
        }
    }
}

#Preview {
    SettingsView()
}
