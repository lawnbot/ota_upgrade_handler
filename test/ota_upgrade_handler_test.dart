import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_upgrade_handler/ota_upgrade_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('ota_upgrade_handler');


  setUp(() {
   TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await OtaUpgradeHandler.platformVersion, '42');
  });
}
