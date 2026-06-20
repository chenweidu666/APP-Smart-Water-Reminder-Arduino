# Water_X1 - 智能喝水提醒系统

基于 Arduino 的智能喝水提醒系统，使用 HX711 重量传感器、OLED 显示屏和 HC-08 蓝牙模块，配合 iOS 应用实现实时监测水杯重量变化、自动记录喝水量、统计每日饮水数据，帮助用户养成健康的喝水习惯。

## 📋 项目简介

Water_X1 是一个完整的智能喝水提醒解决方案，通过监测水杯重量变化来追踪用户的喝水行为，包含：
- **Arduino 固件**：实时监测水杯重量，OLED 显示当前状态，蓝牙传输数据
- **iOS 应用**：蓝牙连接，实时显示喝水量，历史记录管理，每日喝水统计和提醒

## 🎯 功能特性

### Arduino 端
- ✅ 实时监测水杯重量变化（HX711 传感器）
- ✅ OLED 屏幕实时显示当前重量和喝水状态
- ✅ HC-08 蓝牙模块无线传输数据到手机
- ✅ 自动判断水杯状态（稳定/不稳定）
- ✅ 检测水杯是否放置（物体检测）
- ✅ 内存优化和防闪烁显示
- ✅ 蓝牙连接状态自动检测

### iOS 应用端
- ✅ 自动搜索和连接 HC-08 蓝牙模块
- ✅ 实时接收并显示水杯重量和喝水量
- ✅ CoreData 持久化存储所有喝水记录
- ✅ 每日喝水量自动统计和可视化
- ✅ 异常数据识别和删除功能
- ✅ 历史喝水记录查看和管理
- ✅ 喝水提醒功能（可扩展）
- ✅ 现代化的 SwiftUI 界面

## 📁 项目结构

```
APP-Smart-Water-Reminder-Arduino/
├── README.md                    # 项目说明文档
├── firmware/                    # Arduino 固件 (v2 内存优化版)
│   └── hx711_oled_hc08_weight_monitor_v2.ino
└── ios/                         # iOS 应用
    ├── Sources/
    │   └── WeightMonitorApp.swift      # 应用入口
    ├── Models/
    │   ├── PersistenceController.swift # CoreData 控制器
    │   └── WeightMonitor.xcdatamodeld/ # 数据模型
    ├── ViewModels/
    │   └── BluetoothViewModel.swift    # 蓝牙通信视图模型
    ├── Views/
    │   ├── ConnectedView.swift        # 主界面
    │   └── ContentView.swift          # 内容视图
    ├── Assets.xcassets/               # 应用资源
    ├── hx711_oled_hc08_weight_monitor_ios.xcodeproj/
    └── README.md                      # iOS 应用说明
```

## 🔧 硬件要求

### 必需组件
- **Arduino Uno** 开发板
- **HX711** 重量传感器模块
- **HC-08** 蓝牙模块
- **OLED 显示屏** (128x32, SSD1306, I2C)

### 硬件连接

#### HX711 连接
- `SCK` → Arduino 引脚 `10`
- `DT` → Arduino 引脚 `11`
- `VCC` → Arduino `5V`
- `GND` → Arduino `GND`

#### OLED 连接
- `VCC` → Arduino `5V`
- `GND` → Arduino `GND`
- `SDA` → Arduino `A4` (I2C 数据线) 或 `SDA`
- `SCL` → Arduino `A5` (I2C 时钟线) 或 `SCL`

#### HC-08 连接
- `VCC` → Arduino `5V`
- `GND` → Arduino `GND`
- `TXD` → Arduino 引脚 `0` (RX)
- `RXD` → Arduino 引脚 `1` (TX)

## 📦 依赖库

### Arduino 库
在 Arduino IDE 中安装以下库：
- `Wire` (Arduino 内置)
- `Adafruit_GFX` - 图形库
- `Adafruit_SSD1306` - OLED 驱动库

安装方法：
```
工具 → 管理库 → 搜索 "Adafruit GFX" 和 "Adafruit SSD1306" → 安装
```

