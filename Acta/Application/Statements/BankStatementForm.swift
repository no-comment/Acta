import SwiftUI
import SwiftData

struct BankStatementForm: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var statement: BankStatement
    @State private var isShowingDeleteConfirm = false
    
    init(for statement: BankStatement) {
        self.statement = statement
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            dataSection
            Divider()
            actionSection
        }
        .confirmationDialog(
            "Delete this statement?",
            isPresented: $isShowingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Statement", role: .destructive, action: deleteStatement)
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Labeled("Account Name") {
                TextField("Account Name", text: $statement.account.orEmpty)
            }
            
            Labeled("Payment Date") {
                DatePicker("Payment Date", selection: $statement.date.orDistantPast, displayedComponents: .date)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .labelsHidden()
            }
            
            Labeled("Amount") {
                TextField("Amount", value: $statement.amount.orZero, format: .number)
            }

            Labeled("Currency") {
                TextField("Currency", text: $statement.currency.orEmpty)
            }
            
            Labeled("Reference") {
                TextField("Reference", text: $statement.reference.orEmpty)
            }

            Labeled("Vendor") {
                TextField("Vendor", text: $statement.vendor.orEmpty)
            }
            
            Labeled("Notes") {
                TextField("Notes", text: $statement.notes)
            }
        }
    }
    
    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Delete Statement", systemImage: "trash", role: .destructive) {
                isShowingDeleteConfirm = true
            }
            .tint(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func deleteStatement() {
        modelContext.delete(self.statement)
    }
}

#Preview {
    ModelPreview { statement in
        BankStatementForm(for: statement)
    }
}
