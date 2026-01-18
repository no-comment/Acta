import SwiftUI

struct OnboardingView: View {
    @AppStorage(DefaultKey.isNewUser) private var isNewUser: Bool = true
    @AppStorage(DefaultKey.userDisplayName) private var userDisplayName: String = ""
    @State private var openRouterKey: String = ""
    @State private var statusMessage: String?
    @State private var isCompleting = false

    var body: some View {
        VStack(spacing: 30) {
                HStack {
                    Image(.actaIcon)
                        .resizable()
                        .frame(width: 60, height: 60)
                    
                    VStack(alignment: .leading) {
                        Text("Acta")
                            .font(.largeTitle)
                            .fontWeight(.semibold)
                            .fontDesign(.serif)
                        
                        Text("Manage your invoices.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Welcome")
                    .font(.title2)
                    .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Name or Company")
                        .font(.headline)

                    TextField("e.g., John Smith or Acme Corp", text: $userDisplayName)
                        .textFieldStyle(.roundedBorder)

                    Text("Used to determine invoice direction and avoid using your name as a vendor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenRouter API Key")
                        .font(.headline)

                    SecureField("sk-or-v1-...", text: $openRouterKey)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)

                    Text("Required for OCR processing of invoices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 400)

            VStack(spacing: 8) {
                HStack {
                    Button("Skip for now") {
                        isNewUser = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCompleting || userDisplayName.isEmpty || openRouterKey.isEmpty)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(statusMessage.contains("Error") ? .red : .secondary)
                }
            }
        }
        .padding(40)
        .frame(width: 500)
        .onAppear {
            openRouterKey = APIKeyStore.loadOpenRouterKey() ?? ""
        }
    }

    private func completeOnboarding() {
        isCompleting = true
        defer { isCompleting = false }

        do {
            try APIKeyStore.saveOpenRouterKey(openRouterKey.trimmingCharacters(in: .whitespacesAndNewlines))
            isNewUser = false
        } catch {
            statusMessage = "Error saving API key"
        }
    }
}

#Preview {
    OnboardingView()
}
