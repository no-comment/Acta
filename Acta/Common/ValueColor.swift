import SwiftUI

struct ValueColorModifier: ViewModifier {
    @AppStorage(DefaultKey.colorNegativeRed) private var colorNegativeRed: Bool = false
    @AppStorage(DefaultKey.colorPositiveGreen) private var colorPositiveGreen: Bool = false
    let isNegative: Bool

    func body(content: Content) -> some View {
        content
            .foregroundColor(getColor())
    }

    private func getColor() -> Color {
        if self.isNegative {
            return self.colorNegativeRed ? .red : .primary
        }
        
        return self.colorPositiveGreen ? .green : .primary
    }
}

extension View {
    func valueColor<Value: Comparable & Numeric>(for value: Value?) -> some View {
        modifier(ValueColorModifier(isNegative: value < .zero))
    }
    
    func valueColor(isNegative: Bool) -> some View {
        modifier(ValueColorModifier(isNegative: isNegative))
    }
}
