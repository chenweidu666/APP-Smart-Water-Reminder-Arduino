/*
  HX711 + OLED + HC-08蓝牙模块程序 - Arduino Uno (内存优化版)
  功能：HX711重量传感器数据监控，OLED屏幕显示重量，HC-08蓝牙传输数据
  特点：
    - 基于官方例程的重量计算方式
    - 实时重量显示（无缓存延迟）
    - OLED屏幕实时显示重量
    - HC-08蓝牙模块数据传输
    - 串口输出详细信息
    - 重量状态自动判断
    - LED状态指示（闪烁=不稳定，常亮=稳定）
    - 稳定数据历史记录存储（减少到5条）
    - 智能日志输出（稳定时安静，不稳定时详细）
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
    - LED连接到Arduino引脚13 (内置LED)或引脚9
*/

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define HX711_SCK 10
#define HX711_DT 11
#define STATUS_LED 13

// OLED屏幕设置
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
#define OLED_RESET -1

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// 全局变量 - 内存优化
long Weight_Maopi = 0;
#define GapValue 430
bool oledAvailable = false;

// 重量稳定性检测
long lastWeight = 0;
bool weightStable = false;
bool wasStable = false;
unsigned long stableStartTime = 0;
const unsigned long STABLE_DURATION = 2000;
const long STABLE_THRESHOLD = 5;

// 稳定数据存储数组 - 减少到5条记录
struct StableData {
  int weight;  // 使用int而不是long节省内存
  unsigned int timestamp;  // 使用unsigned int
  bool isEmpty;
};
const int MAX_STABLE_RECORDS = 5;  // 减少到5条记录
StableData stableRecords[MAX_STABLE_RECORDS];
byte stableRecordCount = 0;  // 使用byte

// LED闪烁控制
unsigned long lastLedUpdate = 0;
const unsigned long LED_BLINK_INTERVAL = 200;
bool ledState = false;

// 蓝牙保护变量
unsigned long lastDataUpdate = 0;
const unsigned long DATA_UPDATE_INTERVAL = 1000;
unsigned long lastConnectionCheck = 0;
const unsigned long CONNECTION_CHECK_INTERVAL = 2000;
bool bluetoothConnected = false;
unsigned long lastDataSent = 0;
const unsigned long CONNECTION_TIMEOUT = 10000;

void setup() {
  Serial.begin(9600);
  delay(2000);
  
  while (!Serial) {
    ;
  }
  
  pinMode(HX711_SCK, OUTPUT);
  pinMode(HX711_DT, INPUT);
  pinMode(STATUS_LED, OUTPUT);
  
  // 初始化I2C
  Wire.begin();
  // 移除 Wire.setClock(100000); 这行

  // 移除I2C扫描部分

  // 简化的OLED初始化
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3D)) {
      Serial.println("OLED初始化失败");
      oledAvailable = false;
    } else {
      Serial.println("OLED初始化成功 (0x3D)");
      oledAvailable = true;
    }
  } else {
    Serial.println("OLED初始化成功 (0x3C)");
    oledAvailable = true;
  }

  if (oledAvailable) {
    display.clearDisplay();
    display.display();
    
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.println("HX711 + OLED + HC08");
    display.println("Smart Monitor");
    display.display();
    delay(1000);
  } else {
    Serial.println("OLED不可用，使用串口显示");
  }
  
  Serial.println("=== HX711 + OLED + HC-08智能监控系统启动 ===");
  Serial.println("HX711引脚: SCK=10, DT=11");
  Serial.println("HC-08引脚: RX=0, TX=1");
  Serial.println("状态LED引脚: 13");
  Serial.println("重量系数: 430");
  Serial.println("功能: 重量监控 + OLED显示 + HC-08蓝牙传输");
  Serial.println("LED状态: 闪烁=不稳定，常亮=稳定");
  Serial.println("智能日志: 稳定时安静，不稳定时详细");
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
  
  if (oledAvailable) {
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("Ready!");
    display.display();
    delay(500);
  }
  
  Serial.println("HC-08 Smart Monitor Ready!");
  Serial.println("开始发送数据...");
  Serial.println("蓝牙状态: 未连接");
  delay(1000);
  Serial.println("Test Message: Hello HC-08!");
}

