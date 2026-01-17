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

// MARK: - Optional Binding Extensions

extension Binding where Value == String? {
    /// Converts an optional String binding to a non-optional String binding.
    /// Empty strings are converted to nil when setting.
    var orEmpty: Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}

extension Binding where Value == Double? {
    /// Converts an optional Double binding to a non-optional Double binding.
    /// Zero values are converted to nil when setting.
    var orZero: Binding<Double> {
        Binding<Double>(
            get: { self.wrappedValue ?? 0 },
            set: { self.wrappedValue = $0 == 0 ? nil : $0 }
        )
    }
}

extension Binding where Value == Date? {
    /// Converts an optional Date binding to a non-optional Date binding.
    /// Uses distantPast as the nil placeholder.
    var orDistantPast: Binding<Date> {
        Binding<Date>(
            get: { self.wrappedValue ?? .distantPast },
            set: { self.wrappedValue = $0 == .distantPast ? nil : $0 }
        )
    }
}
