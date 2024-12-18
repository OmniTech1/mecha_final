#include <Wire.h>
#include <MPU6050.h>
#include <SoftwareSerial.h>

MPU6050 mpu;
SoftwareSerial BTSerial(10, 11); // 소프트웨어 시리얼 핀 설정 (RX=10, TX=11)

// 소리 센서 핀 설정
const int soundSensorPin = A0;
const int soundThreshold = 40; // 데시벨 기준치
unsigned long measurementStartTime = 0; // 측정 시작 시간
bool measuring = false; // 측정 활성화 플래그

float maxAx = 0.0;
float maxAz = 0.0;

void setup() {
  Wire.begin();
  Serial.begin(9600);    // USB 시리얼 통신용
  BTSerial.begin(9600);  // 블루투스(HC-10) 통신용

  Serial.println("System starting..."); // 시스템 초기화 메시지 출력

  // I2C 스캔 추가
  Serial.println("Scanning for I2C devices...");
  for (byte address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    if (Wire.endTransmission() == 0) {
      Serial.print("I2C device found at address 0x");
      if (address < 16) Serial.print("0");
      Serial.println(address, HEX);
    }
  }
  Serial.println("I2C scan complete.");

  // MPU6050 초기화
  mpu.initialize();
  if (mpu.testConnection()) {
    Serial.println("MPU6050 connected successfully");
  } else {
    Serial.println("MPU6050 connection failed");
    Serial.println("Check power, SDA/SCL connections, and I2C address");
    while (1); // 오류 시 멈춤
  }
}

void loop() {
  // 소리 센서 데이터 읽기
  int soundLevel = analogRead(soundSensorPin);

  // 소리 감지 시 측정 시작
  if ((soundLevel > soundThreshold) && !measuring) {
    measuring = true;
    measurementStartTime = millis(); // 측정 시작 시간 기록
    maxAx = 0.0; // 최대값 초기화
    maxAz = 0.0;
    Serial.println("Sound detected! Measuring for 5 seconds...");
  }

  // 측정 활성화 상태일 때
  if (measuring) {
    int16_t ax, ay, az;
    mpu.getAcceleration(&ax, &ay, &az);

    float ax_g = ax / 16384.0;
    float az_g = az / 16384.0;

    ax_g -= 1.0; // 중력 가속도 제거

    // 최대값 갱신
    if (abs(ax_g) > abs(maxAx)) maxAx = ax_g;
    if (abs(az_g) > abs(maxAz)) maxAz = az_g;

    // 측정 시간(5초)이 지나면 결과 출력
    if (millis() - measurementStartTime >= 5000) { // 5초 경과
      measuring = false; // 측정 종료
      String data = String(maxAx, 2) + "," + String(maxAz, 2);
      BTSerial.println(data);
      Serial.println("Measurement complete. Sending max values:");
      Serial.println(data);
    }
  }
}
