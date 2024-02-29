//
//  ClipboardManager5App.swift
//  ClipboardManager5
//
//  Created by . . on 29/02/2024.
//

import SwiftUI

@main
struct ClipboardManager5App: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
