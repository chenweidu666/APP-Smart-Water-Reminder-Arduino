import SwiftUI

struct ConnectedView: View {
    @StateObject private var btVM = BluetoothViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                // 连接状态和操作按钮
                VStack(spacing: 16) {
                    if btVM.isConnected {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("已连接: \(btVM.connectedDevice?.name ?? "未知设备")")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Text("状态: 数据接收中")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                btVM.disconnect()
                            }) {
                                Text("断开连接")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            if btVM.isBluetoothPoweredOn {
                                Button(action: {
                                    btVM.autoConnectToHC08()
                                }) {
                                    Text("连接 HC-08")
                                        .font(.headline)
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .disabled(btVM.isConnecting)
                            } else {
                                Text("蓝牙未开启，请开启蓝牙")
                                    .foregroundColor(.red)
                                    .padding()
                            }
                            
                            if let errorMessage = btVM.errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
                .padding()
                
                
                // 解析后的数据表格
                VStack(alignment: .leading) {
                    Text("当前数据:")
                        .font(.headline)
                        .padding(.top)
                    
                    if let weightData = btVM.latestWeightData {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("重量")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(weightData.weight)g")
                                    .fontWeight(.bold)
                                    .font(.title2)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack(alignment: .leading) {
                                Text("状态")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(weightData.status)
                                    .fontWeight(.bold)
                                    .font(.title2)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack(alignment: .leading) {
                                Text("物体")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(weightData.object)
                                    .fontWeight(.bold)
                                    .font(.title2)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        Text("等待数据...")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .padding()
                
                // 数据库记录显示
                VStack(alignment: .leading) {
                    Text("最近的记录:")
                        .font(.headline)
                        .padding(.top)
                    
                    if btVM.recentRecords.isEmpty {
                        Text("暂无记录")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(btVM.recentRecords) { record in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("重量: \(record.weight)g")
                                        .fontWeight(.bold)
                                    Text("物体: \(record.object ?? "")")
                                    Text("状态: \(record.status ?? "")")
                                    Text("时间: \(formatDate(record.timestamp))")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                }
            }
            .navigationTitle("HC-08 重量监测")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                btVM.loadRecentRecords()
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "未知时间" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    ConnectedView()
}
