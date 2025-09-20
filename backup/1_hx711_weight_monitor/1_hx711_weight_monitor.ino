/*
  HX711重量传感器监控程序 - Arduino Uno
  功能：HX711重量传感器数据监控，串口打印重量
  硬件连接：
    - HX711的SCK连接到Arduino引脚10
    - HX711的DT连接到Arduino引脚11
    - HX711的VCC连接到Arduino 5V
    - HX711的GND连接到Arduino GND
*/

#define HX711_SCK 10
#define HX711_DT 11

// 全局变量
long Weight_Maopi = 0;  // 空载基准值
bool isCalibrated = false;  // 是否已校准
#define GapValue 430  // 重量系数，与官方例程一致

// 数据平滑处理
#define SAMPLE_COUNT 5  // 采样次数
long weightHistory[SAMPLE_COUNT];  // 重量历史数据（以克为单位）
int historyIndex = 0;  // 历史数据索引

void setup() {
  Serial.begin(9600);
  
  // 等待串口连接
  while (!Serial) {
    ; // 等待串口端口连接
  }
  
  pinMode(HX711_SCK, OUTPUT);
  pinMode(HX711_DT, INPUT);
  
  Serial.println("=== HX711重量传感器监控程序启动 ===");
  Serial.println("如果您看到这条消息，说明串口通信正常！");
  Serial.println("HX711引脚: SCK=10, DT=11");
  Serial.println("波特率: 9600");
  Serial.println("重量系数: 430 (与官方例程一致)");
  Serial.println("================================");
  
  // 测试引脚状态
  Serial.println("测试引脚状态...");
  Serial.print("SCK引脚(10): ");
  Serial.println(digitalRead(10));
  Serial.print("DT引脚(11): ");
  Serial.println(digitalRead(11));
  
  Serial.println("开始读取HX711数据...");
  Serial.println("如果长时间无数据，请检查连接");
  Serial.println("================================");
  
  // 获取空载基准值
  Serial.println("正在获取空载基准值...");
  Get_Maopi();
  Serial.print("空载基准值: ");
  Serial.println(Weight_Maopi);
  Serial.println("校准完成！开始显示重量...");
  Serial.println("注意：空载时数据会有微小变化，这是正常现象");
  Serial.println("================================");
  
  // 初始化重量历史数据
  for (int i = 0; i < SAMPLE_COUNT; i++) {
    weightHistory[i] = 0;
  }
}

void loop() {
  // 检查DT引脚状态
  bool dtState = digitalRead(HX711_DT);
  
  if (dtState == LOW) {
    // DT为低电平，可以读取数据
    unsigned long rawData = HX711_Read();
    
    if (rawData != 0) {
      // 计算重量（按照官方例程的方式）
      long weightRaw = rawData - Weight_Maopi;
      long weightGrams = (long)((float)weightRaw / GapValue);  // 以克为单位
      
      // 数据平滑处理
      weightHistory[historyIndex] = weightGrams;
      historyIndex = (historyIndex + 1) % SAMPLE_COUNT;
      
      // 计算平均值
      long avgWeightGrams = 0;
      for (int i = 0; i < SAMPLE_COUNT; i++) {
        avgWeightGrams += weightHistory[i];
      }
      avgWeightGrams /= SAMPLE_COUNT;
      
      // 串口输出（按照官方例程的格式）
      Serial.print("时间: ");
      Serial.print(millis() / 1000);
      Serial.print("s | 原始数据: ");
      Serial.print(rawData);
      Serial.print(" | 当前重量: ");
      Serial.print(weightGrams);
      Serial.print(" g | 平均重量: ");
      Serial.print(avgWeightGrams);
      Serial.print(" g | 重量(kg): ");
      Serial.print(float(avgWeightGrams) / 1000, 3);
      Serial.println(" kg");
      
      // 重量状态提示（使用平均值判断）
      if (abs(avgWeightGrams) > 5) {  // 5克阈值
        Serial.println("  -> 检测到重物！");
      } else if (abs(avgWeightGrams) < 2) {
        Serial.println("  -> 传感器空载（数据稳定）");
      } else {
        Serial.println("  -> 传感器空载（数据波动）");
      }
    }
  } else {
    // DT为高电平，数据未准备好
    Serial.print("时间: ");
    Serial.print(millis() / 1000);
    Serial.println("s | 数据未准备好 (DT=HIGH)");
  }
  
  delay(1000);
}

// 获取空载基准值（按照官方例程）
void Get_Maopi() {
  Serial.println("正在采集基准数据，请保持传感器空载...");
  Weight_Maopi = HX711_Read();
  Serial.print("基准值: ");
  Serial.println(Weight_Maopi);
  isCalibrated = true;
}

// 读取HX711（按照官方例程）
unsigned long HX711_Read(void) {
  unsigned long count; 
  unsigned char i;
  bool Flag = 0;

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