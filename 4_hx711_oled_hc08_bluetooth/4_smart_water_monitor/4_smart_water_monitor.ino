/*
  HX711 + OLED + HC-08蓝牙模块程序 - Arduino Uno (实时显示版)
  功能：HX711重量传感器数据监控，OLED屏幕显示重量，HC-08蓝牙传输数据
  特点：
    - 基于官方例程的重量计算方式
    - 实时重量显示（无缓存延迟）
    - OLED屏幕实时显示重量
    - HC-08蓝牙模块数据传输
    - 串口输出详细信息
    - 重量状态自动判断
    - 根据HC-08资料包优化的连接方式
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

// 全局变量 - 内存优化
long Weight_Maopi = 0;  // 空载基准值
#define GapValue 430  // 重量系数，与官方例程一致
bool oledAvailable = false;  // OLED是否可用

// 蓝牙保护变量 - 1秒发送一次数据
unsigned long lastDataUpdate = 0;
const unsigned long DATA_UPDATE_INTERVAL = 1000;  // 1秒发送一次数据

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
    display.println("HX711 + OLED + HC08");
    display.println("Weight Monitor");
    display.display();
    delay(1000);
  }
  
  Serial.println("=== HX711 + OLED + HC-08程序启动 ===");
  Serial.println("HX711引脚: SCK=10, DT=11");
  Serial.println("HC-08引脚: RX=0, TX=1");
  Serial.println("重量系数: 430");
  Serial.println("蓝牙波特率: 9600");
  Serial.println("功能: 重量监控 + OLED显示 + HC-08蓝牙传输");
  Serial.println("显示模式: 实时显示（无缓存）");
  Serial.println("数据发送频率: 1秒");
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
  
  // HC-08初始化测试
  Serial.println("HC-08 Weight Monitor Ready!");
  Serial.println("开始发送数据...");
  Serial.println("蓝牙状态: 未连接");
  
  // 发送测试消息
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
    // DT为低电平，可以读取数据
    unsigned long rawData = HX711_Read();
    
    if (rawData != 0) {
      // 计算重量 - 直接使用当前读取值，无缓存
      long weightRaw = rawData - Weight_Maopi;
      long weightGrams = (long)((float)weightRaw / GapValue);
      
      // 串口输出 - 注释掉重量打印
      /*
      Serial.print("时间: ");
      Serial.print(millis() / 1000);
      Serial.print("s | 重量: ");
      Serial.print(weightGrams);
      Serial.println(" g");
      */
      
      // OLED显示 - 实时显示当前重量
      if (oledAvailable) {
        display.clearDisplay();
        display.setTextSize(1);
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(0, 0);
        display.print("Weight: ");
        display.print(weightGrams);
        display.println(" g");
        
        // 状态显示
        display.setTextSize(1);
        if (abs(weightGrams) > 5) {
          display.println("Object Detected!");
        } else {
          display.println("Empty");
        }
        
        display.display();
      }
      
      // 统一的数据发送 - 每1秒发送一次
      if (millis() - lastDataUpdate > DATA_UPDATE_INTERVAL) {
        if (bluetoothConnected) {
          // 发送重量数据
          Serial.print("Weight:");
          Serial.print(weightGrams);
          Serial.print("g Time:");
          Serial.print(millis() / 1000);
          Serial.print("s");
          if (abs(weightGrams) > 5) {
            Serial.println(" Object");
          } else {
            Serial.println(" Empty");
          }
          
          // 发送心跳信号
          Serial.println("Heartbeat - System Running");
          
          lastDataUpdate = millis();
          lastDataSent = millis();
          Serial.println("数据已通过HC-08发送");
        } else {
          Serial.println("蓝牙未连接，跳过数据发送");
        }
      }
      
      // 重量状态提示 - 注释掉
      /*
      if (abs(weightGrams) > 5) {
        Serial.println("  -> 检测到重物！");
      } else {
        Serial.println("  -> 传感器空载");
      }
      */
    } else {
      Serial.println("HX711读取失败");
    }
  } else {
    // DT为高电平，数据未准备好
    /*
    Serial.print("时间: ");
    Serial.print(millis() / 1000);
    Serial.println("s | 数据未准备好");
    */
    
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