void loop() {
  // 检查蓝牙连接状态
  if (millis() - lastConnectionCheck > CONNECTION_CHECK_INTERVAL) {
    checkBluetoothConnection();
    lastConnectionCheck = millis();
  }
  
  // 检查DT引脚状态
  if (digitalRead(HX711_DT) == LOW) {
    unsigned long rawData = HX711_Read();
    
    if (rawData != 0) {
      long weightRaw = rawData - Weight_Maopi;
      long weightGrams = (long)((float)weightRaw / GapValue);
      
      // 检查重量稳定性
      checkWeightStability(weightGrams);
      
      // 更新LED状态
      updateLEDStatus();
      
      // OLED显示
      if (oledAvailable) {
        display.clearDisplay();
        display.setTextSize(1);
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(0, 0);
        
        // 第一行：当前重量
        display.print("Weight: ");
        display.print(weightGrams);
        display.println(" g");
        
        // 第二行：稳定状态
        if (weightStable) {
          display.println("Status: Stable");
        } else {
          display.println("Status: Unstable");
        }
        
        // 第三行：记录数量
        display.print("Records: ");
        display.print(stableRecordCount);
        display.println("/5");
        
        display.display();
      }
      
      // 数据发送
      if (millis() - lastDataUpdate > DATA_UPDATE_INTERVAL) {
        if (bluetoothConnected) {
          if (!weightStable) {
            Serial.print("Weight:");
            Serial.print(weightGrams);
            Serial.print("g Time:");
            Serial.print(millis() / 1000);
            Serial.print("s Status:Unstable");
            if (abs(weightGrams) > 5) {
              Serial.println(" Object");
            } else {
              Serial.println(" Empty");
            }
            Serial.println("Heartbeat - System Running");
            Serial.println("数据已通过HC-08发送 - 状态: 不稳定");
            Serial.println("========================================");
          }
          lastDataUpdate = millis();
          lastDataSent = millis();
        } else {
          Serial.println("蓝牙未连接，跳过数据发送");
          Serial.println("========================================");
        }
      }
    } else {
      Serial.println("HX711读取失败");
      Serial.println("========================================");
    }
  } else {
    if (oledAvailable) {
      display.clearDisplay();
      display.setTextSize(1);
      display.setTextColor(SSD1306_WHITE);
      display.setCursor(0, 0);
      display.println("Waiting...");
      display.display();
    }
  }
  
  delay(50);
}

// 检查重量稳定性
void checkWeightStability(long currentWeight) {
  if (abs(currentWeight - lastWeight) <= STABLE_THRESHOLD) {
    if (!weightStable) {
      weightStable = true;
      stableStartTime = millis();
    } else {
      if (millis() - stableStartTime >= STABLE_DURATION) {
        if (!wasStable) {
          addStableRecord(currentWeight);
          
          Serial.print("Weight:");
          Serial.print(currentWeight);
          Serial.print("g Time:");
          Serial.print(millis() / 1000);
          Serial.print("s Status:Stable");
          if (abs(currentWeight) > 5) {
            Serial.println(" Object");
          } else {
            Serial.println(" Empty");
          }
          Serial.println("Heartbeat - System Running");
          Serial.println("数据已通过HC-08发送 - 状态: 稳定");
          if (currentWeight == 0) {
            Serial.println("空载");
          }
          
          printStableRecords();
          Serial.println("========================================");
          wasStable = true;
        }
        weightStable = true;
      }
    }
  } else {
    if (weightStable) {
      Serial.println("状态变化: 稳定 -> 不稳定");
      printStableRecords();
      Serial.println("========================================");
    }
    weightStable = false;
    lastWeight = currentWeight;
    wasStable = false;
  }
}

// 添加稳定记录到数组
void addStableRecord(long weight) {
  if (stableRecordCount < MAX_STABLE_RECORDS) {
    stableRecords[stableRecordCount].weight = (int)weight;
    stableRecords[stableRecordCount].timestamp = (unsigned int)(millis() / 1000);
    stableRecords[stableRecordCount].isEmpty = (weight == 0);
    stableRecordCount++;
  } else {
    for (byte i = 0; i < MAX_STABLE_RECORDS - 1; i++) {
      stableRecords[i] = stableRecords[i + 1];
    }
    stableRecords[MAX_STABLE_RECORDS - 1].weight = (int)weight;
    stableRecords[MAX_STABLE_RECORDS - 1].timestamp = (unsigned int)(millis() / 1000);
    stableRecords[MAX_STABLE_RECORDS - 1].isEmpty = (weight == 0);
  }
}

// 打印所有稳定记录
void printStableRecords() {
  Serial.println("=== 稳定记录历史 ===");
  if (stableRecordCount == 0) {
    Serial.println("无记录");
  } else {
    for (byte i = 0; i < stableRecordCount; i++) {
      Serial.print("记录");
      Serial.print(i + 1);
      Serial.print(": ");
      Serial.print(stableRecords[i].weight);
      Serial.print("g @ ");
      Serial.print(stableRecords[i].timestamp);
      Serial.print("s");
      if (stableRecords[i].isEmpty) {
        Serial.println(" (空载)");
      } else {
        Serial.println(" (有物)");
      }
    }
  }
  Serial.println("==================");
}

// 更新LED状态
void updateLEDStatus() {
  if (weightStable) {
    digitalWrite(STATUS_LED, HIGH);
  } else {
    if (millis() - lastLedUpdate > LED_BLINK_INTERVAL) {
      ledState = !ledState;
      digitalWrite(STATUS_LED, ledState);
      lastLedUpdate = millis();
    }
  }
}

// 检查蓝牙连接状态
void checkBluetoothConnection() {
  if (millis() - lastDataSent > CONNECTION_TIMEOUT) {
    if (bluetoothConnected) {
      bluetoothConnected = false;
      if (!weightStable) {
        Serial.println("蓝牙状态: 未连接 (超时)");
        Serial.println("========================================");
      }
    }
  } else {
    if (!bluetoothConnected) {
      bluetoothConnected = true;
      if (!weightStable) {
        Serial.println("蓝牙状态: 已连接");
        Serial.println("========================================");
      }
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