import Foundation
import CoreBluetooth
import SwiftUI
import Combine

// 经典蓝牙串口通信管理器
class SerialBluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var receivedData = ""
    @Published var errorMessage: String?
    @Published var connectedDeviceName: String?
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var serialService: CBService?
    private var serialCharacteristic: CBCharacteristic?
    
    // HC-08 经典蓝牙配置
    private let serviceUUID = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB") // Serial Port Profile
    private let characteristicUUID = CBUUID(string: "00001101-0000-1000-8000-00805F9B34FB")
    
    // 数据缓冲区
    private var dataBuffer = ""
    private var lastDataTime = Date()
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("蓝牙已开启")
            errorMessage = nil
        case .poweredOff:
            print("蓝牙已关闭")
            errorMessage = "蓝牙已关闭，请打开蓝牙"
            disconnect()
        case .resetting:
            print("蓝牙正在重置")
            errorMessage = "蓝牙正在重置"
        case .unauthorized:
            print("蓝牙权限未授权")
            errorMessage = "蓝牙权限未授权"
        case .unsupported:
            print("设备不支持蓝牙")
            errorMessage = "设备不支持蓝牙"
        case .unknown:
            print("蓝牙状态未知")
            errorMessage = "蓝牙状态未知"
        @unknown default:
            print("未知蓝牙状态")
            errorMessage = "未知蓝牙状态"
        }
    }
    
    // MARK: - 连接管理
    
    func startScan() {
        guard centralManager.state == .poweredOn else {
            errorMessage = "蓝牙未开启"
            return
        }
        
        isScanning = true
        errorMessage = nil
        
        // 扫描经典蓝牙设备
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        // 10秒后停止扫描
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isScanning {
                self.stopScan()
                if !self.isConnected {
                    self.errorMessage = "未找到HC-08设备"
                }
            }
        }
    }
    
    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScan()
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        serialService = nil
        serialCharacteristic = nil
        isConnected = false
        connectedDeviceName = nil
        receivedData = ""
        dataBuffer = ""
    }
    
    // MARK: - 数据发送
    
    func sendData(_ data: String) {
        guard let characteristic = serialCharacteristic,
              let peripheral = connectedPeripheral,
              isConnected else {
            print("无法发送数据：未连接")
            return
        }
        
        if let dataToSend = data.data(using: .utf8) {
            peripheral.writeValue(dataToSend, for: characteristic, type: .withResponse)
            print("发送数据: \(data)")
        }
    }
    
    // MARK: - 发现设备
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("发现设备: \(peripheral.name ?? "未知设备")")
        
        // 自动连接HC-08设备
        if peripheral.name == "HC-08" {
            connect(to: peripheral)
        }
    }
    
    // MARK: - 连接状态
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("连接成功: \(peripheral.name ?? "未知设备")")
        isConnected = true
        connectedDeviceName = peripheral.name
        errorMessage = nil
        
        // 发现服务
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("连接失败: \(error?.localizedDescription ?? "未知错误")")
        errorMessage = "连接失败: \(error?.localizedDescription ?? "未知错误")"
        isConnected = false
        connectedDeviceName = nil
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("断开连接: \(error?.localizedDescription ?? "正常断开")")
        isConnected = false
        connectedDeviceName = nil
        receivedData = ""
        dataBuffer = ""
        
        if let error = error {
            errorMessage = "连接断开: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 服务发现
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("发现服务失败: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("发现服务: \(service.uuid)")
            if service.uuid == serviceUUID {
                serialService = service
                peripheral.discoverCharacteristics([characteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("发现特征失败: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print("发现特征: \(characteristic.uuid)")
            if characteristic.uuid == characteristicUUID {
                serialCharacteristic = characteristic
                
                // 订阅特征以接收数据
                peripheral.setNotifyValue(true, for: characteristic)
                print("已订阅数据接收")
            }
        }
    }
    
    // MARK: - 数据接收
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("接收数据失败: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value,
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        
        print("收到数据: \(string)")
        
        DispatchQueue.main.async {
            self.dataBuffer += string
            self.lastDataTime = Date()
            
            // 处理完整的数据行
            self.processReceivedData()
        }
    }
    
    private func processReceivedData() {
        // 按行分割数据
        let lines = dataBuffer.components(separatedBy: .newlines)
        
        // 保留最后一行（可能不完整）
        if lines.count > 1 {
            let completeLines = Array(lines.dropLast())
            dataBuffer = lines.last ?? ""
            
            // 处理完整的行
            for line in completeLines {
                if !line.isEmpty {
                    receivedData = line
                    print("处理数据行: \(line)")
                }
            }
        }
        
        // 限制缓冲区大小
        if dataBuffer.count > 1000 {
            dataBuffer = String(dataBuffer.suffix(500))
        }
    }
}
