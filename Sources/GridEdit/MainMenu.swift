import AppKit

/// Programmatic main menu — an SPM app has no nib, so without this the app
/// has no Edit/File menus and none of the standard key equivalents
/// (Cmd+S, Cmd+C, Cmd+Z, …) reach the responder chain.
enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()

        // App menu (its top-level title is always the app name — macOS
        // ignores the item title here, so no localization needed for it).
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("About GridEdit"),
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Hide GridEdit"),
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(
            withTitle: L("Hide Others"),
            action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: L("Show All"),
                        action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Quit GridEdit"),
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        addSubmenu(appMenu, title: "GridEdit", to: main)

        // File menu
        let fileMenu = NSMenu(title: L("File"))
        fileMenu.addItem(withTitle: L("New"),
                         action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: L("Open…"),
                         action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: L("Close"),
                         action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(withTitle: L("Save…"),
                         action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        let saveAs = fileMenu.addItem(
            withTitle: L("Save As…"),
            action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "s")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(withTitle: L("Revert to Saved"),
                         action: #selector(NSDocument.revertToSaved(_:)), keyEquivalent: "")
        addSubmenu(fileMenu, title: L("File"), to: main)

        // Edit menu
        let editMenu = NSMenu(title: L("Edit"))
        editMenu.addItem(withTitle: L("Undo"),
                         action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: L("Redo"),
                                    action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L("Cut"),
                         action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L("Copy"),
                         action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L("Paste"),
                         action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L("Delete"),
                         action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L("Select All"),
                         action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L("Find…"),
                         action: #selector(GridViewController.performTextFinderShow(_:)),
                         keyEquivalent: "f")
        let findReplace = editMenu.addItem(
            withTitle: L("Find and Replace…"),
            action: #selector(GridViewController.performTextFinderShowReplace(_:)),
            keyEquivalent: "f")
        findReplace.keyEquivalentModifierMask = [.command, .option]
        editMenu.addItem(withTitle: L("Find Next"),
                         action: #selector(GridViewController.findNext(_:)), keyEquivalent: "g")
        let findPrevious = editMenu.addItem(
            withTitle: L("Find Previous"),
            action: #selector(GridViewController.findPrevious(_:)), keyEquivalent: "g")
        findPrevious.keyEquivalentModifierMask = [.command, .shift]
        addSubmenu(editMenu, title: L("Edit"), to: main)

        // Window menu
        let windowMenu = NSMenu(title: L("Window"))
        windowMenu.addItem(withTitle: L("Minimize"),
                           action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: L("Zoom"),
                           action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        addSubmenu(windowMenu, title: L("Window"), to: main)
        NSApp.windowsMenu = windowMenu

        return main
    }

    private static func addSubmenu(_ submenu: NSMenu, title: String, to main: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        main.addItem(item)
    }
}
