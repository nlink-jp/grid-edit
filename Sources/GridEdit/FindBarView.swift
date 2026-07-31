import AppKit
import GridEditCore

/// The find / replace bar shown above the grid. Pure view: state changes
/// are reported through closures, display updates come from the owner.
final class FindBarView: NSView, NSSearchFieldDelegate {
    var onQueryChange: ((String) -> Void)?
    var onOptionsChange: ((FindOptions) -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onReplaceOne: ((String) -> Void)?
    var onReplaceAll: ((String) -> Void)?
    var onClose: (() -> Void)?

    let searchField = NSSearchField()
    let replaceField = NSTextField()
    private let matchLabel = NSTextField(labelWithString: "")
    private let caseButton = FindBarView.toggle("Aa", tip: "Case sensitive")
    private let regexButton = FindBarView.toggle(".*", tip: "Regular expression")
    private let wholeCellButton = FindBarView.toggle("Cell", tip: "Whole cell")
    private let replaceButton = NSButton(title: "Replace", target: nil, action: nil)
    private let replaceAllButton = NSButton(title: "All", target: nil, action: nil)

    var options: FindOptions {
        FindOptions(
            caseSensitive: caseButton.state == .on,
            regex: regexButton.state == .on,
            wholeCell: wholeCellButton.state == .on)
    }

    private static func toggle(_ title: String, tip: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.setButtonType(.pushOnPushOff)
        button.bezelStyle = .texturedRounded
        button.toolTip = tip
        button.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        return button
    }

    init() {
        super.init(frame: .zero)

        searchField.placeholderString = "Find"
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        replaceField.placeholderString = "Replace"
        replaceField.delegate = self
        replaceField.widthAnchor.constraint(equalToConstant: 150).isActive = true

        matchLabel.font = .monospacedDigitSystemFont(
            ofSize: NSFont.smallSystemFontSize, weight: .regular)
        matchLabel.textColor = .secondaryLabelColor

        let previousButton = NSButton(
            image: NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Previous")!,
            target: self, action: #selector(previousPressed))
        let nextButton = NSButton(
            image: NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Next")!,
            target: self, action: #selector(nextPressed))
        let closeButton = NSButton(
            image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")!,
            target: self, action: #selector(closePressed))
        for button in [previousButton, nextButton, closeButton] {
            button.bezelStyle = .texturedRounded
        }

        for button in [caseButton, regexButton, wholeCellButton] {
            button.target = self
            button.action = #selector(optionsChanged)
        }
        replaceButton.target = self
        replaceButton.action = #selector(replacePressed)
        replaceButton.bezelStyle = .texturedRounded
        replaceAllButton.target = self
        replaceAllButton.action = #selector(replaceAllPressed)
        replaceAllButton.bezelStyle = .texturedRounded
        replaceAllButton.toolTip = "Replace all"

        let stack = NSStackView(views: [
            searchField, caseButton, regexButton, wholeCellButton,
            matchLabel, previousButton, nextButton,
            replaceField, replaceButton, replaceAllButton,
            NSView(), // spacer
            closeButton,
        ])
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
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

    /// Shows or hides the replace controls (find-only vs find & replace).
    func setReplaceVisible(_ visible: Bool) {
        replaceField.isHidden = !visible
        replaceButton.isHidden = !visible
        replaceAllButton.isHidden = !visible
    }

    func setMatchStatus(current: Int?, total: Int) {
        if total == 0 {
            matchLabel.stringValue = searchField.stringValue.isEmpty ? "" : "0/0"
        } else {
            matchLabel.stringValue = "\((current ?? 0) + 1)/\(total)"
        }
    }

    // MARK: Actions

    @objc private func optionsChanged() {
        onOptionsChange?(options)
    }

    @objc private func nextPressed() { onNext?() }
    @objc private func previousPressed() { onPrevious?() }
    @objc private func closePressed() { onClose?() }
    @objc private func replacePressed() { onReplaceOne?(replaceField.stringValue) }
    @objc private func replaceAllPressed() { onReplaceAll?(replaceField.stringValue) }

    // MARK: NSTextFieldDelegate

    func controlTextDidChange(_ notification: Notification) {
        if (notification.object as? NSSearchField) === searchField {
            onQueryChange?(searchField.stringValue)
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            if control === replaceField {
                onReplaceOne?(replaceField.stringValue)
            } else {
                NSApp.currentEvent?.modifierFlags.contains(.shift) == true
                    ? onPrevious?() : onNext?()
            }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            onClose?()
            return true
        default:
            return false
        }
    }
}
