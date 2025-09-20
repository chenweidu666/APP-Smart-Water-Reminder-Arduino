import SwiftUI

struct ConnectedView: View {
    @EnvironmentObject var btVM: BluetoothViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                // 连接状态和断开按钮
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
                .padding()
                
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
                    .frame(maxHeight: 300)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("数据接收")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ConnectedView()
        .environmentObject(BluetoothViewModel())
}
