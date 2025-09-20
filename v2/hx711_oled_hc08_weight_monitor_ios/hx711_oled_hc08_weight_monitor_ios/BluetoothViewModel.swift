import Foundation
import CoreBluetooth
import SwiftUI
import Combine

struct BluetoothDevice: Identifiable {
    let id = UUID()
    let name: String
    let peripheral: CBPeripheral
}

class BluetoothViewModel: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var devices: [BluetoothDevice] = []
    @Published var isBluetoothPoweredOn = false
    @Published var errorMessage: String? = nil
    
    private var centralManager: CBCentralManager!
    private var foundPeripherals: [CBPeripheral] = []

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
}
