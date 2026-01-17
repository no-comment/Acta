import SwiftUI

struct BankStatementInspectorView: View {
    var statement: BankStatement
    var onClose: () -> Void
    
    init(for statement: BankStatement, onClose: @escaping () -> Void) {
        self.statement = statement
        self.onClose = onClose
    }
    
    var body: some View {
        ScrollView {
            BankStatementForm(for: statement)
                .padding()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    Button("Close", role: .close, action: onClose)
                        .buttonStyle(.bordered)
                    Spacer(minLength: 0)
                }
                .padding([.horizontal, .bottom])
                .padding(.top, 10)
            }
            .background(.regularMaterial)
        }
    }
}

#Preview {
    ModelPreview { statement in
        BankStatementInspectorView(for: statement, onClose: {})
    }
}
