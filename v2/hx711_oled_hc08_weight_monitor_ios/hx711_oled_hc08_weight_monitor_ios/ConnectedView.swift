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
                
                // 喝水统计
                VStack(alignment: .leading) {
                    Text("喝水统计:")
                        .font(.headline)
                        .padding(.top)
                    
                    // 今天统计
                    HStack {
                        VStack(alignment: .leading) {
                            Text("今天喝水次数")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(btVM.todayDrinkCount) 次")
                                .fontWeight(.bold)
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(alignment: .leading) {
                            Text("今天喝水总量")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(btVM.todayDrinkTotal) g")
                                .fontWeight(.bold)
                                .font(.title3)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(alignment: .leading) {
                            Text("7日平均")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(btVM.weeklyAverage) g")
                                .fontWeight(.bold)
                                .font(.title3)
                                .foregroundColor(.orange)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    // 过去7天喝水量表格
                    VStack(spacing: 8) {
                        Text("过去7天喝水量")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        // 表头：日期
                        HStack {
                            ForEach((0..<7).reversed(), id: \.self) { index in
                                Text(formatWeekDay(index))
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(index == 0 ? .green : .gray)
                            }
                        }
                        
                        // 数据行：喝水量
                        HStack {
                            ForEach((0..<7).reversed(), id: \.self) { index in
                                VStack {
                                    Text("\(btVM.weeklyDrinkData[index])g")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(btVM.weeklyDrinkData[index] > 0 ? .primary : .gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(btVM.weeklyDrinkData[index] > 0 ? Color.green.opacity(0.1) : Color.gray.opacity(0.05))
                                .cornerRadius(4)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
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
                        // 表头
                        HStack {
                            Text("喝水前")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                            Text("喝水后")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                            Text("喝水量")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                            Text("时间")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                            Text("操作")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        
                        // 数据行
                        ForEach(btVM.drinkRecords) { record in
                            HStack {
                                Text("\(record.beforeWeight + btVM.cupWeight)g")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                
                                Text("\(record.afterWeight + btVM.cupWeight)g")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .frame(maxWidth: .infinity)
                                
                                Text("\(record.drinkAmount)g")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                
                                Text(formatTime(record.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                
                                Button(action: {
                                    btVM.deleteDrinkRecord(record)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(4)
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
    
    private func formatWeekDay(_ dayOffset: Int) -> String {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "M.d"
        return formatter.string(from: targetDate)
    }
}

#Preview {
    ConnectedView()
}
