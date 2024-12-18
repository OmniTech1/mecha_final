import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key, required this.device});

  final BluetoothDevice device;

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  FlutterBluePlus flutterBlue = FlutterBluePlus();

  String stateText = 'Connecting';
  String connectButtonText = 'Disconnect';
  BluetoothConnectionState deviceState = BluetoothConnectionState.disconnected;
  StreamSubscription<BluetoothConnectionState>? _stateListener;
  List<BluetoothService> bluetoothService = [];

  List<Offset> vectors = []; // 2D 벡터 데이터 저장

  @override
  void initState() {
    super.initState();
    _stateListener = widget.device.connectionState.listen((event) {
      if (deviceState == event) {
        return;
      }
      setBleConnectionState(event);
    });
    connect();

    // 임시 테스트 데이터 추가
    // simulateDataInput();
  }

  @override
  void dispose() {
    _stateListener?.cancel();
    disconnect();
    super.dispose();
  }

  void setBleConnectionState(BluetoothConnectionState event) {
    switch (event) {
      case BluetoothConnectionState.disconnected:
        stateText = 'Disconnected';
        connectButtonText = 'Connect';
        break;
      case BluetoothConnectionState.connected:
        stateText = 'Connected';
        connectButtonText = 'Disconnect';
        break;
      default:
        stateText = 'Unknown State';
        connectButtonText = 'Connect';
        break;
    }
    deviceState = event;
    setState(() {});
  }

  Future<void> connect() async {
    try {
      setState(() {
        stateText = 'Connecting';
      });

      await widget.device.connect(autoConnect: false);

      List<BluetoothService> services = await widget.device.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.properties.notify) {
            subscribeToCharacteristic(c);
          } else {
            debugPrint("not notify");
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to connect: $e');
      setState(() {
        stateText = 'Connection Failed';
      });
    }
  }

  void disconnect() {
    try {
      widget.device.disconnect();
      setState(() {
        stateText = 'Disconnecting';
      });
    } catch (e) {}
  }

  void subscribeToCharacteristic(BluetoothCharacteristic characteristic) async {
    debugPrint("subscribeToCharacteristic");
    if (characteristic.properties.notify) {
      await characteristic.setNotifyValue(true);

      characteristic.onValueReceived.listen((value) {
        final data = String.fromCharCodes(value);
        debugPrint("Received Data: $data");
        processSensorData(data);
      });
    }
  }

  void processSensorData(String data) {
    try {
      List<String> parts = data.split(',');
      double x = double.parse(parts[0]);
      double y = double.parse(parts[1]);

      vectors.add(Offset(x, y));
      debugPrint('New Vector Added: x=$x, y=$y');

      setState(() {});
    } catch (e) {
      debugPrint('Error processing sensor data: $e');
    }
  }

  // void simulateDataInput() {
  //   // 임시 데이터 시뮬레이션
  //   List<String> exampleData = ['1.0,2.0', '-1.5,1.0', '2.0,-2.0', '-3.0,-1.0', '0.5,-1.5'];

  //   for (final data in exampleData) {
  //     processSensorData(data);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.advName),
        centerTitle: true,
      ),
      body: Center(
        child: Stack(
          children: [
            Container(
              color: Colors.white,
              child: CustomPaint(
                size: Size(double.infinity, double.infinity),
                painter: VectorPainter(vectors: vectors, scale: 20.0),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    vectors.clear();
                  });
                },
                child: const Text('초기화'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VectorPainter extends CustomPainter {
  final List<Offset> vectors;
  final double scale;

  VectorPainter({required this.vectors, this.scale = 10.0});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint axisPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0;

    final Paint vectorPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0;

    final Offset center = Offset(size.width / 2, size.height / 2);

    // 축 그리기
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), axisPaint);

    // 벡터 그리기
    for (int i = 0; i < vectors.length; i++) {
      final Offset vector = vectors[i];
      final Offset end = center + Offset(vector.dx * scale, -vector.dy * scale);
      canvas.drawLine(center, end, vectorPaint);
      canvas.drawCircle(end, 4.0, vectorPaint); // 끝점에 원 표시

      // 순서 표시
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: (i + 1).toString(),
          style: TextStyle(color: Colors.red, fontSize: 12.0),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: double.infinity);
      textPainter.paint(canvas, end.translate(5, -5));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
