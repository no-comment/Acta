import AppKit
import SwiftUI

struct TokenField: NSViewRepresentable {
    @Binding var tokens: [String]
    var placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(tokens: $tokens)
    }

    func makeNSView(context: Context) -> NSTokenField {
        let field = NSTokenField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.tokenStyle = .rounded
        field.tokenizingCharacterSet = CharacterSet(charactersIn: ",\n")
        field.objectValue = tokens
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ nsView: NSTokenField, context: Context) {
        let current = context.coordinator.tokens(from: nsView.objectValue)
        if current != tokens {
            nsView.objectValue = tokens
        }
    }

    final class Coordinator: NSObject, NSTokenFieldDelegate {
        @Binding private var tokens: [String]

        init(tokens: Binding<[String]>) {
            _tokens = tokens
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTokenField else { return }
            updateTokens(from: field.objectValue)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTokenField else { return }
            updateTokens(from: field.objectValue)
        }

        func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
            let cleaned = tokens.compactMap { $0 as? String }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return cleaned
        }

        func tokens(from object: Any?) -> [String] {
            if let values = object as? [String] {
                return values
            }
            if let values = object as? [Any] {
                return values.compactMap { $0 as? String }
            }
            if let value = object as? String {
                return value
                    .split(whereSeparator: { $0 == "," || $0.isNewline })
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            return []
        }

        private func updateTokens(from object: Any?) {
            let values = tokens(from: object)
            if values != tokens {
                tokens = values
            }
        }
    }
}
