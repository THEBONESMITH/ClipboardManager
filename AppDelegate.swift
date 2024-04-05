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

    
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
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
        let _ = PersistenceController.shared // Ensure PersistenceController is correctly implemented
    }

    func setupStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard Manager")
        }
        statusBarItem.menu = NSMenu()
        statusBarItem.menu?.delegate = self
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

    func markAsFavourite(item: ClipboardItem, shouldToggle: Bool) {
        if shouldToggle {
            print("Toggling favourite status for item. Current status: \(item.isFavourite)")
            item.isFavourite.toggle()
        } else {
            // If shouldToggle is false, you still might want to ensure the item is marked as favourite.
            // So, you could explicitly set it to true here if that's the intended logic.
            // For example:
            // item.isFavourite = true
        }
        
        do {
            try PersistenceController.shared.container.viewContext.save()
            print("Toggle favourite status: Item \(item.isFavourite ? "is now a favourite" : "is no longer a favourite").")
        } catch {
            print("Toggle favourite status: Failed to toggle favourite status: \(error)")
        }
        
        // This method now supports being called with shouldToggle to either just mark as favourite without toggling,
        // or to toggle the state based on the shouldToggle flag.
    }
    
    func setupOptionKeyMonitoring() {
            NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.isOptionKeyPressed = event.modifierFlags.contains(.option)
                // As this is a global monitor, direct UI updates here may not reflect in active app state
            }
        }
    
    // NSMenuDelegate method
        func menuWillOpen(_ menu: NSMenu) {
            let optionKeyPressed = NSEvent.modifierFlags.contains(.option)
            updateMenuItemsForOptionKeyState(optionKeyPressed: optionKeyPressed)
        }
    
    func updateMenuItemsForOptionKeyState(optionKeyPressed: Bool) {
            // Adjust your menu items based on the optionKeyPressed state
            // This is where you'd add or remove the star symbol or any other indicators
            print("Option key pressed: \(optionKeyPressed)")
            updateStatusBarMenu() // Reconstruct the menu with updated items
        }
    
    func handleFlagsChanged(_ event: NSEvent) {
        let optionKeyPressed = event.modifierFlags.contains(.option)
        if self.isOptionKeyPressed != optionKeyPressed {
            self.isOptionKeyPressed = optionKeyPressed
            print("Option key state changed: \(optionKeyPressed ? "Pressed" : "Released")")
            DispatchQueue.main.async {
                self.updateStatusBarMenu()
            }
        }
    }
    
    func startClipboardMonitoring() {
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForNewClipboardContent()
        }
    }

    func checkForNewClipboardContent() {
        guard !isInternalCopy, let content = NSPasteboard.general.string(forType: .string), content != lastCapturedContent else { return }
        
        lastCapturedContent = content
        print("Detected new clipboard content: \(content)")
        
        // Save the new clipboard content and update the menu immediately.
        saveNewClipboardContent(content)
        
        // Ensure the menu update is called here, right after new content is detected and saved.
        DispatchQueue.main.async { [weak self] in
            self?.updateStatusBarMenu()
        }
    }

    func saveNewClipboardContent(_ content: String) {
        // Access the Core Data managed object context. This is essentially the workspace
        // where your app's managed objects (data) are handled.
        let context = PersistenceController.shared.container.viewContext

        // Create a fetch request for ClipboardItem entities. This is used to query
        // the database for entities that match certain conditions.
        let fetchRequest: NSFetchRequest<ClipboardItem> = ClipboardItem.fetchRequest()

        // Set a predicate on the fetch request. This specifies that we're only interested
        // in ClipboardItem entities where the 'content' attribute matches the 'content' parameter
        // passed into this function. It's like saying "find me a ClipboardItem where its content is equal to this string".
        fetchRequest.predicate = NSPredicate(format: "content == %@", content)

        do {
            // Execute the fetch request on the context. This attempts to find any existing items
            // in the database that match the predicate set above.
            let results = try context.fetch(fetchRequest)

            // Check if the fetch request found any matching items.
            if let existingItem = results.first {
                // If there's an existing item, it means we've previously saved an item with the same content.
                // Instead of creating a duplicate, we simply update its timestamp to the current date and time.
                // This could be useful for maintaining a "recently used" list where the most recent items
                // are always at the top.
                existingItem.timestamp = Date()
                print("Existing item, updated timestamp.")
            } else {
                // If no existing item was found, it means this is the first time we're saving this particular piece of content.
                // We then create a new ClipboardItem entity in the context, set its content and timestamp,
                // and prepare it to be saved to the database.
                let newItem = ClipboardItem(context: context)
                newItem.content = content
                newItem.timestamp = Date()
                print("New clipboard item saved.")
            }

            // Attempt to save any changes made in the context (including our new or updated item) to the database.
            // If no changes are detected, this operation simply does nothing.
            try context.save()
        } catch {
            // If there was an error during the fetch request or saving the context,
            // print the error to the console. This could be due to a variety of issues,
            // such as constraints in the database being violated.
            print("Error saving clipboard item: \(error)")
        }
    }
        
    func updateStatusBarMenu() {
        // Create a new menu that will appear in the status bar.
        let menu = NSMenu()

        // Start building the Favourites submenu.
        print("Creating Favourites Submenu...")
        // This creates a submenu titled "Favourites".
        let favouritesMenu = NSMenu(title: "Favourites")
        // Fetch favourite clipboard items from Core Data.
        let favouritesItems = fetchFavouriteClipboardItems()
        // Iterate through each favourite item.
        for item in favouritesItems {
            // Truncate the content to fit within the menu, appending "..." if needed.
            let menuItemTitle = item.content?.truncating(to: 24, truncationIndicator: "...") ?? ""
            // Create a menu item for each favourite item.
            let menuItem = NSMenuItem(title: menuItemTitle, action: #selector(clipboardItemClicked(_:)), keyEquivalent: "")
            // Attach the ClipboardItem object to the menuItem for later reference.
            menuItem.representedObject = item
            // Add the menuItem to the favouritesMenu.
            favouritesMenu.addItem(menuItem)
        }
        // Create a main menu item for "Favourites" which contains the favouritesMenu as its submenu.
        let favouritesMenuItem = NSMenuItem(title: "Favourites", action: nil, keyEquivalent: "")
        favouritesMenuItem.submenu = favouritesMenu
        // Add the "Favourites" submenu to the main menu.
        menu.addItem(favouritesMenuItem)

        // Add a separator to distinguish between sections of the menu.
        print("Adding Separator...")
        menu.addItem(NSMenuItem.separator())

        // Add recent clipboard items to the menu.
        print("Adding Clipboard Items...")
        // Fetch recent clipboard items from Core Data.
        let clipboardItems = fetchRecentClipboardItems()
        print("Processing \(clipboardItems.count) Clipboard Items for the main menu...")
        // Iterate through each clipboard item.
        for item in clipboardItems {
            // Truncate the content to fit within the menu, appending "..." if needed.
            let menuItemTitle = item.content?.truncating(to: 24, truncationIndicator: "...") ?? ""
            // Create a menu item for each clipboard item.
            let menuItem = NSMenuItem(title: menuItemTitle, action: #selector(clipboardItemClicked(_:)), keyEquivalent: "")
            // Attach the ClipboardItem object to the menuItem for later reference.
            menuItem.representedObject = item
            // If the item is marked as a favourite, add a star icon for visual feedback.
            if item.isFavourite {
                menuItem.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Favourite")
            }
            // Add the menuItem to the main menu.
            menu.addItem(menuItem)
        }

        // Add a quit option to the menu.
        print("Adding Quit Item...")
        menu.addItem(NSMenuItem.separator()) // Add another separator before the quit option.
        // Create and add a "Quit" menu item that terminates the app when selected.
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Update the status bar item's menu to the newly created menu.
        print("Finished Updating StatusBar Menu.")
        statusBarItem.menu = menu
    }

    @objc func favouriteItemClicked(_ sender: NSMenuItem) {
        // Your implementation here
    }
    
    func createFavouritesSubmenu() -> NSMenu {
        // Initialize a new submenu with the title "Favourites".
        let submenu = NSMenu(title: "Favourites")

        // Fetch the list of favourite clipboard items from Core Data.
        let favouriteItems = fetchFavouriteClipboardItems()

        // Iterate through each favourite item to process and add it to the submenu.
        for item in favouriteItems {
            // Truncate the item's content to 24 characters to ensure it fits within the menu display, appending "..." to indicate truncation if needed.
            let menuItemTitle = item.content?.truncating(to: 24) ?? ""

            // Create a new menu item for the favourite item using its truncated title.
            // Specify the action to be taken when the menu item is clicked, which is handled by the `clipboardItemClicked(_:)` method.
            // `keyEquivalent` is set to an empty string as no keyboard shortcut is assigned.
            let menuItem = NSMenuItem(title: menuItemTitle, action: #selector(clipboardItemClicked(_:)), keyEquivalent: "")

            // Associate the ClipboardItem object with the menu item for reference. This allows the action method to access the specific ClipboardItem related to the menu item.
            menuItem.representedObject = item

            // Add the configured menu item to the submenu.
            submenu.addItem(menuItem)
        }

        // Return the populated submenu. This allows the submenu to be used as part of a larger menu structure, such as in a status bar menu.
        return submenu
    }
    
    func addClipboardItems(to menu: NSMenu) {
        // Fetch the most recent clipboard items stored in the application's database.
        let clipboardItems = fetchRecentClipboardItems()

        // Log to the console the number of clipboard items being processed.
        print("Processing \(clipboardItems.count) Clipboard Items...")

        // Iterate through each clipboard item to add it to the menu.
        for item in clipboardItems {
            // Truncate the item's content to 24 characters, adding "..." to indicate truncation if necessary.
            // This ensures the menu item title fits within the menu without making it too wide.
            let menuItemTitle = item.content?.truncating(to: 24, truncationIndicator: "...") ?? ""

            // Create a new NSMenuItem for the clipboard item using the truncated title.
            // The action `clipboardItemClicked(_:)` is assigned to be triggered when the menu item is selected.
            // `keyEquivalent` is set to an empty string, meaning no keyboard shortcut is assigned.
            let menuItem = NSMenuItem(title: menuItemTitle, action: #selector(clipboardItemClicked(_:)), keyEquivalent: "")

            // Attach the ClipboardItem object to the NSMenuItem. This is used to identify which clipboard item
            // the menu item represents when an action is performed.
            menuItem.representedObject = item

            // Log the favourite status of the item to the console. This is useful for debugging purposes
            // and for understanding the state of each item as it's processed.
            print("Item '\(item.content ?? "unknown")' favourite status: \(item.isFavourite)")

            // If the clipboard item is marked as a favourite, add a star icon to its menu item
            // for visual feedback to the user. This indicates that the item is special or important.
            if item.isFavourite {
                print("Applying star to '\(item.content ?? "unknown")'")
                menuItem.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Favourite")
            }

            // Add the configured menu item to the menu passed into the function.
            // This populates the menu with the items fetched from the database.
            menu.addItem(menuItem)
        }
    }
    
    @objc func clipboardItemClicked(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else {
            print("Failed to retrieve ClipboardItem from menu item.")
            return
        }

        let optionKeyPressed = NSApp.currentEvent?.modifierFlags.contains(.option) ?? false
        // Determine if the click came from the Favourites submenu
        let isFromFavouritesMenu = sender.menu?.title == "Favourites"
        print("Option key pressed: \(optionKeyPressed), Is from Favourites Menu: \(isFromFavouritesMenu)")

        if optionKeyPressed {
            // When toggling from the Favourites menu, check if it should really toggle or just ensure it's marked as favourite
            // This part was missing clarity on how to handle items directly from the Favourites menu
            if isFromFavouritesMenu {
                // If already a favourite, attempt to unfavourite
                if item.isFavourite {
                    print("Attempting to unfavourite item with content: \(item.content ?? "nil")")
                    item.isFavourite = false
                }
            } else {
                // For items not in the Favourites menu, toggle as usual
                print("Toggling favourite status for item with content: \(item.content ?? "nil")")
                item.isFavourite.toggle()
            }

            do {
                try PersistenceController.shared.container.viewContext.save()
                print("Favourite status updated for item with content: \(item.content ?? "nil"). New status: \(item.isFavourite)")
            } catch {
                print("Failed to update favourite status for item: \(error)")
            }
        } else {
            // Handle copying content to clipboard
            copyItemContentToClipboard(item)
        }

        // Refresh the menu to reflect changes
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
