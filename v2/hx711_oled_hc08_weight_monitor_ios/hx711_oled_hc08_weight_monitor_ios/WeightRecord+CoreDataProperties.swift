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
    @NSManaged public var isRemoved: Bool

}

extension WeightRecord : Identifiable {

}
