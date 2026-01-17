import SwiftUI

struct SettingsView: View {
    @State private var openRouterKey: String = ""
    @State private var statusMessage: String?
    @State private var isSaving = false

    var body: some View {
        Form {
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
