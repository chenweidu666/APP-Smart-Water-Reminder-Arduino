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
                
                /*
                // 接收到的数据
                VStack(alignment: .leading) {
                    Text("接收到的数据:")
                        .font(.headline)
                        .padding(.top)
                    
                    ScrollView {
                        Text(btVM.receivedData)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 200)
                }
                .padding()
                */
                
                // 杯子重量设置
                VStack(alignment: .leading) {
                    Text("杯子重量设置:")
                        .font(.headline)
                        .padding(.top)
                    
                    VStack(spacing: 12) {
                        // 杯子重量配置
                        HStack {
                            Text("杯子重量:")
                                .font(.body)
                            Spacer()
                            HStack {
                                Button("-") {
                                    if btVM.cupWeight > 50 {
                                        btVM.cupWeight -= 10
                                    }
                                }
                                .frame(width: 30, height: 30)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(5)
                                
                                Text("\(btVM.cupWeight)g")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .frame(minWidth: 60)
                                
                                Button("+") {
                                    if btVM.cupWeight < 500 {
                                        btVM.cupWeight += 10
                                    }
                                }
                                .frame(width: 30, height: 30)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(5)
                            }
                        }
                        
                        // 显示阈值信息
                        HStack {
                            VStack(alignment: .leading) {
                                Text("存储阈值")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(Int(Double(btVM.cupWeight) * 0.9))g")
                                    .fontWeight(.bold)
                                    .font(.title3)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack(alignment: .leading) {
                                Text("喝水阈值")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("0g")
                                    .fontWeight(.bold)
                                    .font(.title3)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack(alignment: .leading) {
                                Text("存储内容")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("水的重量")
                                    .fontWeight(.bold)
                                    .font(.title3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
                
                // 当天喝水统计
                VStack(alignment: .leading) {
                    Text("今天喝水统计:")
                        .font(.headline)
                        .padding(.top)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("喝水次数")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(btVM.todayDrinkCount) 次")
                                .fontWeight(.bold)
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(alignment: .leading) {
                            Text("喝水总量")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(btVM.todayDrinkTotal) g")
                                .fontWeight(.bold)
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(alignment: .leading) {
                            Text("本周平均")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(btVM.weeklyAverage) g")
                                .fontWeight(.bold)
                                .font(.title2)
                                .foregroundColor(.orange)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
                
                // 当前数据
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
                
                // 喝水记录
                VStack(alignment: .leading) {
                    Text("喝水记录:")
                        .font(.headline)
                        .padding(.top)
                    
                    if btVM.drinkRecords.isEmpty {
                        Text("暂无喝水记录")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(btVM.drinkRecords) { record in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("喝水前: \(record.beforeWeight)g")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("喝水后: \(record.afterWeight)g")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text("喝水量: \(record.drinkAmount)g")
                                        .font(.body)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    Text("时间: \(formatTime(record.timestamp))")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    btVM.deleteDrinkRecord(record)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .padding(8)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                
                // 最近的记录（注释掉）
                /*
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
                */
                }
            }
            .navigationTitle("HC-08 重量监测")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                btVM.loadRecentRecords()
                btVM.calculateDrinkStatistics()
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "未知时间" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

#Preview {
    ConnectedView()
}
