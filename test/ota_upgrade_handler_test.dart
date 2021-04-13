import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_upgrade_handler/ota_upgrade_handler.dart';

void main() {
  const MethodChannel channel = MethodChannel('ota_upgrade_handler');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await OtaUpgradeHandler.platformVersion, '42');
  });
}
