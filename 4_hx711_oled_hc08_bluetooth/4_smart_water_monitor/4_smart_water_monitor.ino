/*
  HX711 + OLED + HC-08蓝牙模块程序 - Arduino Uno (智能喝水检测版)
  功能：HX711重量传感器 + OLED屏幕显示 + HC-08蓝牙模块 + 智能喝水检测
  特点：
    - 基于官方例程的重量计算方式
    - 数据平滑处理（1秒采样10次，快速响应）
    - OLED屏幕实时显示重量和喝水状态
    - HC-08蓝牙模块数据传输
    - 智能喝水检测和计算（基于杯子重量变化）
    - 按需发送：喝水时发送 + 每10秒总计
    - 终端输出与蓝牙输出保持一致（简化消息）
  硬件连接：
    - HX711的SCK连接到Arduino引脚10
    - HX711的DT连接到Arduino引脚11
    - HX711的VCC连接到Arduino 5V
    - HX711的GND连接到Arduino GND
    - OLED的VCC连接到Arduino 5V
    - OLED的GND连接到Arduino GND
    - OLED的SCL连接到Arduino SCL (专用I2C时钟线)
    - OLED的SDA连接到Arduino SDA (专用I2C数据线)
    - HC-08的VCC连接到Arduino 5V
    - HC-08的GND连接到Arduino GND
    - HC-08的TXD连接到Arduino引脚0 (RX)
    - HC-08的RXD连接到Arduino引脚1 (TX)
*/

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define HX711_SCK 10
#define HX711_DT 11

// OLED屏幕设置
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1
#define SCREEN_ADDRESS 0x3C

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// 喝水检测状态机
enum DrinkingState {
  EMPTY,           // 空杯状态
  FILLED,          // 满杯状态  
  DRINKING,        // 喝水状态
  STABLE           // 稳定状态
};

// 喝水事件记录
struct DrinkingEvent {
  unsigned long startTime;    // 开始时间
  unsigned long endTime;      // 结束时间
  long beforeWeight;         // 喝水前重量
  long afterWeight;          // 喝水后重量
  long waterConsumed;        // 喝水量（重量差值）
  bool isValid;              // 是否有效
};

// 全局变量 - 内存优化
long Weight_Maopi = 0;  // 空载基准值
#define GapValue 430  // 重量系数，与官方例程一致
bool oledAvailable = false;  // OLED是否可用

// 数据平滑处理 - 1秒采样10次
#define SAMPLE_COUNT 10  // 1秒采样10次
long weightHistory[SAMPLE_COUNT];  // 重量历史数据
byte historyIndex = 0;  // 使用byte节省内存
bool hasEnoughSamples = false;  // 是否有足够的采样数据

// 喝水检测参数
#define WEIGHT_THRESHOLD 5     // 重量变化阈值(克)
#define STABLE_TIME 2000       // 稳定时间(毫秒)
#define MIN_DRINKING_WEIGHT 3  // 最小喝水重量(克)
#define MAX_DRINKING_WEIGHT 300 // 最大喝水重量(克)

// 喝水检测状态
DrinkingState currentState = EMPTY;
DrinkingState previousState = EMPTY;
unsigned long stateChangeTime = 0;
long lastStableWeight = 0;
long currentDrinkingStartWeight = 0;
unsigned long drinkingStartTime = 0;

// 杯子重量管理
long cupWeight = 0;           // 杯子重量
bool cupWeightSet = false;    // 是否已设置杯子重量
long maxCupWeight = 0;        // 杯子最大重量（满杯时）

// 喝水事件记录
#define MAX_EVENTS 10
DrinkingEvent drinkingEvents[MAX_EVENTS];
byte eventIndex = 0;
byte totalEvents = 0;
long totalWaterConsumed = 0;  // 总喝水量

// 蓝牙发送控制 - 按需发送
unsigned long lastTotalReport = 0;
const unsigned long TOTAL_REPORT_INTERVAL = 10000;  // 每10秒发送一次总重量
bool hasNewDrinkingEvent = false;  // 是否有新的喝水事件

