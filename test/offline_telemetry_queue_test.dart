import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chargeease_mobile/services/telemetry/offline_telemetry_queue.dart';

class MockSuccessAdapter implements HttpClientAdapter {
  int requestCount = 0;
  List<Map<String, dynamic>> receivedPayloads = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    if (options.data is Map<String, dynamic>) {
      receivedPayloads.add(options.data as Map<String, dynamic>);
    }
    return ResponseBody.fromString(
      jsonEncode({'status': 'ingested', 'count': 1}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class MockFailureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      error: 'Simulated network offline',
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineTelemetryQueue Persistence Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('enqueue persists payload to disk under offline_telemetry_queue_v1', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockFailureAdapter(); // Simulate offline
      final queue = OfflineTelemetryQueue(dio, prefs);

      final payload = {
        'vehicle_id': 'v-001',
        'latitude': 28.6139,
        'longitude': 77.2090,
        'soc_pct': 55.0,
      };

      await queue.enqueue(payload);

      expect(queue.queuedCount, 1);
      final rawDisk = prefs.getString(OfflineTelemetryQueue.storageKey);
      expect(rawDisk, isNotNull);
      final decoded = jsonDecode(rawDisk!) as List;
      expect(decoded.length, 1);
      expect(decoded[0]['vehicle_id'], 'v-001');
      expect(decoded[0]['soc_pct'], 55.0);
    });

    test('loadFromDisk restores previously queued payloads on app restart', () async {
      final storedData = [
        {'vehicle_id': 'v-100', 'soc_pct': 42.0},
        {'vehicle_id': 'v-101', 'soc_pct': 41.5},
      ];
      await prefs.setString(
        OfflineTelemetryQueue.storageKey,
        jsonEncode(storedData),
      );

      final dio = Dio();
      final queue = OfflineTelemetryQueue(dio, prefs);

      await queue.loadFromDisk();

      expect(queue.queuedCount, 2);
      expect(queue.queue[0]['vehicle_id'], 'v-100');
      expect(queue.queue[1]['vehicle_id'], 'v-101');
    });

    test('flush drains items on successful HTTP 200/201 and clears storage', () async {
      final mockAdapter = MockSuccessAdapter();
      final dio = Dio();
      dio.httpClientAdapter = mockAdapter;
      final queue = OfflineTelemetryQueue(dio, prefs);

      await queue.enqueue({'vehicle_id': 'v-201', 'soc_pct': 88.0});
      await queue.enqueue({'vehicle_id': 'v-202', 'soc_pct': 87.5});

      expect(queue.queuedCount, 0);
      expect(mockAdapter.requestCount, 2);
      final rawDisk = prefs.getString(OfflineTelemetryQueue.storageKey);
      expect(rawDisk, isNull);
    });

    test('flush retains items on disk when server or network fails', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockFailureAdapter();
      final queue = OfflineTelemetryQueue(dio, prefs);

      await queue.enqueue({'vehicle_id': 'v-301', 'soc_pct': 20.0});
      await queue.enqueue({'vehicle_id': 'v-302', 'soc_pct': 19.5});

      expect(queue.queuedCount, 2);
      final rawDisk = prefs.getString(OfflineTelemetryQueue.storageKey);
      expect(rawDisk, isNotNull);
      final decoded = jsonDecode(rawDisk!) as List;
      expect(decoded.length, 2);
    });

    test('clear removes in-memory queue and removes persisted key', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockFailureAdapter();
      final queue = OfflineTelemetryQueue(dio, prefs);

      await queue.enqueue({'vehicle_id': 'v-401', 'soc_pct': 10.0});
      expect(queue.queuedCount, 1);

      await queue.clear();
      expect(queue.queuedCount, 0);
      expect(prefs.getString(OfflineTelemetryQueue.storageKey), isNull);
    });
  });
}
