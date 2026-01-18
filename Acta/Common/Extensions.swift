import SwiftUI
import Foundation

// MARK: - Comparable Optionals
// Used for Table sorting
extension Optional: @retroactive Comparable where Wrapped: Comparable {
    public static func < (lhs: Wrapped?, rhs: Wrapped?) -> Bool {
        if let lhs, let rhs {
            return lhs < rhs
        }
        return lhs == nil && rhs != nil
    }
}

// Swift 6: Use @retroactive to make intent clear
extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data) else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return result
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
