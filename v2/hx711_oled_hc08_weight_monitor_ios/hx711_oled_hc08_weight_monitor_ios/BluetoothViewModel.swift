import Foundation
import CoreBluetooth
import SwiftUI
import Combine

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
    
    private var centralManager: CBCentralManager!
    private var foundPeripherals: [CBPeripheral] = []
    private var targetServiceUUID = CBUUID(string: "FFE0")
    private var characteristicUUID = CBUUID(string: "FFE1")

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

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard !foundPeripherals.contains(peripheral) else { return }
        foundPeripherals.append(peripheral)
        let name = peripheral.name ?? "未知设备"
        let device = BluetoothDevice(name: name, peripheral: peripheral)
        DispatchQueue.main.async {
            self.devices.append(device)
        }
    }
    
    // 连接设备
    func connectToDevice(_ device: BluetoothDevice) {
        centralManager.stopScan()
        device.peripheral.delegate = self
        centralManager.connect(device.peripheral, options: nil)
        errorMessage = "正在连接..."
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
            self.errorMessage = "连接成功"
        }
    }
    
    // 连接失败
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("连接失败: \(error?.localizedDescription ?? "未知错误")")
        DispatchQueue.main.async {
            self.errorMessage = "连接失败: \(error?.localizedDescription ?? "未知错误")"
        }
    }
    
    // 断开连接
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("断开连接")
        DispatchQueue.main.async {
            self.connectedDevice = nil
            self.isConnected = false
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
        
        if let data = characteristic.value, let string = String(data: data, encoding: .utf8) {
            print("收到数据: \(string)")
            DispatchQueue.main.async {
                let lines = self.receivedData.split(separator: "\n").suffix(3)
                self.receivedData = lines.joined(separator: "\n") + "\n" + string
            }
        }
    }
}
