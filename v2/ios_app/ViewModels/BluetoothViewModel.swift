import Foundation
import CoreBluetooth
import SwiftUI
import Combine
import CoreData

struct WeightData: Identifiable {
    let id = UUID()
    let weight: Int
    let status: String
    let object: String
    let time: Int
    let system: String
    let timestamp = Date()
}

struct DrinkRecord: Identifiable {
    let id = UUID()
    let beforeWeight: Int  // 喝水前重量
    let afterWeight: Int   // 喝水后重量
    let drinkAmount: Int   // 喝水量
    let timestamp: Date
    let beforeRecord: WeightRecord
    let afterRecord: WeightRecord
}

struct BluetoothDevice: Identifiable {
    let id = UUID()
    let name: String
    let peripheral: CBPeripheral?
    
    init(name: String, peripheral: CBPeripheral? = nil) {
        self.name = name
        self.peripheral = peripheral
    }
}

class BluetoothViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var devices: [BluetoothDevice] = []
    @Published var isBluetoothPoweredOn = false
    @Published var errorMessage: String? = nil
    @Published var connectedDevice: BluetoothDevice? = nil
    @Published var receivedData: String = ""
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var latestWeightData: WeightData? = nil
    @Published var recentRecords: [WeightRecord] = []
    @Published var drinkRecords: [DrinkRecord] = []  // 喝水记录
    
    // 喝水统计
    @Published var todayDrinkCount: Int = 0
    @Published var todayDrinkTotal: Int = 0  // 单位：克
    @Published var weeklyAverage: Int = 0   // 单位：克
    @Published var weeklyDrinkData: [Int] = Array(repeating: 0, count: 7) // 过去7天的每日喝水量
    
    // 恢复原有的蓝牙管理器
    private var centralManager: CBCentralManager!
    private var foundPeripherals: [CBPeripheral] = []
    private var targetServiceUUID = CBUUID(string: "FFE0")
    private var characteristicUUID = CBUUID(string: "FFE1")
    private var jsonBuffer = ""
    private var lastStableObject: String? = nil
    private var persistenceController = PersistenceController.shared
    
    // 杯子重量相关
    private var lastValidWeight: Int? = nil // 上次有效的重量记录

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("蓝牙状态更新: \(central.state.rawValue)")
        switch central.state {
        case .poweredOn:
            print("蓝牙已开启")
            isBluetoothPoweredOn = true
            errorMessage = nil
        case .poweredOff:
            print("蓝牙已关闭")
            isBluetoothPoweredOn = false
            errorMessage = "蓝牙已关闭，请打开蓝牙"
        case .resetting:
            print("蓝牙正在重置")
            isBluetoothPoweredOn = false
            errorMessage = "蓝牙正在重置"
        case .unauthorized:
            print("蓝牙权限未授权")
            isBluetoothPoweredOn = false
            errorMessage = "蓝牙权限未授权"
        case .unknown:
            print("蓝牙状态未知")
            isBluetoothPoweredOn = false
            errorMessage = "蓝牙状态未知"
        case .unsupported:
            print("设备不支持蓝牙")
            isBluetoothPoweredOn = false
            errorMessage = "设备不支持蓝牙"
        @unknown default:
            print("未知蓝牙状态")
            isBluetoothPoweredOn = false
            errorMessage = "未知蓝牙状态"
        }
    }

    func startScan() {
        guard isBluetoothPoweredOn else {
            errorMessage = "蓝牙未开启，无法扫描"
            return
        }
        
        devices.removeAll()
        foundPeripherals.removeAll()
        errorMessage = nil
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    // 自动连接HC-08
    func autoConnectToHC08() {
        guard isBluetoothPoweredOn else {
            errorMessage = "蓝牙未开启"
            return
        }
        
        isConnecting = true
        errorMessage = "正在搜索 HC-08..."
        
        devices.removeAll()
        foundPeripherals.removeAll()
        
        // 扫描设备，寻找HC-08
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        // 设置超时，10秒后停止扫描
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isConnecting {
                self.centralManager.stopScan()
                self.isConnecting = false
                self.errorMessage = "找不到 HC-08，请开启客户端"
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard !foundPeripherals.contains(peripheral) else { return }
        foundPeripherals.append(peripheral)
        let name = peripheral.name ?? "未知设备"
        let device = BluetoothDevice(name: name, peripheral: peripheral)
        DispatchQueue.main.async {
            self.devices.append(device)
            
            // 如果正在自动连接且找到HC-08，立即连接
            if self.isConnecting && name == "HC-08" {
                self.centralManager.stopScan()
                self.connectToDevice(device)
            }
        }
    }
    
    // 连接设备
    func connectToDevice(_ device: BluetoothDevice) {
        centralManager.stopScan()
        if let peripheral = device.peripheral {
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
            errorMessage = "正在连接..."
            isConnecting = true
        } else {
            errorMessage = "设备连接信息无效"
        }
    }
    
    // 断开连接
    func disconnect() {
        if let peripheral = connectedDevice?.peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    // 连接成功
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("连接成功: \(peripheral.name ?? "未知设备")")
        peripheral.discoverServices([targetServiceUUID])
        DispatchQueue.main.async {
            self.connectedDevice = self.devices.first { device in
                device.peripheral == peripheral
            }
            self.isConnected = true
            self.isConnecting = false
            self.errorMessage = "连接成功"
        }
    }
    
    // 连接失败
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("连接失败: \(error?.localizedDescription ?? "未知错误")")
        DispatchQueue.main.async {
            self.isConnecting = false
            self.errorMessage = "连接失败: \(error?.localizedDescription ?? "未知错误")"
        }
    }
    
    // 断开连接
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("断开连接")
        DispatchQueue.main.async {
            self.connectedDevice = nil
            self.isConnected = false
            self.isConnecting = false
            self.receivedData = ""
            if let error = error {
                self.errorMessage = "断开连接: \(error.localizedDescription)"
            } else {
                self.errorMessage = "已断开连接"
            }
        }
    }
    
    // 发现服务
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("发现服务错误: \(error.localizedDescription)")
            return
        }
        
        if let services = peripheral.services {
            for service in services {
                print("发现服务: \(service.uuid)")
                if service.uuid == targetServiceUUID {
                    peripheral.discoverCharacteristics([characteristicUUID], for: service)
                }
            }
        }
    }
    
    // 发现特征
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("发现特征错误: \(error.localizedDescription)")
            return
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                print("发现特征: \(characteristic.uuid)")
                if characteristic.uuid == characteristicUUID {
                    // 订阅特征以接收数据
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("已订阅特征接收数据")
                }
            }
        }
    }
    
    // 接收数据
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("接收数据错误: \(error.localizedDescription)")
            return
        }
        
        if let jsonData = characteristic.value, let string = String(data: jsonData, encoding: .utf8) {
            print("收到数据: \(string)")
            DispatchQueue.main.async {
                // 更新接收到的数据显示
                let lines = self.receivedData.split(separator: "\n").suffix(5)
                self.receivedData = lines.joined(separator: "\n") + "\n" + string
                
                // 处理Arduino发送的文本格式数据
                self.processArduinoData(string)
            }
        }
    }
    
    // 处理Arduino发送的数据
    private func processArduinoData(_ data: String) {
        print("处理Arduino数据: \(data)")
        
        // 将接收到的字符串添加到缓冲区
        jsonBuffer += data
        
        // 限制缓冲区大小，防止内存问题
        if jsonBuffer.count > 2000 {
            print("缓冲区过大，清空缓冲区")
            jsonBuffer = ""
            return
        }
        
        // 尝试从缓冲区中查找完整的数据块
        // Arduino发送格式：
        // ================
        // Weight: 100 g
        // Status: Stable
        // Object: Detected
        // Time: 800 s
        // System Running
        // ================
        
        // 查找完整的数据块（以===============开始和结束）
        let separator = "==============="
        let parts = jsonBuffer.components(separatedBy: separator)
        
        // 处理完整的数据块（至少3个部分：前缀、数据、后缀）
        if parts.count >= 3 {
            for i in 1..<parts.count-1 {
                let dataBlock = parts[i].trimmingCharacters(in: .whitespacesAndNewlines)
                if !dataBlock.isEmpty {
                    parseDataBlock(dataBlock)
                }
            }
            
            // 保留最后一个不完整的数据块
            jsonBuffer = separator + parts.last!
        }
    }
    
    // 解析单个数据块
    private func parseDataBlock(_ dataBlock: String) {
        print("解析数据块: \(dataBlock)")
        
        let lines = dataBlock.components(separatedBy: .newlines)
        var weight: Int?
        var status: String?
        var object: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine.hasPrefix("Weight:") {
                let components = trimmedLine.components(separatedBy: " ")
                if components.count >= 2 {
                    weight = Int(components[1])
                }
            } else if trimmedLine.hasPrefix("Status:") {
                let components = trimmedLine.components(separatedBy: " ")
                if components.count >= 2 {
                    status = components[1]
                }
            } else if trimmedLine.hasPrefix("Object:") {
                let components = trimmedLine.components(separatedBy: " ")
                if components.count >= 2 {
                    object = components[1]
                }
            }
        }
        
        // 如果解析到完整的数据，创建WeightData
        if let weight = weight, let status = status, let object = object {
            let weightData = WeightData(weight: weight, status: status, object: object, time: 0, system: "Arduino")
            latestWeightData = weightData
            
            print("解析成功: weight=\(weight), status=\(status), object=\(object)")
            
            // 只记录stable状态且第一次的数据，并且重量要大于10g
            if status == "Stable" && lastStableObject != object && weight >= 10 {
                print("保存记录: 符合条件，开始保存")
                saveWeightRecord(weight: weight, status: status, object: object)
                lastStableObject = object
                print("保存记录: 完成，开始加载记录")
                loadRecentRecords()
                print("保存记录: 开始计算统计")
                calculateDrinkStatistics()
                print("保存记录: 全部完成")
            } else if status != "Stable" {
                // 如果状态不是stable，重置lastStableObject
                print("重置状态: 状态不是Stable")
                lastStableObject = nil
            } else {
                print("跳过记录: 不满足保存条件")
            }
        } else {
            print("数据不完整，跳过: weight=\(weight?.description ?? "nil"), status=\(status ?? "nil"), object=\(object ?? "nil")")
        }
    }
    
    // 保存重量记录到数据库
    private func saveWeightRecord(weight: Int, status: String, object: String) {
        let context = persistenceController.container.viewContext
        let weightRecord = WeightRecord(context: context)
        
        // 直接保存原始重量
        weightRecord.weight = Int32(weight)
        weightRecord.status = status
        weightRecord.object = object
        weightRecord.timestamp = Date() // 使用手机当前时间
        
        do {
            try context.save()
            print("重量记录已保存: 重量=\(weight)g, status=\(status), object=\(object)")
        } catch {
            print("保存重量记录失败: \(error.localizedDescription)")
        }
    }
    
    // 加载最近的记录
    func loadRecentRecords() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<WeightRecord> = WeightRecord.fetchRequest()
        request.predicate = NSPredicate(format: "isRemoved == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.timestamp, ascending: false)]
        request.fetchLimit = 3
        
        do {
            let records = try context.fetch(request)
            DispatchQueue.main.async {
                self.recentRecords = records
            }
        } catch {
            print("加载记录失败: \(error.localizedDescription)")
        }
    }
    
    // 计算喝水统计
    func calculateDrinkStatistics() {
        print("开始计算喝水统计")
        let context = persistenceController.container.viewContext
        
        // 计算今天的喝水统计
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let todayRequest: NSFetchRequest<WeightRecord> = WeightRecord.fetchRequest()
        todayRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@ AND isRemoved == NO", today as NSDate, tomorrow as NSDate)
        todayRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.timestamp, ascending: true)]
        
        do {
            let todayRecords = try context.fetch(todayRequest)
            
            // 计算今天的喝水次数和总量（数据库中存储的是原始重量）
            var drinkCount = 0
            var totalDrinkAmount = 0
            var todayDrinkRecords: [DrinkRecord] = []
            
            if todayRecords.count > 1 {
                for i in 1..<todayRecords.count {
                    let previousWeight = Int(todayRecords[i-1].weight)
                    let currentWeight = Int(todayRecords[i].weight)
                    let weightDifference = previousWeight - currentWeight
                    
                    // 只有当重量减少（喝水）且差值大于5g时才计算
                    // 过滤掉小的波动，至少减少5g才算喝水
                    if weightDifference >= 5 {
                        drinkCount += 1
                        totalDrinkAmount += weightDifference
                        
                        // 创建喝水记录
                        let drinkRecord = DrinkRecord(
                            beforeWeight: previousWeight,
                            afterWeight: currentWeight,
                            drinkAmount: weightDifference,
                            timestamp: todayRecords[i].timestamp ?? Date(),
                            beforeRecord: todayRecords[i-1],
                            afterRecord: todayRecords[i]
                        )
                        todayDrinkRecords.append(drinkRecord)
                    }
                }
            }
            
            // 计算过去7天的每日喝水量
            var weeklyDrinkData: [Int] = Array(repeating: 0, count: 7)
            let calendar = Calendar.current
            
            for dayOffset in 0..<7 {
                let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
                let targetStart = calendar.startOfDay(for: targetDate)
                let targetEnd = calendar.date(byAdding: .day, value: 1, to: targetStart)!
                
                let dayRequest: NSFetchRequest<WeightRecord> = WeightRecord.fetchRequest()
                dayRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@ AND isRemoved == NO", targetStart as NSDate, targetEnd as NSDate)
                dayRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.timestamp, ascending: true)]
                
                let dayRecords = try context.fetch(dayRequest)
                var dayDrinkTotal = 0
                
                if dayRecords.count > 1 {
                    for i in 1..<dayRecords.count {
                        let previousWeight = Int(dayRecords[i-1].weight)
                        let currentWeight = Int(dayRecords[i].weight)
                        let weightDifference = previousWeight - currentWeight
                        
                        // 只计算重量下降的差值（喝水）
                        if weightDifference >= 5 {
                            dayDrinkTotal += weightDifference
                        }
                    }
                }
                
                // 数组索引：0=今天，1=昨天，...，6=6天前
                weeklyDrinkData[dayOffset] = dayDrinkTotal
            }
            
            // 计算7日平均（过去6天 + 今天）
            let weeklyTotal = weeklyDrinkData.reduce(0, +)
            let weeklyAverage = weeklyTotal / 7
            
            DispatchQueue.main.async {
                print("统计计算完成: 今天喝水次数=\(drinkCount), 总量=\(totalDrinkAmount)g, 本周平均=\(weeklyAverage)g")
                self.todayDrinkCount = drinkCount
                self.todayDrinkTotal = totalDrinkAmount
                self.weeklyAverage = weeklyAverage
                self.weeklyDrinkData = weeklyDrinkData
                self.drinkRecords = todayDrinkRecords.reversed() // 最新的在前面
            }
            
        } catch {
            print("计算喝水统计失败: \(error.localizedDescription)")
        }
    }
    
    // 删除喝水记录
    func deleteDrinkRecord(_ drinkRecord: DrinkRecord) {
        let context = persistenceController.container.viewContext
        
        // 标记相关的WeightRecord为已删除（软删除）
        drinkRecord.beforeRecord.isRemoved = true
        drinkRecord.afterRecord.isRemoved = true
        
        do {
            try context.save()
            print("喝水记录已删除")
            // 重新计算统计
            self.calculateDrinkStatistics()
        } catch {
            print("删除喝水记录失败: \(error.localizedDescription)")
        }
    }
    
    // 删除异常的重量记录（用于删除95g等异常数据）
    func deleteAbnormalWeightRecords(targetWeight: Int) {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<WeightRecord> = WeightRecord.fetchRequest()
        request.predicate = NSPredicate(format: "weight == %d AND isRemoved == NO", Int32(targetWeight))
        
        do {
            let records = try context.fetch(request)
            for record in records {
                record.isRemoved = true
                print("标记删除异常记录: 重量=\(record.weight)g, 时间=\(record.timestamp ?? Date())")
            }
            
            try context.save()
            print("已删除 \(records.count) 条重量为 \(targetWeight)g 的异常记录")
            
            // 重新加载数据
            self.loadRecentRecords()
            self.calculateDrinkStatistics()
        } catch {
            print("删除异常重量记录失败: \(error.localizedDescription)")
        }
    }
    
    // 获取所有重量记录（用于调试）
    func getAllWeightRecords() -> [WeightRecord] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<WeightRecord> = WeightRecord.fetchRequest()
        request.predicate = NSPredicate(format: "isRemoved == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("获取重量记录失败: \(error.localizedDescription)")
            return []
        }
    }
}