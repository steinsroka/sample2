import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
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
  late List<Apnea> apneaData;
  late ChartSeriesController _chartSeriesController;
  bool isRecording = false;
  bool isApnea = false;
  int count = 0;
  double d = 0;
  DateTime time = DateTime.now();
  int i = 5;
  int j = 0;
  DateTime apneaStart = DateTime.now();
  DateTime recordStart = DateTime.now();
  DateTime recordEnd = DateTime.now();
  late Duration diff;
  @override
  void initState() {
    super.initState();
    apneaData = getApneaData();
    chartData = getChartData();
    Timer.periodic(const Duration(seconds: 1), updateDataSource);
    initNotification();
    isRecording = false;
    isApnea = false;
    count = 0;
  }

  @override
  void dispose() {
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
                if(isApnea) {
                  apneaData.add(Apnea(++j, apneaStart, DateTime.now()));
                }
                isApnea = false;
              }
              if(count > 30) {
                showNotification(count);
              } else if (count>20) {
                if(count%2 == 0) showNotification(count);
              } else if (count >= 10) {
                if(count%5 == 0) showNotification(count);
                if(!isApnea){
                  apneaStart = DateTime.now();

                }
                isApnea = true;
              }
              //print(double.parse(val));
              //air_document.collection("data").add({'time': DateTime.now().toString(), 'value': val});
              return Column(
                  children: [
                    Text(value.toString()),
                    ElevatedButton(
                        child: isRecording ? Text('측정종료') : Text('측정시작'),
                        onPressed: () {
                          if(isRecording) {
                            stopRecording(widget.characteristic);
                            recordEnd = DateTime.now();
                          } else {
                            startRecording(widget.characteristic);
                            recordStart = DateTime.now();
                          }
                          setState(() {
                            isRecording = !isRecording;
                          });
                        }
                    ),
                    Text(d < 1.0? '호흡없음' : '호흡중'),
                    Text('호흡없는 상태 $count 초'),
                    Text(val),
                    Text(asciiToDouble(value).toString()),
                  ]
              );
            },
          ),

          _buildGraph(context),
          ListTile(
            title: Text('취침시간'),
            subtitle: Text(DateFormat("yyyy-MM-dd HH:mm:ss").format(recordStart) + ' to ' + DateFormat("yyyy-MM-dd HH:mm:ss").format(recordEnd)),
            trailing: Text(recordEnd.difference(recordStart).toString()),
          ),
          _buildApneaList(context)
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

  void startRecording(BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(true);
    count = 0;
  }

  void stopRecording(BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(false);
    count = 0;
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

  Widget _buildApneaList(BuildContext context) {
    return ExpansionTile(
      title: Text('무호흡 데이터'),
      subtitle: Text('무호흡 횟수: $j'),
      children: [ListView.builder(
        shrinkWrap: true,
        itemCount: apneaData.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(apneaData[index].id.toString()),
            subtitle: Text(DateFormat("yyyy-MM-dd HH:mm:ss").format(apneaData[index].start) +
                ' to ' + DateFormat("yyyy-MM-dd HH:mm:ss").format(apneaData[index].end)),
            trailing: Text(apneaData[index].end.difference(apneaData[index].start).toString()),
          );
        },
      )]
    );
  }

  void updateDataSource(Timer timer) {
    chartData.add(Data(time.add(Duration(seconds:i++)), d));
    chartData.removeAt(0);
    _chartSeriesController.updateDataSource(
        addedDataIndex: chartData.length -1, removedDataIndex: 0
    );
  }

  List<Apnea> getApneaData() {return <Apnea> [];}

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

class Apnea {
  Apnea(this.id, this.start, this.end);

  final int id;
  final DateTime start;
  final DateTime end;
}

class Data {
  Data(this.time, this.val);

  final DateTime time;
  final double val;
}

//DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now())