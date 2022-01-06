import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sample2/recordscreen.dart';
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


  @override
  void initState() {
    super.initState();
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
              builder: (c, snapshot) =>
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: () => widget.device.discoverServices(),
                ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: widget.device.services,
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
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => ResultScreen())),
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
                  style: Theme
                      .of(context)
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
      builder: (c, snapshot) =>
          ListTile(
            leading: (snapshot.data == BluetoothDeviceState.connected)
                ? const Icon(Icons.bluetooth_connected)
                : const Icon(Icons.bluetooth_disabled),
            title: Text('Device is ${snapshot.data.toString().split('.')[1]}.'),
            trailing: StreamBuilder<bool>(
              stream: widget.device.isDiscoveringServices,
              initialData: false,
              builder: (c, snapshot) =>
                  IndexedStack(
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

  Widget _buildBody2(BuildContext context, List<BluetoothService> services) {
    //double d = 0;
    String suuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
    String cuuid = '0000ffe1-0000-1000-8000-00805f9b34fb';

    BluetoothService service = services.last;
    BluetoothCharacteristic characteristic = service.characteristics.last;
    for (var s in services) {
      if (s.uuid.toString() == suuid) {
        service = s;
      }
    }
    for (var c in service.characteristics) {
      if (c.uuid.toString() == cuuid) {
        characteristic = c;
      }
    }
    return ElevatedButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (context) =>
                RecordScreen(
                    device: widget.device, service: service, characteristic: characteristic))),
        child: Text('측정')
    );
  }
}