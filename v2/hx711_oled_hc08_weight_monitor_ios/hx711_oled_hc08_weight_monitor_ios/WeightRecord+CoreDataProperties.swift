//
//  WeightRecord+CoreDataProperties.swift
//  hx711_oled_hc08_weight_monitor_ios
//
//  Created by 陈纬 on 2025/9/20.
//

import Foundation
import CoreData

extension WeightRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeightRecord> {
        return NSFetchRequest<WeightRecord>(entityName: "WeightRecord")
    }

    @NSManaged public var weight: Int32
    @NSManaged public var status: String?
    @NSManaged public var object: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var deleted: Bool

}

extension WeightRecord : Identifiable {

}
