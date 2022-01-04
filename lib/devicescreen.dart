
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
// characteristic uuid: 0000ffe1-0000-1000-8000-00805f9b34fb
// service uuid: 0000ffe0-0000-1000-8000-00805f9b34fb


List<Data> chartData = [];
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({Key? key, required this.device}) : super(key: key);
  final BluetoothDevice device;
/*
  Future _getThingsOnStartup() async {
    await Future.delayed(Duration(seconds: 1));
    initNotification();
  }
  void initNotification() async{
    var androidSetting = AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettings = InitializationSettings(android: androidSetting);
    flutterLocalNotificationsPlugin.initialize(initializationSettings, onSelectNotification: (String? payload) async {
      if(payload != null) {
        debugPrint('notificationPayload: $payload');
      }
    });
  }

  Future<void> _showNotifications() async {
    int groupNotificationCounter = 1;

    const AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        'group channel id',
        'group channel name',
        importance: Importance.max,
        priority: Priority.high
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.show(groupNotificationCounter, 'smart alarm', '숨쉬세요!!!!', notificationDetails);
    groupNotificationCounter++;

  }

 */
  @override
  Widget build(BuildContext context) {
    device.discoverServices();
    return Scaffold(
      appBar: _buildAppbar(context),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            _buildBody1(),
            StreamBuilder<List<BluetoothService>>(
              stream: device.services,
              initialData: [],
              builder: (c, snapshot) {
                if(!snapshot.hasData){
                  return const Text('no data yet');
                } else {
                  return Container(
                    child: _buildBody2(context, snapshot.data!),
                  );
                }

              },
            ),
            _buildBody3(context),
            ElevatedButton(
              onPressed: (){
                print(chartData[0].time);
                }/* =>
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => ResultScreen()
                  )),*/,
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
      title: Text(device.name),
      actions: <Widget>[
        StreamBuilder<BluetoothDeviceState>(
          stream: device.state,
          initialData: BluetoothDeviceState.connecting,
          builder: (c, snapshot) {
            VoidCallback? onPressed;
            String text;
            switch (snapshot.data) {
              case BluetoothDeviceState.connected:
                onPressed = () => device.disconnect();
                text = 'DISCONNECT';
                break;
              case BluetoothDeviceState.disconnected:
                onPressed = () => device.connect();
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
      stream: device.state,
      initialData: BluetoothDeviceState.connecting,
      builder: (c, snapshot) => ListTile(
        leading: (snapshot.data == BluetoothDeviceState.connected)
            ? Icon(Icons.bluetooth_connected)
            : Icon(Icons.bluetooth_disabled),
        title: Text(
            'Device is ${snapshot.data.toString().split('.')[1]}.'),
        subtitle: Text('${device.id}'),
        trailing: StreamBuilder<bool>(
          stream: device.isDiscoveringServices,
          initialData: false,
          builder: (c, snapshot) => IndexedStack(
            index: snapshot.data! ? 1 : 0,
            children: <Widget>[
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () => device.discoverServices(),
              ),
            ],
          ),
        ),
      ),
    );
  }
/*
  // 서비스 필드
  Widget _buildBody2(List<BluetoothService> services) {
    String suuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
    String cuuid = '0000ffe1-0000-1000-8000-00805f9b34fb';
    String r = '';
    for (var s in services) {
      if(s.uuid.toString() == suuid) {
        s.characteristics.forEach((c) async {
          if(c.uuid.toString() == cuuid) {
            await c.setNotifyValue(true);
            c.value.listen((v) {
              r = ascii.decode(v);
              print('\n::::::::::::::::::::::::r\n');
            });
          }
        });
      }
    }
    return Container(
      child:Text(r)
    );
  }
*/
  Widget _buildBody2(BuildContext context, List<BluetoothService> services) {
    bool isRecording = false;
    String val= '';
    int count = 0;
    double d = 0;
    String suuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
    String cuuid = '0000ffe1-0000-1000-8000-00805f9b34fb';
    BluetoothService service = services.last;
    BluetoothCharacteristic characteristic = service.characteristics.last;
    services.forEach((s) {
      if(s.uuid.toString() == suuid) {
        service = s;
      }
    });
    service.characteristics.forEach((c) {
      if(c.uuid.toString() == cuuid) {
        characteristic = c;
      }
    });
    return ListTile(
      title: Column(
        children: <Widget>[
          Text('Service: 0x${service.uuid.toString().toUpperCase().substring(4, 8)}')
        ],
      ),
      subtitle: StreamBuilder<List<int>>(
        stream: characteristic.value,
        initialData: characteristic.lastValue,
        builder: (c, snapshot) {
          final value = snapshot.data;
          return Column(
              children: [
                Text(value.toString()),
                ElevatedButton(
                  child: Text(characteristic.isNotifying? '측정종료' : '측정시작'),
                  onPressed: () async {
                    await characteristic.setNotifyValue(!characteristic.isNotifying);
                    await characteristic.read();
                    DocumentReference? doc = createDoc();
                    if(isRecording == false) { // 기록 시작
                      isRecording = true;
                      characteristic.value.listen((v) async {
                        val = ascii.decode(v);
                        d = double.parse(val);
                        if(d <1.0) {
                          count += 1;
                        } else {
                          count = 0;
                        }
                        if(count > 10) {
                          //_showNotifications();
                        }
                        doc?.collection("data").add({'time': DateTime.now().toString(), 'value': val});
                        chartData.add(Data(DateTime.now(), d));
                        print(chartData.isEmpty);
                        //Record record = Record(time: DateTime.now().toString(), value: val );
                        //print(record.time);
                        //print(record.value);
                      });
                    } else { // 기록 종료
                      isRecording = false;
                      doc = null;
                    }
                  },
                ),
                Text(val),
                Text(d < 1.0? '호흡없음' : '호흡중'),
                Text('호흡없는 상태 $count 초')
              ]
          );
        },
      )
    );
  }

  DocumentReference createDoc() {
    String document_name = DateTime.now().toString();
    print(document_name);// 현재날짜 까지만 가져오기
    DocumentReference document = FirebaseFirestore.instance.collection("record").doc(document_name);
    return document;
  }

  // 그래프
  Widget _buildBody3(BuildContext context) {

    return Container(
      child: SfCartesianChart(
        primaryXAxis: DateTimeAxis(
            minimum: DateTime.now(),
            maximum: DateTime.now().add(const Duration(minutes: 1))
        ),
        series: <ChartSeries>[
          LineSeries<Data, DateTime> (
              dataSource: chartData,
              xValueMapper: (Data data, _) => data.time,
              yValueMapper: (Data data, _) => data.val
          )
        ],
      ),
    );
  }
}

class Data{
  Data(this.time, this.val);
  final DateTime time;
  final double val;
}