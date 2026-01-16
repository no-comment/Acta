import SwiftUI
import Foundation

extension TableColumn where RowValue: Identifiable, Sort == Never, Content == Text, Label == Text {
    init(
        _ titleKey: LocalizedStringKey,
        value: KeyPath<RowValue, String?>
    ) {
        self.init(titleKey) { rowValue in
            Text(rowValue[keyPath: value] ?? "N/A")
        }
    }
}
