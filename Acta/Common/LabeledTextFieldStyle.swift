import SwiftUI

struct Labeled<Content: View>: View {
    private var title: String
    private let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(self.title)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.leading, 8)
                .padding(.bottom, 3)
            
            content
        }
    }
}

#Preview {
    Labeled("Title") {
        TextField("Title", text: .constant("Value"))
    }
}
