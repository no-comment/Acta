import SwiftUI
import QuickLookUI

struct DocumentPreviewView: NSViewRepresentable {
    let url: URL?

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView()
        view.autostarts = true
        if let url {
            view.previewItem = url as NSURL
        }
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        if nsView.previewItem?.previewItemURL != url {
            if let url {
                nsView.previewItem = url as NSURL
            } else {
                nsView.previewItem = nil
            }
        }
    }
}

#Preview {
    DocumentPreviewView(url: nil)
}