// 采样控制
unsigned long lastSampleTime = 0;
const unsigned long SAMPLE_INTERVAL = 100;  // 100ms采样一次，1秒采样10次

// 蓝牙连接状态检测
unsigned long lastConnectionCheck = 0;
const unsigned long CONNECTION_CHECK_INTERVAL = 2000;  // 2秒检查一次连接状态
bool bluetoothConnected = false;
unsigned long lastDataSent = 0;
const unsigned long CONNECTION_TIMEOUT = 10000;  // 10秒无数据认为断开

void setup() {
  Serial.begin(9600);
  delay(2000);  // 给HC-08更多启动时间
  
  // 等待串口连接
  while (!Serial) {
    ; // 等待串口端口连接
  }
  
  pinMode(HX711_SCK, OUTPUT);
  pinMode(HX711_DT, INPUT);
  
  // 初始化I2C
  Wire.begin();
  
  // 尝试初始化OLED屏幕
  if(!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3D)) {
      Serial.println(F("OLED初始化失败"));
      oledAvailable = false;
    } else {
      oledAvailable = true;
    }
  } else {
    oledAvailable = true;
  }
  
  if (oledAvailable) {
    display.clearDisplay();
    display.display();
    
    // 显示启动信息
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.println("Smart Water Monitor");
    display.println("HX711+OLED+HC08");
    display.display();
    delay(1000);
  }
  
  Serial.println("=== 智能喝水检测系统启动 ===");
  Serial.println("HX711引脚: SCK=10, DT=11");
  Serial.println("HC-08引脚: RX=0, TX=1");
  Serial.println("重量系数: 430");
  Serial.println("蓝牙波特率: 9600");
  Serial.println("功能: 重量监控 + OLED显示 + HC-08蓝牙传输 + 智能喝水检测");
  Serial.println("检测方式: 基于杯子重量变化");
  Serial.println("采样频率: 100ms (1秒10次)");
  Serial.println("蓝牙发送: 喝水时发送 + 每10秒总计");
  Serial.println("================================");
  
  // 获取空载基准值
  Serial.println("正在校准...");
  if (oledAvailable) {
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("Calibrating...");
    display.display();
  }
  
  Get_Maopi();
  Serial.print("基准值: ");
  Serial.println(Weight_Maopi);
  Serial.println("校准完成！");
  
  // 初始化重量历史数据
  for (byte i = 0; i < SAMPLE_COUNT; i++) {
    weightHistory[i] = 0;
  }
  
  // 初始化喝水事件记录
  for (byte i = 0; i < MAX_EVENTS; i++) {
    drinkingEvents[i].isValid = false;
  }
  
  if (oledAvailable) {
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("Ready!");
    display.println("Place cup to start");
    display.display();
    delay(500);
  }
  
  Serial.println("智能喝水检测系统就绪！");
  Serial.println("请放置杯子开始检测...");
  Serial.println("蓝牙状态: 未连接");
  
  // 发送测试消息
  delay(1000);
  Serial.println("Test Message: Smart Water Monitor Ready!");
}

