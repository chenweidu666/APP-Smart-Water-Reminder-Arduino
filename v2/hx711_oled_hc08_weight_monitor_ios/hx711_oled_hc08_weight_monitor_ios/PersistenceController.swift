import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 创建一些示例数据用于预览
        let newItem = WeightRecord(context: viewContext)
        newItem.timestamp = Date()
        newItem.weight = 100
        newItem.status = "Stable"
        newItem.object = "杯子"
        newItem.isRemoved = false
        
        do {
            try viewContext.save()
        } catch {
            // 用fatalError替换实际的错误处理，这样在开发过程中会显示错误
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "WeightMonitor")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // 用fatalError替换实际的错误处理，这样在开发过程中会显示错误
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
