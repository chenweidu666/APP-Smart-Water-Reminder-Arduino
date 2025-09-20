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

struct BluetoothDevice: Identifiable {
    let id = UUID()
    let name: String
    let peripheral: CBPeripheral
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
    
    // 喝水统计
    @Published var todayDrinkCount: Int = 0
    @Published var todayDrinkTotal: Int = 0  // 单位：毫升
    @Published var weeklyAverage: Int = 0   // 单位：毫升
    
    private var centralManager: CBCentralManager!
    private var foundPeripherals: [CBPeripheral] = []
    private var targetServiceUUID = CBUUID(string: "FFE0")
    private var characteristicUUID = CBUUID(string: "FFE1")
    private var jsonBuffer = ""
    private var lastStableObject: String? = nil
    private var persistenceController = PersistenceController.shared
    
    // 杯子重量相关
    private let cupWeight = 200 // 杯子重量（克）
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
        device.peripheral.delegate = self
        centralManager.connect(device.peripheral, options: nil)
        errorMessage = "正在连接..."
        isConnecting = true
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
                // 将接收到的字符串添加到缓冲区
                self.jsonBuffer += string
                
                // 尝试从缓冲区中查找完整的JSON对象
                if let jsonStart = self.jsonBuffer.range(of: "{"),
                   let jsonEnd = self.jsonBuffer.range(of: "}", options: .backwards) {
                    
                    let jsonString = String(self.jsonBuffer[jsonStart.lowerBound...jsonEnd.upperBound])
                    
                    // 尝试解析JSON
                    if let jsonData = jsonString.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                       let weight = json["weight"] as? Int,
                       let status = json["status"] as? String,
                       let object = json["object"] as? String,
                       let system = json["system"] as? String {
                        
                        let weightData = WeightData(weight: weight, status: status, object: object, time: 0, system: system)
                        self.latestWeightData = weightData
                        
                        // 只记录stable状态且第一次的数据，并且重量要大于杯子重量的90%
                        if status == "Stable" && self.lastStableObject != object && weight >= Int(Double(self.cupWeight) * 0.9) {
                            self.saveWeightRecord(weight: weight, status: status, object: object)
                            self.lastStableObject = object
                            self.loadRecentRecords()
                            self.calculateDrinkStatistics()
                        } else if status != "Stable" {
                            // 如果状态不是stable，重置lastStableObject
                            self.lastStableObject = nil
                        }
                        
                        // 清除已解析的JSON部分
                        self.jsonBuffer.removeSubrange(jsonStart.lowerBound...jsonEnd.upperBound)
                    }
                }
            }
        }
    }
    
    // 保存重量记录到数据库
    private func saveWeightRecord(weight: Int, status: String, object: String) {
        let context = persistenceController.container.viewContext
        let weightRecord = WeightRecord(context: context)
        weightRecord.weight = Int32(weight)
        weightRecord.status = status
        weightRecord.object = object
        weightRecord.timestamp = Date() // 使用手机当前时间
        
        do {
            try context.save()
            print("重量记录已保存: weight=\(weight), status=\(status), object=\(object)")
        } catch {
            print("保存重量记录失败: \(error.localizedDescription)")
        }
    }
    
    // 加载最近的记录
    func loadRecentRecords() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<WeightRecord> = WeightRecord.fetchRequest()
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
        let context = persistenceController.container.viewContext
        
        // 计算今天的喝水统计
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let todayRequest: NSFetchRequest<WeightRecord> = WeightRecord.fetchRequest()
        todayRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@", today as NSDate, tomorrow as NSDate)
        todayRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.timestamp, ascending: true)]
        
        do {
            let todayRecords = try context.fetch(todayRequest)
            
            // 计算今天的喝水次数和总量（只计算重量下降的差值）
            var drinkCount = 0
            var totalDrinkAmount = 0
            
            if todayRecords.count > 1 {
                for i in 1..<todayRecords.count {
                    let previousWeight = Int(todayRecords[i-1].weight)
                    let currentWeight = Int(todayRecords[i].weight)
                    let weightDifference = previousWeight - currentWeight
                    
                    // 只有当重量减少（喝水）且差值大于一定阈值时才计算
                    // 过滤掉小的波动，假设至少减少10g才算一次喝水
                    if weightDifference >= 10 {
                        drinkCount += 1
                        totalDrinkAmount += weightDifference
                    }
                }
            }
            
            // 计算本周平均
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
            let weeklyRequest: NSFetchRequest<WeightRecord> = WeightRecord.fetchRequest()
            weeklyRequest.predicate = NSPredicate(format: "timestamp >= %@ AND timestamp < %@", weekAgo as NSDate, tomorrow as NSDate)
            weeklyRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WeightRecord.timestamp, ascending: true)]
            
            let weeklyRecords = try context.fetch(weeklyRequest)
            var weeklyTotal = 0
            
            if weeklyRecords.count > 1 {
                for i in 1..<weeklyRecords.count {
                    let previousWeight = Int(weeklyRecords[i-1].weight)
                    let currentWeight = Int(weeklyRecords[i].weight)
                    let weightDifference = previousWeight - currentWeight
                    
                    // 只计算重量下降的差值（喝水）
                    if weightDifference >= 10 {
                        weeklyTotal += weightDifference
                    }
                }
            }
            
            let weeklyAverage = weeklyRecords.count > 0 ? weeklyTotal / 7 : 0
            
            DispatchQueue.main.async {
                self.todayDrinkCount = drinkCount
                self.todayDrinkTotal = totalDrinkAmount
                self.weeklyAverage = weeklyAverage
            }
            
        } catch {
            print("计算喝水统计失败: \(error.localizedDescription)")
        }
    }
}