### iOS 依赖
- iOS 14.0+
- Xcode 12.0+
- Swift 5.0+

使用的框架：
- `SwiftUI` - 用户界面
- `CoreBluetooth` - 蓝牙通信
- `CoreData` - 数据持久化
- `Combine` - 响应式编程

## 🚀 使用方法

### 1. Arduino 固件烧录

1. 打开 Arduino IDE
2. 安装必要的库（见上方依赖库）
3. 选择开发板：`工具 → 开发板 → Arduino Uno`
4. 选择端口：`工具 → 端口 → [你的 Arduino 端口]`
5. 打开固件文件：`firmware/hx711_oled_hc08_weight_monitor_v2.ino`
6. 点击 `上传` 按钮烧录程序

### 2. iOS 应用使用

1. 使用 Xcode 打开 `ios/hx711_oled_hc08_weight_monitor_ios.xcodeproj`
2. 连接 iOS 设备或使用模拟器
3. 运行项目（⌘R）
4. 在应用中点击"搜索设备"
5. 选择 HC-08 设备进行连接
6. 连接成功后，应用将自动接收并显示重量数据

## 📊 数据格式

Arduino 通过蓝牙发送的数据格式：

```
===============
Weight: 100 g
Status: Stable
Object: Detected
Time: 800 s
System Running
===============
```

数据说明：
- `Weight`: 当前水杯重量（单位：克）
- `Status`: 重量状态（Stable/Unstable，用于判断是否在喝水）
- `Object`: 物体检测状态（Detected/None，检测水杯是否放置）
- `Time`: 系统运行时间（单位：秒）

## 🔄 版本说明

### 固件 (v2)
- 内存优化，减少内存占用
- OLED 防闪烁优化显示（200ms 更新间隔）
- 改进的蓝牙连接状态检测
- 配套 iOS 应用

## 🛠️ 技术栈

### Arduino 端
- **语言**: C++ (Arduino)
- **传感器**: HX711 重量传感器
- **显示**: SSD1306 OLED (I2C)
- **通信**: HC-08 蓝牙模块 (串口)
- **优化**: 内存优化、防闪烁显示

### iOS 端
- **语言**: Swift
- **UI 框架**: SwiftUI
- **蓝牙**: CoreBluetooth
- **数据存储**: CoreData
- **响应式**: Combine

## 📝 开发说明

### Arduino 固件开发
- 重量计算基于官方 HX711 例程，通过监测重量变化判断喝水行为
- 使用定时器控制数据更新频率（1秒/次），平衡实时性和功耗
- OLED 显示更新间隔 200ms，避免闪烁，提升用户体验
- 蓝牙连接状态通过超时机制检测，确保数据传输稳定

### iOS 应用开发
- 使用 MVVM 架构模式，代码结构清晰
- `BluetoothViewModel` 处理所有蓝牙通信逻辑，自动重连
- `PersistenceController` 管理 CoreData 存储，持久化喝水记录
- SwiftUI 实现响应式 UI 更新，实时显示喝水量和统计信息
- 通过重量差值计算每次喝水量，自动记录到历史数据

## 🐛 故障排除

### Arduino 端
- **OLED 不显示**: 检查 I2C 地址（0x3C 或 0x3D），确认连接正确
- **重量读数异常**: 检查 HX711 连接，重新校准空载基准值（空杯时的重量）
- **蓝牙无法连接**: 确认 HC-08 波特率为 9600，检查 TX/RX 连接
- **喝水检测不准确**: 调整重量系数（GapValue），确保能准确检测重量变化

### iOS 端
- **无法搜索到设备**: 确认蓝牙已开启，HC-08 已配对
- **连接失败**: 检查设备是否在其他应用中已连接
- **数据不更新**: 确认 Arduino 端正在发送数据，检查数据格式
- **喝水量统计不准确**: 检查水杯是否稳定放置，避免误判

## 📄 许可证

本项目仅供学习和个人使用。

## 👤 作者

陈纬

## 📧 联系方式

- 邮箱: 514351508@qq.com
- 电话: 15895193783

---

*最后更新：2026年*
