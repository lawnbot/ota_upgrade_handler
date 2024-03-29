import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:ota_upgrade_handler/ota_upgrade_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final String _versionControlResult = "";

  OtaUpgradeStatus currentEvent = OtaUpgradeStatus(
      state: OtaUpgradeState.downloadNotStarted, downloadProgress: 0.0);

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () => initPlatformState());
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion = '';
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await OtaUpgradeHandler.platformVersion;
      print(platformVersion);
      print(await OtaUpgradeHandler.getExternalFilesDir());

      _startNewAppDownload("my_flutter.apk");
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                if (kIsWeb == false && Platform.isAndroid && kReleaseMode)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        "OTA Status: ${_getOtaStatus()}",
                        style: const TextStyle(color: Colors.grey, fontSize: 12.0),
                      ),
                    ],
                  ),
              ],
            ),
          )),
    );
  }

  void _startNewAppDownload(String fileName) async {
    try {
      String downloadUrl = "https://www.mywebsitedownload.com/$fileName";

      print(await OtaUpgradeHandler.getExternalFilesDir());
      String location = await OtaUpgradeHandler.getExternalFilesDir();
      OtaUpgradeHandler.cleanFilesinFolderStartingWith(
          location, "MyAppFileName");
      final otaHandler = OtaUpgradeHandler();

      otaHandler.start(location, downloadUrl);

      otaHandler.streamedOtaUpgradeStatus.listen((event) {
        //print(event.state.toString() +' ' + event.downloadProgress.toInt().toString());
        if (mounted) setState(() => currentEvent = event);
      });
    } catch (e) {
      print('Failed to make OTA update. Details: $e');
    }
  }

  String _getOtaStatus() {
    if (currentEvent.state == OtaUpgradeState.downloadNotStarted) {
      return _versionControlResult;
    }

    switch (currentEvent.state) {
      case OtaUpgradeState.downloading:
        return '${currentEvent.downloadProgress.toInt()}%\n';
      default:
        return currentEvent.state.toString();
    }
  }
}
