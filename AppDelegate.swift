//
//  AppDelegate.swift
//  ClipboardManager5
//
//  Created by . . on 29/02/2024.
//

import Foundation
import Cocoa
import CoreData

extension String {
    func truncating(to length: Int, truncationIndicator: String = "...") -> String {
        guard self.count > length else { return self }
        return String(self.prefix(length - truncationIndicator.count)) + truncationIndicator
    }
}

    
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var statusBarItem: NSStatusItem!
    var clipboardTimer: Timer?
    var lastCapturedContent: String?
    var isInternalCopy = false
    var isOptionKeyPressed = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
            setupCoreData()
            setupStatusBarItem()
            startClipboardMonitoring()
            setupOptionKeyMonitoring()
        }

    func setupCoreData() {
            let _ = PersistenceController.shared
        }

    func setupStatusBarItem() {
            statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusBarItem.button {
                button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard Manager")
            }
            updateStatusBarMenu()
        }

    @objc func updateMenuForCurrentModifierFlags() {
            let flags = NSEvent.modifierFlags
            isOptionKeyPressed = flags.contains(.option)
            updateStatusBarMenu()
        }
    
    func copyItemToClipboardAndRefreshList(content: String) {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "content == %@", content)

        do {
            let existingItems = try context.fetch(fetchRequest)
            
            // Check if the item already exists
            if let existingItem = existingItems.first {
                // If it exists, update its timestamp to now to move it to the top
                existingItem.timestamp = Date()
                print("Item already exists. Moved to top.")
            } else {
                // If it doesn't exist, create a new item
                let newItem = ClipboardItem(context: context)
                newItem.content = content
                newItem.timestamp = Date()
                print("New item added.")
            }
            
            try context.save()
            // Refresh the menu to reflect changes
            DispatchQueue.main.async {
                self.updateStatusBarMenu()
            }
        } catch {
            print("Error updating or creating an item: \(error)")
        }
        refreshMenuImmediately()
    }

    func refreshMenuImmediately() {
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusBarMenu() // Make sure this updates the menu based on the latest data
        }
    }
    
    @objc func exampleAction(_ sender: NSMenuItem) {
            // Perform action based on whether the Option key is pressed
            if isOptionKeyPressed {
                print("Option key is pressed.")
            } else {
                print("Option key is not pressed.")
            }
        }
    
    func fetchFavouriteClipboardItems() -> [ClipboardItem] {
        print("Fetching favourite clipboard items...")
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isFavourite == %@", NSNumber(value: true))
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch favourite clipboard items: \(error)")
            return []
        }
    }

    func markAsFavourite(item: ClipboardItem) {
        item.isFavourite.toggle() // This toggles the isFavourite property
        do {
            try PersistenceController.shared.container.viewContext.save()
            print("Item \(item.isFavourite ? "marked as favourite" : "unmarked as favourite").")
        } catch {
            print("Failed to toggle favourite status: \(error)")
        }
        DispatchQueue.main.async {
            self.updateStatusBarMenu() // Refresh the menu to show the updated favourites
        }
    }
    
    func setupOptionKeyMonitoring() {
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let isOptionPressed = event.modifierFlags.contains(.option)
            print("Global flags changed: Option key is \(isOptionPressed ? "pressed" : "not pressed")")
            self?.isOptionKeyPressed = isOptionPressed
            self?.updateStatusBarMenu()
        }
    }
    
    func startClipboardMonitoring() {
            clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.checkForNewClipboardContent()
            }
        }

    func checkForNewClipboardContent() {
            guard !isInternalCopy else { return }
            let currentContent = NSPasteboard.general.string(forType: .string)
            if let content = currentContent, content != lastCapturedContent {
                lastCapturedContent = content
                saveNewClipboardContent(content)
            }
        }

    func saveNewClipboardContent(_ content: String) {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "content == %@", content)

        do {
            let existingItems = try context.fetch(fetchRequest)
            if let existingItem = existingItems.first {
                // Item exists, update timestamp
                existingItem.timestamp = Date()
                print("Existing item, updated timestamp.")
            } else {
                // No existing item, create new
                let newItem = ClipboardItem(context: context)
                newItem.content = content
                newItem.timestamp = Date()
                print("New clipboard item saved.")
            }
            try context.save()
        } catch {
            print("Error saving clipboard content: \(error)")
        }
    }
        
    func updateStatusBarMenu() {
        let menu = NSMenu()

        // Create Favourites Submenu
        let favouritesMenu = NSMenu(title: "Favourites")
        let favouritesItems = fetchFavouriteClipboardItems()
        for item in favouritesItems {
            let menuItemTitle = item.content?.truncating(to: 24) ?? ""
            let menuItem = NSMenuItem(title: menuItemTitle, action: #selector(clipboardItemClicked(_:)), keyEquivalent: "")
            menuItem.representedObject = item
            favouritesMenu.addItem(menuItem)
        }
        let favouritesMenuItem = NSMenuItem(title: "Favourites", action: nil, keyEquivalent: "")
        favouritesMenuItem.submenu = favouritesMenu
        menu.addItem(favouritesMenuItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Add Recent Clipboard Items
        let clipboardItems = fetchRecentClipboardItems()
        for item in clipboardItems {
            let menuItemTitle = item.content?.truncating(to: 24) ?? ""
            let menuItem = NSMenuItem(title: menuItemTitle, action: #selector(clipboardItemClicked(_:)), keyEquivalent: "")
            menuItem.representedObject = item
            menu.addItem(menuItem)
        }

        // Quit item
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusBarItem.menu = menu
    }

    @objc func favouriteItemClicked(_ sender: NSMenuItem) {
        // Your implementation here
    }
    
    func createFavouritesSubmenu() -> NSMenu {
            let submenu = NSMenu(title: "Favourites")
            let favouriteItems = fetchFavouriteClipboardItems()
            for item in favouriteItems {
                let menuItemTitle = item.content?.truncating(to: 24) ?? ""
                let menuItem = NSMenuItem(title: menuItemTitle, action: #selector(clipboardItemClicked(_:)), keyEquivalent: "")
                menuItem.representedObject = item
                submenu.addItem(menuItem)
            }
            return submenu
        }
    
    func addClipboardItems(to menu: NSMenu) {
            let clipboardItems = fetchRecentClipboardItems()
            for item in clipboardItems {
                let menuItemTitle = item.content?.truncating(to: 24) ?? ""
                let menuItem = NSMenuItem(title: menuItemTitle, action: #selector(clipboardItemClicked(_:)), keyEquivalent: "")
                menuItem.representedObject = item
                menu.addItem(menuItem)
            }
        }
    
    @objc func clipboardItemClicked(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else {
            print("Failed to retrieve ClipboardItem from menu item.")
            return
        }
        
        let optionKeyPressed = NSApp.currentEvent?.modifierFlags.contains(.option) ?? false
        print("Option key pressed state in clipboardItemClicked: \(optionKeyPressed)")

        if optionKeyPressed {
            print("Attempting to toggle favourite status for item with content: \(item.content ?? "nil")")
            toggleFavouriteStatus(for: item)
        } else {
            print("Copying content to clipboard for item with content: \(item.content ?? "nil")")
            copyItemContentToClipboard(item)
        }
        refreshMenuImmediately()
    }

    func toggleFavouriteStatus(for item: ClipboardItem) {
        print("Toggling favourite status for item. Current status: \(item.isFavourite)")
        item.isFavourite.toggle()
        do {
            try PersistenceController.shared.container.viewContext.save()
            print("Toggle favourite status: Item \(item.isFavourite ? "is now a favourite" : "is no longer a favourite").")
        } catch {
            print("Toggle favourite status: Failed to toggle favourite status: \(error)")
        }
        DispatchQueue.main.async {
            self.updateStatusBarMenu()
        }
    }
    
    func copyItemContentToClipboard(_ item: ClipboardItem) {
        guard let content = item.content else {
            print("Copy item content to clipboard: Attempted to copy nil content for item.")
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        print("Copy item content to clipboard: Copied content to clipboard: \(content)")
    }
    
    func moveItemToTop(_ item: ClipboardItem) {
        let context = PersistenceController.shared.container.viewContext
        item.timestamp = Date() // Update the timestamp to make it the most recent item
        do {
            try context.save()
            print("Item moved to top.")
        } catch {
            print("Error moving item to top: \(error)")
        }
    }
    
        func fetchRecentClipboardItems() -> [ClipboardItem] {
            let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            fetchRequest.fetchLimit = 20

            do {
                return try PersistenceController.shared.container.viewContext.fetch(fetchRequest)
            } catch {
                print("Failed to fetch clipboard items: \(error)")
                return []
            }
        }

        func copyContentToClipboard(_ content: String) {
            isInternalCopy = true
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(content, forType: .string)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isInternalCopy = false
            }
        }

        // Remember to implement any required cleanup
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
