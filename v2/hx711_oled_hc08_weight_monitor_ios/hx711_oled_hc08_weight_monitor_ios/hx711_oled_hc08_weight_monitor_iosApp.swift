//
//  hx711_oled_hc08_weight_monitor_iosApp.swift
//  hx711_oled_hc08_weight_monitor_ios
//
//  Created by 陈纬 on 2025/9/20.
//

import SwiftUI

@main
struct hx711_oled_hc08_weight_monitor_iosApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
