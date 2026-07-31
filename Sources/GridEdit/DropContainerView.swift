import AppKit
import UniformTypeIdentifiers

/// Accepts CSV/TSV files dropped anywhere on the document window and opens
/// each as a document (csv-editor's drag & drop open).
final class DropContainerView: NSView {
    private static let acceptedExtensions: Set<String> = ["csv", "tsv", "tab", "txt"]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func acceptedURLs(from info: NSDraggingInfo) -> [URL] {
        let urls = info.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return urls.filter {
            Self.acceptedExtensions.contains($0.pathExtension.lowercased())
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        acceptedURLs(from: sender).isEmpty ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = acceptedURLs(from: sender)
        guard !urls.isEmpty else { return false }
        for url in urls {
            NSDocumentController.shared.openDocument(
                withContentsOf: url, display: true) { _, _, error in
                if let error {
                    NSAlert(error: error).runModal()
                }
            }
        }
        return true
    }
}
