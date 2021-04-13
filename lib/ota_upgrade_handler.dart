import 'dart:async';

import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:isolate';

class OtaUpgradeHandler {
  static const MethodChannel _channel =
      const MethodChannel('ota_upgrade_handler');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<String> getExternalFilesDir() async {
    final String filesDir =
        await _channel.invokeMethod('externalFilesDir') ?? '';
    return filesDir;
  }

  static Future<String> installApk(String apkFileName) async {
    final String result =      
        await _channel.invokeMethod('installApk', {'apkFileName': apkFileName});
    return result;
  }

  static void cleanFilesinFolderStartingWith(String path, String fileName) {
    try {
      final dir = Directory(path);
      List<FileSystemEntity> fileSys = dir.listSync(recursive: false);

      List<FileSystemEntity> filesAppointedToDelete = fileSys
          .where((el) =>
              el is File && el.path.split("/").last.startsWith(fileName))
          .toList();

      filesAppointedToDelete.forEach((el) {
        el.deleteSync();
      });
    } catch (e) {
      print('Could not delete the old files of app: ' + fileName);
    }
  }

  List<Isolate> isolates = [];
  final controller = StreamController<OtaUpgradeStatus>();
  Stream<OtaUpgradeStatus> get streamedOtaUpgradeStatus => controller.stream;

  void start(String location, String fullDownloadUri) async {
    if (!fullDownloadUri.contains('/')) {
      return;
    }
    isolates = [];
    ReceivePort receivePort = ReceivePort();
    String fileNameOfDownload = fullDownloadUri.split('/').last;

    controller.sink.add(OtaUpgradeStatus(
        state: OtaUpgradeState.DOWNLOAD_NOT_STARTED, downloadProgress: 0.0));

    var isolatedDownloadParameters = IsolatedDownloadParameters(
        downloadUrl: fullDownloadUri,
        fileDirectory: location,
        fileName: fileNameOfDownload,
        sendPort: receivePort.sendPort);

    // isolates.add(await Isolate.spawn(runAnotherThing, receivePort.sendPort));
    isolates.add(await Isolate.spawn(isolatedDownload,
        isolatedDownloadParameters)); // Just one object can be passed

    receivePort.listen((data) {
      final currStatus = data as OtaUpgradeStatus;
      controller.add(currStatus);
      //print('Data: ${currStatus.downloadProgress}');

      if (currStatus.state == OtaUpgradeState.FINISHED_DOWNLOADING) {
        print("Finished downloading from receive port");
        OtaUpgradeHandler.getExternalFilesDir().then((value) => print(value));
        controller.add(OtaUpgradeStatus(
            state: OtaUpgradeState.INSTALLING, downloadProgress: 100.0));
        OtaUpgradeHandler.installApk(fileNameOfDownload)
            .then((value) => receivePort.close());
        // To trigger the on onDone Method
      }
    }).onDone(() {
      // NEVER finished until receivePort not closed?
      // print("Finished downloading from receive port");
      // OtaUpgradeHandler.getFilesDir().then((value) => print(value));
      // OtaUpgradeHandler.installApk("MobiTransFlut_1.1.50.apk");

      controller.close();
      stop();
    });
  }

  void stop() {
    for (Isolate? i in isolates) {
      // ignore: unnecessary_null_comparison
      if (i != null) {
        i.kill(priority: Isolate.immediate);
        i = null;
        print('Terminated all isolates.');
      }
    }
  }
}

void isolatedDownload(IsolatedDownloadParameters parameters) async {
  var request = await HttpClient().getUrl(Uri.parse(parameters.downloadUrl));
  var response = await request.close();

  String dir = parameters.fileDirectory;
  print(dir);

  List<List<int>> chunks = [];
  int downloaded = 0;

  response.listen((List<int> chunk) {
    // Display download progress
    //print('downloadPercentage: ${downloaded / response.contentLength * 100}');
    // parameters.sendPort.send(
    //     'downloadProgress: ${downloaded / response.contentLength * 100}');
    parameters.sendPort.send(OtaUpgradeStatus(
        state: OtaUpgradeState.DOWNLOADING,
        downloadProgress: downloaded / response.contentLength * 100));

    chunks.add(chunk);
    downloaded += chunk.length;
  }, onDone: () async {
    // Display download progress
    //print('downloadProgress: ${downloaded / response.contentLength * 100}');

    // Save the file
    //File file = new File('$dir/$parameters.filename');
    File file = new File(dir + '/' + parameters.fileName);
    final Uint8List bytes = Uint8List(response.contentLength);
    int offset = 0;
    for (List<int> chunk in chunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    await file.writeAsBytes(bytes);

    // parameters.sendPort.send(
    //     'finishedDownloading: ${downloaded / response.contentLength * 100}');
    parameters.sendPort.send(OtaUpgradeStatus(
        state: OtaUpgradeState.FINISHED_DOWNLOADING,
        downloadProgress: downloaded / response.contentLength * 100));

    return;
  });
}

class IsolatedDownloadParameters {
  String downloadUrl;
  String fileDirectory;
  String fileName;
  SendPort sendPort;

  IsolatedDownloadParameters(
      {required this.downloadUrl,
      required this.fileDirectory,
      required this.fileName,
      required this.sendPort});
}

enum OtaUpgradeState {
  DOWNLOAD_NOT_STARTED,
  DOWNLOADING,
  FINISHED_DOWNLOADING,
  INSTALLING,
  ERROR
}

class OtaUpgradeStatus {
  OtaUpgradeState state = OtaUpgradeState.DOWNLOAD_NOT_STARTED;
  double downloadProgress = 0.0;
  OtaUpgradeStatus({required this.state, required this.downloadProgress});
}
