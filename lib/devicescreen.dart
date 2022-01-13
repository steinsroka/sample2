import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:sample2/recordscreen.dart';
import 'package:sample2/resultscreen.dart';

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
      body: ListView(
        children: <Widget>[
          _buildBody1(),
          /*
            ListTile(
              title: Text('모든데이터 확인'),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => ResultScreen())),
            ),

             */
          StreamBuilder<List<BluetoothService>>(
              stream: widget.device.services,
              initialData: [],
              builder: (c, snapshot) {
                if (!snapshot.hasData) return const Text('no data yet');
                if (snapshot.hasError) return Text(snapshot.error.toString());
                return Container(
                  child: _buildBody2(context, snapshot.data!),
                );
              }),
        ],
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
          builder: (c, snapshot) => IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => widget.device.discoverServices(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody2(BuildContext context, List<BluetoothService> services) {
    BluetoothService service = services.last;
    BluetoothCharacteristic characteristic = service.characteristics.last;
    for (var s in services) {
      if (s.uuid.toString() == '0000ffe0-0000-1000-8000-00805f9b34fb') {
        service = s;
      }
    }
    for (var c in service.characteristics) {
      if (c.uuid.toString() == '0000ffe1-0000-1000-8000-00805f9b34fb') {
        characteristic = c;
      }
    }
      return StreamBuilder<BluetoothDeviceState>(
        stream: widget.device.state,
        initialData: BluetoothDeviceState.disconnected,
        builder: (c, snapshot) {
          VoidCallback? onTap;
          String text;
          switch (snapshot.data) {
            case BluetoothDeviceState.connected:
              if(service.uuid.toString() != '0000ffe0-0000-1000-8000-00805f9b34fb' ||
                  characteristic.uuid.toString() != '0000ffe1-0000-1000-8000-00805f9b34fb') {
                onTap = null;
                text = '지원하는 기기가 아닙니다';
              }
              onTap = () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => RecordScreen(
                      device: widget.device,
                      service: service,
                      characteristic: characteristic)));
              text = '측정시작';
              break;
            case BluetoothDeviceState.disconnected:
              onTap = null;
              text = '먼저 기기를 연결해주세요';
              break;
            case BluetoothDeviceState.connecting:
              onTap = null;
              text = '기기 연결중...';
              break;

              default:
                onTap = null;
                text = '';
          }
          return ListTile(
            onTap: onTap,
            title: Text(text),
          );
        }
      );
    }
}