void loop() {
  // 检查蓝牙连接状态
  if (millis() - lastConnectionCheck > CONNECTION_CHECK_INTERVAL) {
    checkBluetoothConnection();
    lastConnectionCheck = millis();
  }
  
  // 检查DT引脚状态
  if (digitalRead(HX711_DT) == LOW) {
    // DT为低电平，可以读取数据
    unsigned long rawData = HX711_Read();
    
    if (rawData != 0) {
      // 计算重量
      long weightRaw = rawData - Weight_Maopi;
      long weightGrams = (long)((float)weightRaw / GapValue);
      
      // 数据平滑处理 - 100ms采样一次
      if (millis() - lastSampleTime > SAMPLE_INTERVAL) {
        weightHistory[historyIndex] = weightGrams;
        historyIndex = (historyIndex + 1) % SAMPLE_COUNT;
        
        // 检查是否有足够的采样数据
        if (historyIndex == 0) {
          hasEnoughSamples = true;
        }
        
        lastSampleTime = millis();
      }
      
      // 计算平均值 - 只有足够采样数据时才计算
      long avgWeightGrams = 0;
      if (hasEnoughSamples) {
        for (byte i = 0; i < SAMPLE_COUNT; i++) {
          avgWeightGrams += weightHistory[i];
        }
        avgWeightGrams /= SAMPLE_COUNT;
      } else {
        // 采样数据不足时，使用当前值
        avgWeightGrams = weightGrams;
      }
      
      // 喝水检测和状态分析
      analyzeDrinkingState(avgWeightGrams);
      
      // OLED显示
      if (oledAvailable) {
        display.clearDisplay();
        display.setTextSize(1);
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(0, 0);
        display.print("Weight: ");
        display.print(avgWeightGrams);
        display.println(" g");
        
        // 状态显示
        display.setTextSize(1);
        switch (currentState) {
          case EMPTY:
            display.println("Empty");
            break;
          case FILLED:
            display.println("Filled");
            break;
          case DRINKING:
            display.println("Drinking...");
            break;
          case STABLE:
            display.println("Stable");
            break;
        }
        
        // 显示总喝水量
        if (totalWaterConsumed > 0) {
          display.print("Total: ");
          display.print(totalWaterConsumed);
          display.println("g");
        }
        
        display.display();
      }
      
      // 蓝牙数据发送 - 按需发送
      if (bluetoothConnected) {
        // 1. 有新的喝水事件时立即发送
        if (hasNewDrinkingEvent) {
          sendDrinkingEvent();
          hasNewDrinkingEvent = false;
        }
        
        // 2. 每10秒发送一次总重量
        if (millis() - lastTotalReport > TOTAL_REPORT_INTERVAL) {
          sendTotalWeight();
          lastTotalReport = millis();
        }
      }
      
    } else {
      Serial.println("HX711读取失败");
    }
  } else {
    // DT为高电平，数据未准备好
    if (oledAvailable) {
      display.clearDisplay();
      display.setTextSize(1);
      display.setTextColor(SSD1306_WHITE);
      display.setCursor(0, 0);
      display.println("Waiting...");
      display.display();
    }
  }
  
  delay(50);  // 减少主循环延迟，提高响应速度
}

// 分析喝水状态 - 基于杯子重量变化
void analyzeDrinkingState(long currentWeight) {
  unsigned long currentTime = millis();
  
  // 状态转换逻辑
  switch (currentState) {
    case EMPTY:
      if (currentWeight > WEIGHT_THRESHOLD) {
        // 检测到杯子放置
        if (!cupWeightSet) {
          cupWeight = currentWeight;
          cupWeightSet = true;
          maxCupWeight = currentWeight;
        }
        changeState(FILLED, currentTime);
        lastStableWeight = currentWeight;
      }
      break;
      
    case FILLED:
      if (currentWeight > lastStableWeight + WEIGHT_THRESHOLD) {
        // 检测到倒水（重量增加）
        changeState(FILLED, currentTime);
        lastStableWeight = currentWeight;
        maxCupWeight = currentWeight;
      } else if (currentWeight < lastStableWeight - WEIGHT_THRESHOLD) {
        // 检测到喝水（重量减少）
        changeState(DRINKING, currentTime);
        currentDrinkingStartWeight = lastStableWeight;
        drinkingStartTime = currentTime;
      }
      break;
      
    case DRINKING:
      if (abs(currentWeight - lastStableWeight) < WEIGHT_THRESHOLD && 
          (currentTime - stateChangeTime) > STABLE_TIME) {
        // 喝水结束，计算喝水量
        long waterConsumed = currentDrinkingStartWeight - currentWeight;
        if (waterConsumed >= MIN_DRINKING_WEIGHT && 
            waterConsumed <= MAX_DRINKING_WEIGHT) {
          recordDrinkingEvent(currentDrinkingStartWeight, currentWeight, 
                            waterConsumed, drinkingStartTime, currentTime);
          hasNewDrinkingEvent = true;  // 标记有新的喝水事件
        }
        changeState(FILLED, currentTime);
        lastStableWeight = currentWeight;
      }
      break;
      
    case STABLE:
      if (currentWeight > WEIGHT_THRESHOLD) {
        changeState(FILLED, currentTime);
        lastStableWeight = currentWeight;
      } else {
        changeState(EMPTY, currentTime);
        lastStableWeight = 0;
      }
      break;
  }
}

