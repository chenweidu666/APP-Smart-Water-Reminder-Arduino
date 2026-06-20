//
//  ContentView.swift
//  hx711_oled_hc08_weight_monitor_ios
//
//  Created by 陈纬 on 2025/9/20.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @StateObject private var btVM = BluetoothViewModel()
    
    @State private var showConfirmationDialog = false
    @State private var selectedDevice: BluetoothDevice? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                // 蓝牙状态指示器
                HStack {
                    Image(systemName: btVM.isBluetoothPoweredOn ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(btVM.isBluetoothPoweredOn ? .blue : .red)
                    Text(btVM.isBluetoothPoweredOn ? "蓝牙已开启" : "蓝牙未开启")
                        .foregroundColor(btVM.isBluetoothPoweredOn ? .blue : .red)
                }
                .padding()
                
                // 错误消息显示
                if let errorMessage = btVM.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                
                // 控制按钮
                Button(action: {
                    btVM.startScan()
                }) {
                    Text("搜索设备")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(btVM.isBluetoothPoweredOn ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!btVM.isBluetoothPoweredOn)
                .padding(.horizontal)
                
                // 设备列表
                List(btVM.devices) { device in
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(device.name)
                                .font(.body)
                            if let connectedDevice = btVM.connectedDevice, connectedDevice.id == device.id {
                                Text("已连接")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !btVM.isConnected || btVM.connectedDevice?.id != device.id {
                            selectedDevice = device
                            showConfirmationDialog = true
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("蓝牙设备")
            .confirmationDialog("确认连接", isPresented: $showConfirmationDialog, presenting: selectedDevice) { device in
                Button("确认连接") {
                    btVM.connectToDevice(device)
                }
                Button("取消", role: .cancel) {}
            } message: { device in
                Text("确定要连接到 \(device.name) 吗？")
            }
            .fullScreenCover(isPresented: $btVM.isConnected) {
                ConnectedView()
                    .environmentObject(btVM)
            }
        }
    }
}

#Preview {
    ContentView()
}
