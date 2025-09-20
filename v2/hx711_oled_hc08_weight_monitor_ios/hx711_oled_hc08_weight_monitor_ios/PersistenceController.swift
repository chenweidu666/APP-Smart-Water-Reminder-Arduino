import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 添加一些示例数据用于预览
        let sampleRecord = WeightRecord(context: viewContext)
        sampleRecord.weight = 500
        sampleRecord.status = "Stable"
        sampleRecord.object = "Water"
        sampleRecord.timestamp = Date()
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // 创建内存中的NSManagedObjectModel
        let model = NSManagedObjectModel()
        
        // 创建WeightRecord实体
        let weightRecordEntity = NSEntityDescription()
        weightRecordEntity.name = "WeightRecord"
        weightRecordEntity.managedObjectClassName = "WeightRecord"
        
        // 添加属性
        let weightAttribute = NSAttributeDescription()
        weightAttribute.name = "weight"
        weightAttribute.attributeType = .integer32AttributeType
        weightAttribute.defaultValue = 0
        
        let statusAttribute = NSAttributeDescription()
        statusAttribute.name = "status"
        statusAttribute.attributeType = .stringAttributeType
        
        let objectAttribute = NSAttributeDescription()
        objectAttribute.name = "object"
        objectAttribute.attributeType = .stringAttributeType
        
        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        
        let isRemovedAttribute = NSAttributeDescription()
        isRemovedAttribute.name = "isRemoved"
        isRemovedAttribute.attributeType = .booleanAttributeType
        isRemovedAttribute.defaultValue = false
        
        weightRecordEntity.properties = [weightAttribute, statusAttribute, objectAttribute, timestampAttribute, isRemovedAttribute]
        
        // 设置模型实体
        model.entities = [weightRecordEntity]
        
        // 创建持久化容器
        container = NSPersistentContainer(name: "WeightMonitor", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
