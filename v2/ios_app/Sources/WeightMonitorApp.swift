//
//  WeightMonitorApp.swift
//  WeightMonitor
//
//  Created by 陈纬 on 2025/9/20.
//

import SwiftUI
import CoreData

@main
struct WeightMonitorApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ConnectedView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
