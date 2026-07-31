import AppKit
import GridEditCore

/// Bottom status bar: the document's format settings (applied on save)
/// plus a header toggle and a size readout. Pure view — changes are
/// reported through closures, display state comes from update(content:).
final class FormatBarView: NSView {
    var onEncodingChange: ((TextEncoding) -> Void)?
    var onDelimiterChange: ((Delimiter) -> Void)?
    var onLineEndingChange: ((LineEnding) -> Void)?
    var onHeaderToggle: ((Bool) -> Void)?

    private let encodingPopup = NSPopUpButton()
    private let delimiterPopup = NSPopUpButton()
    private let lineEndingPopup = NSPopUpButton()
    private let headerCheckbox = NSButton(
        checkboxWithTitle: "Header", target: nil, action: nil)
    private let sizeLabel = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)

        for popup in [encodingPopup, delimiterPopup, lineEndingPopup] {
            popup.controlSize = .small
            popup.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            popup.target = self
        }
        encodingPopup.addItems(withTitles: TextEncoding.allCases.map(\.rawValue))
        encodingPopup.action = #selector(encodingChanged)
        delimiterPopup.addItems(withTitles: Delimiter.allCases.map(\.displayName))
        delimiterPopup.action = #selector(delimiterChanged)
        lineEndingPopup.addItems(withTitles: [LineEnding.lf.rawValue, LineEnding.crlf.rawValue])
        lineEndingPopup.action = #selector(lineEndingChanged)

        headerCheckbox.controlSize = .small
        headerCheckbox.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        headerCheckbox.target = self
        headerCheckbox.action = #selector(headerToggled)

        sizeLabel.font = .monospacedDigitSystemFont(
            ofSize: NSFont.smallSystemFontSize, weight: .regular)
        sizeLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            label("Encoding:"), encodingPopup,
            label("Delimiter:"), delimiterPopup,
            label("Line ending:"), lineEndingPopup,
            headerCheckbox,
            NSView(), // spacer
            sizeLabel,
        ])
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private func label(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        return label
    }

    func update(content: DocumentContent) {
        encodingPopup.selectItem(withTitle: content.encoding.rawValue)
        delimiterPopup.selectItem(withTitle: content.delimiter.displayName)

        // CR-only files exist read-side; writing always maps CR to LF, so
        // the popup shows a transient CR entry until another choice is made.
        let hasCRItem = lineEndingPopup.itemTitles.contains(LineEnding.cr.rawValue)
        if content.lineEnding == .cr && !hasCRItem {
            lineEndingPopup.addItem(withTitle: LineEnding.cr.rawValue)
        } else if content.lineEnding != .cr && hasCRItem {
            lineEndingPopup.removeItem(withTitle: LineEnding.cr.rawValue)
        }
        lineEndingPopup.selectItem(withTitle: content.lineEnding.rawValue)

        headerCheckbox.state = content.hasHeader ? .on : .off
        sizeLabel.stringValue =
            "\(content.table.rows.count) rows × \(content.table.maxColumns) cols"
    }

    @objc private func encodingChanged() {
        guard let title = encodingPopup.titleOfSelectedItem,
              let encoding = TextEncoding(rawValue: title) else { return }
        onEncodingChange?(encoding)
    }

    @objc private func delimiterChanged() {
        guard let title = delimiterPopup.titleOfSelectedItem,
              let delimiter = Delimiter.allCases.first(where: { $0.displayName == title })
        else { return }
        onDelimiterChange?(delimiter)
    }

    @objc private func lineEndingChanged() {
        guard let title = lineEndingPopup.titleOfSelectedItem,
              let lineEnding = LineEnding(rawValue: title) else { return }
        onLineEndingChange?(lineEnding)
    }

    @objc private func headerToggled() {
        onHeaderToggle?(headerCheckbox.state == .on)
    }
}
