import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sample2/resultscreen.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

// characteristic uuid: 0000ffe1-0000-1000-8000-00805f9b34fb
// service uuid: 0000ffe0-0000-1000-8000-00805f9b34fb

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({Key? key, required this.device}) : super(key: key);
  final BluetoothDevice device;

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  DocumentReference document = FirebaseFirestore.instance.collection("record").doc('first');
  bool isButtonActive = false;
  late List<Data> chartData;
  late ChartSeriesController _chartSeriesController;
  double d = 0;

  @override
  void initState() {
    super.initState();
    chartData = getChartData();
    Timer.periodic(const Duration(seconds: 1), updateDataSource);
    initNotification();
    isButtonActive = false;
  }

  void initNotification() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final IOSInitializationSettings initializationSettingsIOS =
        IOSInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: (String? payload) async {
      if (payload != null) {
        debugPrint('notification payload: $payload');
      }
    });
  }

  Future<void> showNotification(int count) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0, '숨쉬세요!!!!', '호흡없는상태 $count초', platformChannelSpecifics,
        payload: 'item x');
  }

  @override
  Widget build(BuildContext context) {
    widget.device.discoverServices();
    return Scaffold(
      appBar: _buildAppbar(context),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            //_buildBody1(),
            StreamBuilder<bool>(
              stream: widget.device.isDiscoveringServices,
              initialData: false,
              builder: (c, snapshot) => IndexedStack(
                index: snapshot.data! ? 1 : 0,
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: () => widget.device.discoverServices(),
                  ),
                ],
              ),
            ),
            _buildBody3(context),
            StreamBuilder<List<BluetoothService>>(
              stream: widget.device.services,
              initialData: [],
              builder: (c, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('no data yet');
                } else {
                  return Container(
                    child: _buildBody2(context, snapshot.data!),
                  );
                }
              },
            ),

            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => ResultScreen())),
              child: Text('모든데이터 확인'),
            ),
          ],
        ),
      ),
    );
  }

  // 앱 바
  AppBar _buildAppbar(BuildContext context) {
    return AppBar(
      title: Text(widget.device.name),
      actions: <Widget>[
        StreamBuilder<BluetoothDeviceState>(
          stream: widget.device.state,
          initialData: BluetoothDeviceState.connecting,
          builder: (c, snapshot) {
            VoidCallback? onPressed;
            String text;
            switch (snapshot.data) {
              case BluetoothDeviceState.connected:
                onPressed = () => widget.device.disconnect();
                text = 'DISCONNECT';
                break;
              case BluetoothDeviceState.disconnected:
                onPressed = () => widget.device.connect();
                text = 'CONNECT';
                break;
              default:
                onPressed = null;
                text = snapshot.data.toString().substring(21).toUpperCase();
                break;
            }
            return FlatButton(
                onPressed: onPressed,
                child: Text(
                  text,
                  style: Theme.of(context)
                      .primaryTextTheme
                      .button
                      ?.copyWith(color: Colors.white),
                ));
          },
        )
      ],
    );
  }

  // 앱 연결상태
  Widget _buildBody1() {
    return StreamBuilder<BluetoothDeviceState>(
      stream: widget.device.state,
      initialData: BluetoothDeviceState.connecting,
      builder: (c, snapshot) => ListTile(
        leading: (snapshot.data == BluetoothDeviceState.connected)
            ? const Icon(Icons.bluetooth_connected)
            : const Icon(Icons.bluetooth_disabled),
        title: Text('Device is ${snapshot.data.toString().split('.')[1]}.'),
        trailing: StreamBuilder<bool>(
          stream: widget.device.isDiscoveringServices,
          initialData: false,
          builder: (c, snapshot) => IndexedStack(
            index: snapshot.data! ? 1 : 0,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => widget.device.discoverServices(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool isRecording = false;
  String val= '';
  int count = 0;
  Widget _buildBody2(BuildContext context, List<BluetoothService> services) {
    //double d = 0;
    String suuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
    String cuuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

    BluetoothService service = services.last;
    BluetoothCharacteristic characteristic = service.characteristics.last;
    for (var s in services) {
      if(s.uuid.toString() == suuid) {
        service = s;
      }
    }
    for (var c in service.characteristics) {
      if(c.uuid.toString() == cuuid) {
        characteristic = c;
      }
    }
    return Column(
          children: <Widget>[
            Text('Service: 0x${service.uuid.toString().toUpperCase().substring(4, 8)}'),
            StreamBuilder<List<int>>(
              stream: characteristic.value,
              initialData: characteristic.lastValue,
              builder: (c, snapshot) {
                if(snapshot.hasError) return Text('Error :${snapshot.error}');
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                    return const Text('Select lot');
                  case ConnectionState.waiting:
                    return const Text('Awaiting bids...');
                  case ConnectionState.active:

                    final value = snapshot.data;
                    return Column(
                      children: [
                        Text(value.toString()),
                        ElevatedButton(
                          child: Text(characteristic.isNotifying? '측정종료' : '측정시작'),
                          onPressed: () => startRecording(characteristic)
                        ),
                        Text(d < 1.0? '호흡없음' : '호흡중'),
                        Text('호흡없는 상태 $count 초'),
                        Text(val),
                      ]
                  );
                  case ConnectionState.done:
                    return Text('${snapshot.data} closed');
                }

              },
            )
          ],
    );
  }
  
  /// startRecording: 
  /// 1. 아두이노로부터 전달되는 데이터실시간으로 읽어옴
  /// 1-1. 읽어온 데이터를 가공하여 무호흡 상태를 판별함
  /// 2. Document를 생성하고 실시간 데이터를 firebase에 저장함
  /// 2-2. 무호흡상태가 있으면 이를 firebase에 저장함 (무호흡은 하나의 Record에 저장해고 관계 없음)
  /// 3. 그래프를 그리기 시작함
  void startRecording(BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(!characteristic.isNotifying);
    await characteristic.read();
    if(isRecording == false) { // 기록 시작
      isRecording = true;
      characteristic.value.listen((v) async {
        val = ascii.decode(v);
        d = double.parse(val);
        if(d <1.0) {
          count++;
        } else {
          count = 0;
        }
        if(count > 10) {
          showNotification(count);
        }
        document.collection("data").add({'time': DateTime.now().toString(), 'value': val});
        //Record record = Record(time: DateTime.now().toString(), value: val );
      });
    } else { // 기록 종료
      isRecording = false;
      count = 0;
      widget.device.discoverServices();
    }
  }
  
  /// 1. 실시간으로 받아오는 데이터를 무시한다
  /// 1-1. 각종 변수 초기화
  /// 2. firebase document와의 연결을 해제
  /// 3. 그래프 그리기 종료
  void endRecording() {
    
  }

  // 그래프
  Widget _buildBody3(BuildContext context) {
    return SfCartesianChart(
      series: <LineSeries<Data, DateTime>>[
        LineSeries<Data, DateTime>(
          onRendererCreated: (ChartSeriesController controller){
            _chartSeriesController = controller;
          },
          dataSource: chartData,
          xValueMapper: (Data data, _) => data.time,
          yValueMapper: (Data data, _) => data.val)
      ],
      primaryXAxis: DateTimeAxis(
          intervalType: DateTimeIntervalType.seconds // TODO: 간격이 5초~10초정도로 잡히는데 60초로 늘릴것
      )
    );
  }

  DateTime time = DateTime.now();
  int i = 5;
  void updateDataSource(Timer timer) {
    chartData.add(Data(time.add(Duration(seconds:i++)), d));
    chartData.removeAt(0);
    _chartSeriesController.updateDataSource(
      addedDataIndex: chartData.length -1, removedDataIndex: 0
    );
  }

  List<Data> getChartData() {
    return <Data> [


    ];
  }
}

class Data {
  Data(this.time, this.val);

  final DateTime time;
  final double val;
}
