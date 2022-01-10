import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class RecordScreen extends StatefulWidget {
  final BluetoothCharacteristic characteristic;
  final BluetoothService service;
  final BluetoothDevice device;
  const RecordScreen({Key? key, required this.device, required this.characteristic, required this.service}) : super(key: key);

  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  DocumentReference air_document = FirebaseFirestore.instance.collection("record").doc('first');
  DocumentReference apnea_document = FirebaseFirestore.instance.collection("record").doc('apnea');
  late List<Data> chartData;
  late ChartSeriesController _chartSeriesController;
  bool isRecording = false;
  bool isApnea = false;
  int count = 0;
  double d = 0;

  @override
  void initState() {
    super.initState();
    chartData = getChartData();
    Timer.periodic(const Duration(seconds: 1), updateDataSource);
    initNotification();
    isRecording = false;
    isApnea = false;
    count = 0;
  }

  @override
  void dispose() {
    isRecording = false;
    isApnea = false;
    count = 0;
    flutterLocalNotificationsPlugin.cancelAll();
    super.dispose();
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
    return Scaffold(
      appBar: AppBar(
        title: Text('측정')
      ),
      body: SingleChildScrollView(
        child: Column(
        children: <Widget>[
          Text('Service: 0x${widget.service.uuid.toString().toUpperCase().substring(4, 8)}'),
          StreamBuilder<List<int>>(
            stream: widget.characteristic.value,
            initialData: [],
            builder: (c, snapshot) {
              if(snapshot.hasError) return Text('Error :${snapshot.error}');
              if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
              final value = snapshot.data!;
              String val = ascii.decode(value);
              d = asciiToDouble(value);
              if(d <1.0) {
                count++;
              } else {
                count = 0;
              }
              if(count > 30) {
                showNotification(count);
              } else if (count>20) {
                if(count%2 == 0) showNotification(count);
              } else if (count >= 10) {
                if(count%5 == 0) showNotification(count);
              }
              //print(double.parse(val));
              //air_document.collection("data").add({'time': DateTime.now().toString(), 'value': val});
              return Column(
                  children: [
                    Text(value.toString()),
                    ElevatedButton(
                        child: Text(isRecording ? '측정종료' : '측정시작'),
                        onPressed: () => isRecording ? stopRecording(widget.characteristic): startRecording(widget.characteristic)
                    ),
                    Text(d < 1.0? '호흡없음' : '호흡중'),
                    Text('호흡없는 상태 $count 초'),
                    Text(val),
                    Text(asciiToDouble(value).toString()),
                  ]
              );
            },
          ),

          _buildGraph(context)
        ],
      ),
      )
    );
  }

  double asciiToDouble(List<int> v) {
    double d = 0;
    if(v.length == 6) {
      d = (v[0]-48)+(v[2]-48)*0.1+(v[3]-48)*0.01;
    } else if (v.length == 7) {
      d = (v[0]-48)*10+(v[1]-48)+(v[3]-48)*0.1+(v[4]-48)*0.01;
    } else if (v.length == 8) {
      d = (v[0]-48)*100+(v[1]-48)*10+(v[2-48])*1+(v[4]-48)*0.1+(v[5]-48)*0.01;
    }
    print(d.toString());
    return d;
  }

  /// startRecording:
  /// 1. 아두이노로부터 전달되는 데이터실시간으로 읽어옴
  /// 1-1. 읽어온 데이터를 가공하여 무호흡 상태를 판별함
  /// 2. Document를 생성하고 실시간 데이터를 firebase에 저장함
  /// 2-2. 무호흡상태가 있으면 이를 firebase에 저장함 (무호흡은 하나의 Record에 저장해고 관계 없음)
  /// 3. 그래프를 그리기 시작함

  void startRecording(BluetoothCharacteristic characteristic) async {
    isRecording = true;
    await characteristic.setNotifyValue(true);
    count = 0;
  }

  void stopRecording(BluetoothCharacteristic characteristic) async {
    isRecording = false;
    await characteristic.setNotifyValue(false);
    dispose();
    Navigator.of(context).pop();
  }


  // 그래프
  Widget _buildGraph(BuildContext context) {
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
            intervalType: DateTimeIntervalType.auto// TODO: 간격이 5초~10초정도로 잡히는데 60초로 늘릴것
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
      Data(DateTime.now().add(Duration(seconds:0)), 1.0),
      Data(DateTime.now().add(Duration(seconds:1)), 1.0),
      Data(DateTime.now().add(Duration(seconds:2)), 1.0),
      Data(DateTime.now().add(Duration(seconds:3)), 1.0),
      Data(DateTime.now().add(Duration(seconds:4)), 1.0)

    ];
  }
}



class Data {
  Data(this.time, this.val);

  final DateTime time;
  final double val;
}

