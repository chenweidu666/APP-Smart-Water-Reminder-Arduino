/*
  HX711 + OLED 重量监控程序 - Arduino Uno (简化版)
  功能：HX711重量传感器数据监控，OLED屏幕显示重量
  特点：
    - 基于官方例程的重量计算方式
    - 实时重量显示（无缓存延迟）
    - OLED屏幕防闪烁优化显示
    - 串口输出详细信息
    - 重量状态自动判断
    - 内存优化版本
  硬件连接：
    - HX711的SCK连接到Arduino引脚10
    - HX711的DT连接到Arduino引脚11
    - HX711的VCC连接到Arduino 5V
    - HX711的GND连接到Arduino GND
    - OLED的VCC连接到Arduino 5V
    - OLED的GND连接到Arduino GND
    - OLED的SCL连接到Arduino A5 (I2C时钟线)
    - OLED的SDA连接到Arduino A4 (I2C数据线)
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

// OLED I2C端口定义
#define OLED_SDA A4  // I2C数据线
#define OLED_SCL A5  // I2C时钟线

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// 全局变量 - 内存优化
long Weight_Maopi = 0;  // 空载基准值
#define GapValue 430  // 重量系数，与官方例程一致
bool oledAvailable = false;  // OLED是否可用

// 串口输出控制 - 每2秒输出一次
unsigned long lastSerialUpdate = 0;
const unsigned long SERIAL_UPDATE_INTERVAL = 2000;  // 2秒输出一次

// OLED防闪烁优化变量 - 减少内存使用
unsigned long lastDisplayUpdate = 0;
const unsigned long DISPLAY_UPDATE_INTERVAL = 200;  // 200ms更新一次显示
long lastDisplayWeight = 0;
bool lastStableState = false;
bool lastObjectDetected = false;

void setup() {
  Serial.begin(9600);
  
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
      Serial.println(F("OLED init failed"));
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
    display.println("HX711 Monitor");
    display.println("Starting...");
    display.display();
    delay(1000);
  }
  
  Serial.println("=== HX711 Weight Monitor ===");
  Serial.println("HX711: SCK=10, DT=11");
  Serial.println("OLED: SDA=A4, SCL=A5");
  Serial.println("Weight Factor: 430");
  Serial.println("==========================");
  
  // 获取空载基准值
  Serial.println("Calibrating...");
  if (oledAvailable) {
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("Calibrating...");
    display.display();
  }
  
  Get_Maopi();
  Serial.print("Base: ");
  Serial.println(Weight_Maopi);
  Serial.println("Ready!");
  
  if (oledAvailable) {
    display.clearDisplay();
    display.setCursor(0, 0);
    display.println("Ready!");
    display.display();
    delay(500);
  }
}

void loop() {
  // 检查DT引脚状态
  if (digitalRead(HX711_DT) == LOW) {
    // DT为低电平，可以读取数据
    unsigned long rawData = HX711_Read();
    
    if (rawData != 0) {
      // 计算重量 - 直接使用当前读取值，无缓存
      long weightRaw = rawData - Weight_Maopi;
      long weightGrams = (long)((float)weightRaw / GapValue);
      
      // 优化后的OLED显示 - 防闪烁
      if (oledAvailable && millis() - lastDisplayUpdate > DISPLAY_UPDATE_INTERVAL) {
        updateOLEDDisplay(weightGrams);
        lastDisplayUpdate = millis();
      }
      
      // 串口输出 - 每2秒输出一次
      if (millis() - lastSerialUpdate > SERIAL_UPDATE_INTERVAL) {
        static long lastSerialWeight = 0;
        static unsigned long lastSerialUpdateTime = 0;
        static bool serialStable = false;
        if (millis() - lastSerialUpdateTime > 200) {
          serialStable = abs(weightGrams - lastSerialWeight) <= 3;
          lastSerialWeight = weightGrams;
          lastSerialUpdateTime = millis();
        }
        
        Serial.println("================");
        Serial.print("Weight: ");
        Serial.print(weightGrams);
        Serial.println(" g");
        Serial.print("Status: ");
        Serial.println(serialStable ? "Stable" : "Unstable");
        Serial.print("Object: ");
        if (abs(weightGrams) > 5) {
          Serial.println("Detected");
        } else {
          Serial.println("Empty");
        }
        Serial.print("Time: ");
        Serial.print(millis() / 1000);
        Serial.println(" s");
        Serial.println("System Running");
        Serial.println("================");
        
        lastSerialUpdate = millis();
      }
    } else {
      Serial.println("HX711 read failed");
    }
  } else {
    // DT为高电平，数据未准备好 - 只在需要时显示等待信息
    if (oledAvailable && millis() - lastDisplayUpdate > DISPLAY_UPDATE_INTERVAL) {
      static bool showingWaiting = false;
      if (!showingWaiting) {
        display.clearDisplay();
        display.setTextSize(1);
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(0, 0);
        display.println("Waiting...");
        display.display();
        showingWaiting = true;
        lastDisplayUpdate = millis();
      }
    }
  }
  
  delay(100);  // 增加主循环延迟，减少CPU负载
}

// 优化的OLED显示更新函数 - 内存优化
void updateOLEDDisplay(long weightGrams) {
  // 计算当前状态
  bool objectDetected = abs(weightGrams) > 5;
  bool isStable = abs(weightGrams - lastDisplayWeight) <= 3;
  
  // 检查是否需要更新显示（防闪烁的关键）
  bool needUpdate = false;
  
  // 重量变化超过1g时更新
  if (abs(weightGrams - lastDisplayWeight) > 1) {
    needUpdate = true;
  }
  
  // 状态变化时更新
  if (objectDetected != lastObjectDetected || isStable != lastStableState) {
    needUpdate = true;
  }
  
  // 如果不需要更新，直接返回
  if (!needUpdate) {
    return;
  }
  
  // 更新显示
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  
  // 第一行：重量
  display.setCursor(0, 0);
  display.print("W: ");
  display.print(weightGrams);
  display.println("g");
  
  // 第二行：物体检测状态
  display.setCursor(0, 12);
  if (objectDetected) {
    display.println("Object!");
  } else {
    display.println("Empty");
  }
  
  // 第三行：稳定性状态
  display.setCursor(0, 24);
  display.print("S: ");
  if (isStable) {
    display.println("Stable");
  } else {
    display.println("Unstable");
  }
  
  display.display();
  
  // 更新缓存值
  lastDisplayWeight = weightGrams;
  lastObjectDetected = objectDetected;
  lastStableState = isStable;
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