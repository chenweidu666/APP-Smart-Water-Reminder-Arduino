/*
  HC-08蓝牙简单测试程序 - Arduino Uno
  功能：最简单的HC-08蓝牙测试
  硬件连接：
    - HC-08的VCC连接到Arduino 5V
    - HC-08的GND连接到Arduino GND
    - HC-08的TXD连接到Arduino引脚0 (RX)
    - HC-08的RXD连接到Arduino引脚1 (TX)
*/

void setup() {
  Serial.begin(9600);
  delay(2000);
  
  Serial.println("HC-08 Simple Test Start");
  Serial.println("HC-08 Ready!");
}

void loop() {
  // 每秒发送一次测试数据
  Serial.println("Hello HC-08!");
  delay(1000);
  
  // 检查接收
  if (Serial.available()) {
    String data = Serial.readString();
    Serial.print("Received: ");
    Serial.println(data);
  }
}
