import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performance_optimization/performance/data/perf_repository.dart';
import 'package:performance_optimization/performance/perf_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repositoryChannel = MethodChannel('test/performance_repository');
  const perfChannel = MethodChannel('cyberguard/performance');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(repositoryChannel, null);
    messenger.setMockMethodCallHandler(perfChannel, null);
  });

  test('repository converts native-style maps and preserves null responses', () async {
    final nativeMap = <Object?, Object?>{
      'id': 7,
      'timestamp': 1700000000000,
      'batteryPct': 81,
    };

    messenger.setMockMethodCallHandler(repositoryChannel, (call) async {
      if (call.method == 'collectSampleNow' ||
          call.method == 'getLatestSample') {
        return nativeMap;
      }
      return null;
    });
    PerfRepository.setChannel(repositoryChannel);

    final sample = await PerfRepository.refreshAndGetLatest();

    expect(sample, isA<Map<String, dynamic>>());
    expect(sample, {
      'id': 7,
      'timestamp': 1700000000000,
      'batteryPct': 81,
    });

    messenger.setMockMethodCallHandler(repositoryChannel, (call) async => null);
    expect(await PerfRepository.getLatestSample(), isNull);
    expect(await PerfRepository.collectSampleNow(), isNull);
  });

  test('PerfChannel converts native-style maps and preserves null responses', () async {
    final nativeMap = <Object?, Object?>{
      'timestamp': 1700000000000,
      'batteryPct': 81,
    };

    messenger.setMockMethodCallHandler(perfChannel, (call) async {
      if (call.method == 'getLatestSample' ||
          call.method == 'collectSampleNow' ||
          call.method == 'getDeviceInfo' ||
          call.method == 'getLiveBatteryRaw') {
        return nativeMap;
      }
      return null;
    });

    expect(await PerfChannel.getLatestSample(), {
      'timestamp': 1700000000000,
      'batteryPct': 81,
    });
    expect(await PerfChannel.collectSampleNow(), {
      'timestamp': 1700000000000,
      'batteryPct': 81,
    });
    expect(await PerfChannel.getDeviceInfo(), {
      'timestamp': 1700000000000,
      'batteryPct': 81,
    });
    expect(await PerfChannel.getLiveBatteryRaw(), {
      'timestamp': 1700000000000,
      'batteryPct': 81,
    });

    messenger.setMockMethodCallHandler(perfChannel, (call) async => null);
    expect(await PerfChannel.getLatestSample(), isNull);
    expect(await PerfChannel.collectSampleNow(), isNull);
    expect(await PerfChannel.getDeviceInfo(), isNull);
    expect(await PerfChannel.getLiveBatteryRaw(), isNull);
  });
}
