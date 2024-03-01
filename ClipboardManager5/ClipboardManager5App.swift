//
//  ClipboardManager5App.swift
//  ClipboardManager5
//
//  Created by . . on 29/02/2024.
//

import SwiftUI

@main
struct ClipboardManager5App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Omit the WindowGroup to prevent window creation
    var body: some Scene {
        Settings { // Use a Settings scene as a workaround or keep this block empty
            Text("Settings placeholder").frame(width: 200, height: 200)
        }
    }
}


