# HC-08 重量监测 iOS 应用

这是一个用于监测HX711重量传感器数据的iOS应用，通过HC-08蓝牙模块与Arduino进行通信。

## 项目结构

```
ios_app/
├── Sources/                          # 源代码目录
│   └── hx711_oled_hc08_weight_monitor_iosApp.swift  # 应用入口
├── Models/                          # 数据模型
│   ├── PersistenceController.swift  # CoreData控制器
│   └── WeightMonitor.xcdatamodeld/  # CoreData模型
├── ViewModels/                      # 视图模型
│   └── BluetoothViewModel.swift     # 蓝牙通信视图模型
├── Views/                           # 用户界面
│   ├── ConnectedView.swift         # 主界面
│   └── ContentView.swift           # 内容视图
├── Assets.xcassets/                 # 应用资源
└── hx711_oled_hc08_weight_monitor_ios.xcodeproj/  # Xcode项目文件
```

## 功能特性

- **蓝牙连接**: 自动连接HC-08蓝牙模块
- **实时数据**: 接收并显示Arduino发送的重量数据
- **数据存储**: 使用CoreData持久化存储重量记录
- **喝水统计**: 计算每日喝水量和统计信息
- **数据管理**: 支持删除异常记录和查看历史数据

## 硬件要求

- Arduino Uno + HX711重量传感器
- HC-08蓝牙模块
- OLED显示屏（可选）

## 使用方法

1. 确保Arduino设备已连接并运行
2. 打开iOS应用
3. 点击"连接 HC-08"按钮
4. 应用将自动连接并开始接收数据

## 数据格式

Arduino发送的数据格式：
```
===============
Weight: 100 g
Status: Stable
Object: Detected
Time: 800 s
System Running
===============
```

## 技术栈

- SwiftUI
- CoreBluetooth
- CoreData
- Combine
