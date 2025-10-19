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
    
    // 使用新的串口蓝牙管理器
    private var serialBluetoothManager = SerialBluetoothManager()
    private var jsonBuffer = ""
    private var lastStableObject: String? = nil
    private var persistenceController = PersistenceController.shared
    
    // 杯子重量相关
    private var lastValidWeight: Int? = nil // 上次有效的重量记录
    
    override init() {
        super.init()
        setupSerialBluetoothManager()
    }
    
    private func setupSerialBluetoothManager() {
        // 监听串口蓝牙管理器的状态变化
        serialBluetoothManager.$isConnected
            .assign(to: &$isConnected)
        
        serialBluetoothManager.$receivedData
            .sink { [weak self] data in
                self?.processReceivedData(data)
            }
            .store(in: &cancellables)
        
        serialBluetoothManager.$errorMessage
            .assign(to: &$errorMessage)
        
        serialBluetoothManager.$connectedDeviceName
            .sink { [weak self] deviceName in
                if let name = deviceName {
                    self?.connectedDevice = BluetoothDevice(name: name)
                } else {
                    self?.connectedDevice = nil
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
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
        errorMessage = nil
        serialBluetoothManager.startScan()
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
        serialBluetoothManager.startScan()
        
        // 设置超时，10秒后停止扫描
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isConnecting {
                self.serialBluetoothManager.stopScan()
                self.isConnecting = false
                self.errorMessage = "找不到 HC-08，请开启客户端"
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard !devices.contains(where: { $0.peripheral == peripheral }) else { return }
        let name = peripheral.name ?? "未知设备"
        let device = BluetoothDevice(name: name, peripheral: peripheral)
        DispatchQueue.main.async {
            self.devices.append(device)
            
            // 如果正在自动连接且找到HC-08，立即连接
            if self.isConnecting && name == "HC-08" {
                self.serialBluetoothManager.stopScan()
                self.serialBluetoothManager.connect(to: peripheral)
            }
        }
    }
    
    // 连接设备
    func connectToDevice(_ device: BluetoothDevice) {
        serialBluetoothManager.stopScan()
        serialBluetoothManager.connect(to: device.peripheral)
        errorMessage = "正在连接..."
        isConnecting = true
    }
    
    // 断开连接
    func disconnect() {
        serialBluetoothManager.disconnect()
    }
    
    // 连接成功
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("连接成功: \(peripheral.name ?? "未知设备")")
        DispatchQueue.main.async {
            self.connectedDevice = self.devices.first { $0.peripheral == peripheral }
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
                peripheral.discoverCharacteristics(nil, for: service)
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
                // 订阅特征以接收数据
                peripheral.setNotifyValue(true, for: characteristic)
                print("已订阅特征接收数据")
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
                
                // 将接收到的字符串添加到缓冲区
                self.jsonBuffer += string
                
                // 限制缓冲区大小，防止内存问题
                if self.jsonBuffer.count > 1000 {
                    print("缓冲区过大，清空缓冲区")
                    self.jsonBuffer = ""
                }
                
                // 尝试从缓冲区中查找完整的JSON对象
                if let firstBrace = self.jsonBuffer.firstIndex(of: "{"),
                   let lastBrace = self.jsonBuffer.lastIndex(of: "}"),
                   firstBrace <= lastBrace {
                    
                    // 使用更安全的方式提取JSON字符串
                    let jsonString = String(self.jsonBuffer[firstBrace...lastBrace])
                    print("提取的JSON字符串: \(jsonString)")
                    
                    // 尝试解析JSON
                    if let jsonData = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                       let weight = json["weight"] as? Int,
                       let status = json["status"] as? String,
                       let object = json["object"] as? String,
                       let system = json["system"] as? String {
                        
                        let weightData = WeightData(weight: weight, status: status, object: object, time: 0, system: system)
                        self.latestWeightData = weightData
                        
                        // 只记录stable状态且第一次的数据，并且重量要大于10g
                        print("数据处理: weight=\(weight), status=\(status), object=\(object), lastStableObject=\(self.lastStableObject ?? "nil"), threshold=10")
                        
                        if status == "Stable" && self.lastStableObject != object && weight >= 10 {
                            print("保存记录: 符合条件，开始保存")
                            self.saveWeightRecord(weight: weight, status: status, object: object)
                            self.lastStableObject = object
                            print("保存记录: 完成，开始加载记录")
                            self.loadRecentRecords()
                            print("保存记录: 开始计算统计")
                            self.calculateDrinkStatistics()
                            print("保存记录: 全部完成")
                        } else if status != "Stable" {
                            // 如果状态不是stable，重置lastStableObject
                            print("重置状态: 状态不是Stable")
                            self.lastStableObject = nil
                        } else {
                            print("跳过记录: 不满足保存条件")
                        }
                        
                        // 清除已解析的JSON部分
                        self.jsonBuffer.removeSubrange(firstBrace...lastBrace)
                        print("清除JSON部分，剩余缓冲区长度: \(self.jsonBuffer.count)")
                    }
                }
            }
        }
    }
    
    // 处理串口接收到的数据
    private func processReceivedData(_ data: String) {
        print("处理串口数据: \(data)")
        
        // 将接收到的字符串添加到缓冲区
        jsonBuffer += data
        
        // 限制缓冲区大小，防止内存问题
        if jsonBuffer.count > 1000 {
            print("缓冲区过大，清空缓冲区")
            jsonBuffer = ""
        }
        
        // 尝试解析Arduino发送的数据格式
        // Arduino发送格式示例：
        // Weight: 100 g
        // Status: Stable
        // Object: Detected
        
        let lines = data.components(separatedBy: .newlines)
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
            
            print("解析数据: weight=\(weight), status=\(status), object=\(object)")
            
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