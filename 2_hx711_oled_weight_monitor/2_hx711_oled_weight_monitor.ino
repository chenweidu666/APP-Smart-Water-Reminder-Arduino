/*
  HX711 + 0.91寸OLED显示程序 - Arduino Uno (内存优化版)
  功能：HX711重量传感器数据监控，OLED屏幕显示重量
  硬件连接：
    - HX711的SCK连接到Arduino引脚10
    - HX711的DT连接到Arduino引脚11
    - HX711的VCC连接到Arduino 5V
    - HX711的GND连接到Arduino GND
    - OLED的VCC连接到Arduino 5V
    - OLED的GND连接到Arduino GND
    - OLED的SCL连接到Arduino SCL (专用I2C时钟线)
    - OLED的SDA连接到Arduino SDA (专用I2C数据线)
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

// 数据平滑处理 - 减少采样次数
#define SAMPLE_COUNT 3  // 从5减少到3
long weightHistory[SAMPLE_COUNT];  // 重量历史数据
byte historyIndex = 0;  // 使用byte节省内存

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
    display.println("HX711 + OLED");
    display.println("Weight Monitor");
    display.display();
    delay(1000);
  }
  
  Serial.println("=== HX711 + OLED程序启动 ===");
  Serial.println("HX711引脚: SCK=10, DT=11");
  Serial.println("重量系数: 430");
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
      // 计算重量
      long weightRaw = rawData - Weight_Maopi;
      long weightGrams = (long)((float)weightRaw / GapValue);
      
      // 数据平滑处理
      weightHistory[historyIndex] = weightGrams;
      historyIndex = (historyIndex + 1) % SAMPLE_COUNT;
      
      // 计算平均值
      long avgWeightGrams = 0;
      for (byte i = 0; i < SAMPLE_COUNT; i++) {
        avgWeightGrams += weightHistory[i];
      }
      avgWeightGrams /= SAMPLE_COUNT;
      
      // 串口输出
      Serial.print("时间: ");
      Serial.print(millis() / 1000);
      Serial.print("s | 重量: ");
      Serial.print(avgWeightGrams);
      Serial.println(" g");
      
      // OLED显示
      if (oledAvailable) {
        display.clearDisplay();
        display.setTextSize(1);  // 将字体从2改为1，减小字体
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(0, 0);
        display.print("Weight: ");
        display.print(avgWeightGrams);
        display.println(" g");
        
        // 状态显示
        display.setTextSize(1);
        if (abs(avgWeightGrams) > 5) {
          display.println("Object Detected!");
        } else {
          display.println("Empty");
        }
        
        display.display();
      }
      
      // 重量状态提示
      if (abs(avgWeightGrams) > 5) {
        Serial.println("  -> 检测到重物！");
      } else {
        Serial.println("  -> 传感器空载");
      }
    }
  } else {
    // DT为高电平，数据未准备好
    Serial.print("时间: ");
    Serial.print(millis() / 1000);
    Serial.println("s | 数据未准备好");
    
    if (oledAvailable) {
      display.clearDisplay();
      display.setTextSize(1);
      display.setTextColor(SSD1306_WHITE);
      display.setCursor(0, 0);
      display.println("Waiting...");
      display.display();
    }
  }
  
  delay(1000);
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