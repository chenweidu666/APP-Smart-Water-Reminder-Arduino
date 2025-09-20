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
    var body: some View {
        NavigationView {
            VStack {
                // 蓝牙状态指示器
                HStack {
                    Image(systemName: btVM.isBluetoothPoweredOn ? "bluetooth" : "bluetooth.slash")
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
                
                Button(action: {
                    btVM.startScan()
                }) {
                    Text("搜索蓝牙设备")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(btVM.isBluetoothPoweredOn ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!btVM.isBluetoothPoweredOn)
                
                List(btVM.devices) { device in
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(device.name)
                                .font(.body)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("蓝牙设备")
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
