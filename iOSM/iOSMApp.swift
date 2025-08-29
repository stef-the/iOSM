//
//  iOSMApp.swift
//  iOSM
//
//  Created by stef on 8/29/25.
//

import SwiftUI

@main
struct iOSMApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