// 状态转换
void changeState(DrinkingState newState, unsigned long time) {
  if (newState != currentState) {
    previousState = currentState;
    currentState = newState;
    stateChangeTime = time;
  }
}

// 记录喝水事件
void recordDrinkingEvent(long beforeWeight, long afterWeight, long waterConsumed, 
                        unsigned long startTime, unsigned long endTime) {
  drinkingEvents[eventIndex].startTime = startTime;
  drinkingEvents[eventIndex].endTime = endTime;
  drinkingEvents[eventIndex].beforeWeight = beforeWeight;
  drinkingEvents[eventIndex].afterWeight = afterWeight;
  drinkingEvents[eventIndex].waterConsumed = waterConsumed;
  drinkingEvents[eventIndex].isValid = true;
  
  eventIndex = (eventIndex + 1) % MAX_EVENTS;
  if (totalEvents < MAX_EVENTS) {
    totalEvents++;
  }
  
  totalWaterConsumed += waterConsumed;
}

// 发送喝水事件数据 - 简化消息，与终端输出一致
void sendDrinkingEvent() {
  if (totalEvents > 0) {
    // 获取最后一次喝水事件
    byte lastEventIndex = (eventIndex - 1 + MAX_EVENTS) % MAX_EVENTS;
    if (drinkingEvents[lastEventIndex].isValid) {
      // 简化消息格式，去掉时间戳
      Serial.print("喝水重量 ");
      Serial.print(drinkingEvents[lastEventIndex].waterConsumed);
      Serial.println(" g");
      lastDataSent = millis();
    }
  }
}

// 发送总重量数据 - 简化消息，与终端输出一致
void sendTotalWeight() {
  if (totalWaterConsumed > 0) {
    // 简化消息格式，去掉时间戳
    Serial.print("喝水总重量 ");
    Serial.print(totalWaterConsumed);
    Serial.println("g");
    lastDataSent = millis();
  }
}

// 检查蓝牙连接状态
void checkBluetoothConnection() {
  // 检查是否有数据发送成功
  if (millis() - lastDataSent > CONNECTION_TIMEOUT) {
    if (bluetoothConnected) {
      bluetoothConnected = false;
      Serial.println("蓝牙状态: 未连接 (超时)");
    }
  } else {
    if (!bluetoothConnected) {
      bluetoothConnected = true;
      Serial.println("蓝牙状态: 已连接");
    }
  }
}

// 获取空载基准值
void Get_Maopi() {
  Weight_Maopi = HX711_Read();
}

// 读取HX711
unsigned long HX711_Read(void) {
  unsigned long count; 
  unsigned char i;

  digitalWrite(HX711_DT, HIGH);
  delayMicroseconds(1);

  digitalWrite(HX711_SCK, LOW);
  delayMicroseconds(1);

  count = 0; 
  while(digitalRead(HX711_DT)); 
  for(i = 0; i < 24; i++) { 
    digitalWrite(HX711_SCK, HIGH); 
    delayMicroseconds(1);
    count = count << 1; 
    digitalWrite(HX711_SCK, LOW); 
    delayMicroseconds(1);
    if(digitalRead(HX711_DT))
      count++; 
  } 
  digitalWrite(HX711_SCK, HIGH); 
  count ^= 0x800000;
  delayMicroseconds(1);
  digitalWrite(HX711_SCK, LOW); 
  delayMicroseconds(1);
  
  return(count);
}
