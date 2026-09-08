import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chargeease_mobile/core/storage/local_storage.dart';
import 'package:chargeease_mobile/services/telemetry/offline_telemetry_queue.dart';
import 'package:chargeease_mobile/features/simulator/providers/pitch_simulator_provider.dart';
import 'package:chargeease_mobile/features/alerts/models/alert_model.dart';
import 'package:chargeease_mobile/features/vehicle/providers/vehicle_provider.dart';
import 'package:chargeease_mobile/features/vehicle/models/vehicle_model.dart';
import 'package:chargeease_mobile/features/vehicle/repositories/vehicle_repository.dart';

/// Mock adapter simulating total network offline failure with DioException
class MockOfflineFailureAdapter implements HttpClientAdapter {
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    throw DioException(
      requestOptions: options,
      error: 'Simulated connection drop',
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Mock adapter throwing a non-Dio raw exception
class MockRawExceptionAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw Exception('Unexpected OS socket breakdown');
  }

  @override
  void close({bool force = false}) {}
}

/// Mock adapter that succeeds for [succeedFirstN] calls then throws DioException
class MockPartialFailureAdapter implements HttpClientAdapter {
  final int succeedFirstN;
  int currentCall = 0;
  List<Map<String, dynamic>> processedPayloads = [];

  MockPartialFailureAdapter({required this.succeedFirstN});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    currentCall++;
    if (currentCall <= succeedFirstN) {
      if (options.data is Map<String, dynamic>) {
        processedPayloads.add(options.data as Map<String, dynamic>);
      }
      return ResponseBody.fromString(
        jsonEncode({'status': 'ingested', 'id': currentCall}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    throw DioException(
      requestOptions: options,
      error: 'Simulated partial connection loss',
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Mock adapter returning specific HTTP status codes
class MockHttpStatusAdapter implements HttpClientAdapter {
  final int statusCode;
  int requestCount = 0;

  MockHttpStatusAdapter(this.statusCode);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    return ResponseBody.fromString(
      jsonEncode({'detail': 'HTTP  response'}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Mock adapter with simulated latency
class MockDelayedSuccessAdapter implements HttpClientAdapter {
  final Duration delay;
  int requestCount = 0;
  List<Map<String, dynamic>> receivedPayloads = [];

  MockDelayedSuccessAdapter({this.delay = const Duration(milliseconds: 5)});

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
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    return ResponseBody.fromString(
      jsonEncode({'status': 'ingested'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Test vehicle repository providing a test vehicle
class StubVehicleRepository implements VehicleRepository {
  final VehicleModel vehicle;

  StubVehicleRepository(this.vehicle);

  @override
  Future<List<VehicleModel>> getVehicles() async => [vehicle];

  @override
  Future<VehicleModel> getVehicleById(String id) async => vehicle;

  @override
  Future<List<Map<String, dynamic>>> getVehicleTrack(
    String vehicleId, {
    int limit = 100,
  }) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineTelemetryQueue Adversarial & Stress Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Corrupted SharedPreferences - Malformed JSON string gracefully ignored and recovers on next enqueue', () async {
      // 1. Seed malformed JSON into disk
      await prefs.setString(
        OfflineTelemetryQueue.storageKey,
        '{corrupted_json: [invalid, unclosed, ',
      );

      final dio = Dio();
      dio.httpClientAdapter = MockOfflineFailureAdapter();
      final queue = OfflineTelemetryQueue(dio, prefs);

      // 2. Call loadFromDisk - must not throw FormatException
      await queue.loadFromDisk();
      expect(queue.queuedCount, 0);
      expect(queue.isInitialized, isTrue);

      // 3. Enqueue new item - must recover and write valid JSON to disk
      await queue.enqueue({
        'vehicle_id': 'v-recovery-01',
        'soc_pct': 50.0,
      });

      expect(queue.queuedCount, 1);
      final raw = prefs.getString(OfflineTelemetryQueue.storageKey);
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List;
      expect(decoded.length, 1);
      expect(decoded[0]['vehicle_id'], 'v-recovery-01');
    });

    test('Corrupted SharedPreferences - Top-level JSON Object instead of List does not crash', () async {
      // Seed JSON object
      await prefs.setString(
        OfflineTelemetryQueue.storageKey,
        jsonEncode({'vehicle_id': 'invalid_root_type'}),
      );

      final dio = Dio();
      dio.httpClientAdapter = MockOfflineFailureAdapter();
      final queue = OfflineTelemetryQueue(dio, prefs);

      await queue.loadFromDisk();
      expect(queue.queuedCount, 0);
      expect(queue.isInitialized, isTrue);
    });

    test('Corrupted SharedPreferences - List containing primitives and nulls extracts only valid Maps', () async {
      // Seed list with mixed invalid elements
      final corruptedList = [
        12345,
        'a string element',
        null,
        true,
        {'vehicle_id': 'v-valid-item', 'soc_pct': 77.5},
        [1, 2, 3],
      ];
      await prefs.setString(
        OfflineTelemetryQueue.storageKey,
        jsonEncode(corruptedList),
      );

      final dio = Dio();
      dio.httpClientAdapter = MockOfflineFailureAdapter();
      final queue = OfflineTelemetryQueue(dio, prefs);

      await queue.loadFromDisk();
      expect(queue.queuedCount, 1);
      expect(queue.queue.first['vehicle_id'], 'v-valid-item');
      expect(queue.queue.first['soc_pct'], 77.5);
    });

    test('Rapid burst enqueuing under offline condition retains all 50 items with zero data loss', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockOfflineFailureAdapter();
      final queue = OfflineTelemetryQueue(dio, prefs);
      await queue.loadFromDisk(); // Pre-initialize queue to test burst enqueuing

      const count = 50;
      final futures = List.generate(count, (i) {
        return queue.enqueue({
          'index': i,
          'vehicle_id': 'v-burst-',
          'soc_pct': 50.0 - (i * 0.5),
        });
      });

      await Future.wait(futures);

      expect(queue.queuedCount, count);

      // Verify SharedPreferences persistence
      final raw = prefs.getString(OfflineTelemetryQueue.storageKey);
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List;
      expect(decoded.length, count);

      // Verify strict sequential FIFO ordering and content integrity
      for (int i = 0; i < count; i++) {
        expect(decoded[i]['index'], i);
        expect(decoded[i]['vehicle_id'], 'v-burst-');
      }
    });

    test('Concurrent burst enqueue before initialization preserves all elements without dropping entries', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockOfflineFailureAdapter();
      final queue = OfflineTelemetryQueue(dio, prefs);
      // Intentionally NOT calling loadFromDisk() to test cold-start concurrency

      const count = 50;
      final futures = List.generate(count, (i) {
        return queue.enqueue({
          'index': i,
          'vehicle_id': 'v-cold-',
        });
      });

      await Future.wait(futures);

      // Verify all 50 items are captured
      expect(queue.queuedCount, count);
      final raw = prefs.getString(OfflineTelemetryQueue.storageKey);
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List;
      expect(decoded.length, count);

      // Verify all indices 0..49 exist (set completeness: no duplicates, no dropped entries)
      final indices = decoded.map((e) => e['index'] as int).toSet();
      expect(indices.length, count);
      for (int i = 0; i < count; i++) {
        expect(indices.contains(i), isTrue);
      }
    });

    test('Burst enqueuing with asynchronous network latency drains cleanly without concurrent modification exceptions', () async {
      final mockAdapter = MockDelayedSuccessAdapter(
        delay: const Duration(milliseconds: 2),
      );
      final dio = Dio();
      dio.httpClientAdapter = mockAdapter;
      final queue = OfflineTelemetryQueue(dio, prefs);

      const count = 25;
      final futures = List.generate(count, (i) {
        return queue.enqueue({
          'seq': i,
          'vehicle_id': 'v-async-',
        });
      });

      await Future.wait(futures);

      // After all burst enqueue futures finish, all items are flushed
      expect(queue.queuedCount, 0);
      expect(mockAdapter.requestCount, count);
      expect(prefs.getString(OfflineTelemetryQueue.storageKey), isNull);
    });

    test('Partial network failure halts flush and retains remaining items on disk with isFlushing reset', () async {
      final partialAdapter = MockPartialFailureAdapter(succeedFirstN: 2);
      final dio = Dio();
      dio.httpClientAdapter = partialAdapter;
      final queue = OfflineTelemetryQueue(dio, prefs);

      // Pre-populate queue with 5 items directly on disk
      final initialData = List.generate(5, (i) => {'id': i, 'soc': 90 - i});
      await prefs.setString(
        OfflineTelemetryQueue.storageKey,
        jsonEncode(initialData),
      );

      await queue.loadFromDisk();
      expect(queue.queuedCount, 5);

      // Flush: first 2 succeed, 3rd fails
      await queue.flush();

      // Remaining items must be 3
      expect(queue.queuedCount, 3);
      expect(queue.isFlushing, isFalse);
      expect(partialAdapter.currentCall, 3); // 2 successes + 1 failed attempt

      // Disk must contain exactly the 3 remaining items: id 2, 3, 4
      final raw = prefs.getString(OfflineTelemetryQueue.storageKey);
      expect(raw, isNotNull);
      final remainingOnDisk = jsonDecode(raw!) as List;
      expect(remainingOnDisk.length, 3);
      expect(remainingOnDisk[0]['id'], 2);
      expect(remainingOnDisk[1]['id'], 3);
      expect(remainingOnDisk[2]['id'], 4);

      // Now switch adapter to full success and flush remaining
      dio.httpClientAdapter = MockDelayedSuccessAdapter(delay: Duration.zero);
      await queue.flush();

      expect(queue.queuedCount, 0);
      expect(queue.isFlushing, isFalse);
      expect(prefs.getString(OfflineTelemetryQueue.storageKey), isNull);
    });

    test('Non-Dio exception during flush does not crash and leaves queue intact', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockRawExceptionAdapter();
      final queue = OfflineTelemetryQueue(dio, prefs);

      await queue.enqueue({'vehicle_id': 'v-raw-exc', 'soc_pct': 80.0});

      expect(queue.queuedCount, 1);
      expect(queue.isFlushing, isFalse);
      final raw = prefs.getString(OfflineTelemetryQueue.storageKey);
      expect(raw, isNotNull);
    });

    test('Server HTTP 500 and HTTP 429 errors stop flush loop without discarding unsent data', () async {
      // Test HTTP 500
      final adapter500 = MockHttpStatusAdapter(500);
      final dio500 = Dio();
      dio500.httpClientAdapter = adapter500;
      final queue500 = OfflineTelemetryQueue(dio500, prefs);

      await queue500.enqueue({'vehicle_id': 'v-500', 'val': 1});
      expect(queue500.queuedCount, 1);
      expect(queue500.isFlushing, isFalse);
      expect(adapter500.requestCount, 1);

      // Test HTTP 429
      final adapter429 = MockHttpStatusAdapter(429);
      final dio429 = Dio();
      dio429.httpClientAdapter = adapter429;
      final queue429 = OfflineTelemetryQueue(dio429, prefs);

      await queue429.enqueue({'vehicle_id': 'v-429', 'val': 2});
      expect(queue429.queuedCount, 2); // includes v-500 and v-429
      expect(queue429.isFlushing, isFalse);
    });

    test('Empty queue flushes are no-ops and safe for concurrent calls', () async {
      final mockAdapter = MockDelayedSuccessAdapter();
      final dio = Dio();
      dio.httpClientAdapter = mockAdapter;
      final queue = OfflineTelemetryQueue(dio, prefs);

      // Multiple simultaneous flushes on empty queue
      await Future.wait([
        queue.flush(),
        queue.flush(),
        queue.flush(),
      ]);

      expect(mockAdapter.requestCount, 0);
      expect(queue.isFlushing, isFalse);
      expect(queue.queuedCount, 0);

      // Clear on empty queue is safe
      await queue.clear();
      expect(queue.queuedCount, 0);
      expect(prefs.getString(OfflineTelemetryQueue.storageKey), isNull);
    });
  });

  group('PitchSimulatorNotifier Adversarial & Stress Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Rapid start / stop toggling stress maintains consistent state and timer hygiene', () {
      final notifier = container.read(pitchSimulatorProvider.notifier);

      // 100 rapid sequential toggles
      for (int i = 0; i < 100; i++) {
        notifier.toggle();
      }

      // Even number of toggles should return to initial isRunning = false
      expect(container.read(isPitchSimulatorRunningProvider), isFalse);

      // Rapid successive start calls (idempotent guard)
      notifier.start();
      notifier.start();
      notifier.start();
      expect(container.read(isPitchSimulatorRunningProvider), isTrue);

      // Rapid successive stop calls (idempotent guard)
      notifier.stop();
      notifier.stop();
      notifier.stop();
      expect(container.read(isPitchSimulatorRunningProvider), isFalse);
    });

    test('Boundary SoC crossings: triggers alert at <10% and CLEARS alert when looping back to >=10%', () {
      final notifier = container.read(pitchSimulatorProvider.notifier);
      final waypoints = notifier.waypoints;

      // Verify initial state: 18.0% SoC (Index 0) -> No alert
      expect(waypoints[0].socPct, 18.0);
      expect(container.read(pitchSimulatorAlertProvider), isNull);

      // Step 1: Janpath Road (15.0% SoC) -> No alert
      notifier.step();
      expect(container.read(pitchSimulatorProvider).currentStepIndex, 1);
      expect(container.read(pitchSimulatorAlertProvider), isNull);

      // Step 2: Kartavya Path (12.0% SoC) -> No alert
      notifier.step();
      expect(container.read(pitchSimulatorProvider).currentStepIndex, 2);
      expect(container.read(pitchSimulatorAlertProvider), isNull);

      // Step 3: India Gate (9.5% SoC) -> Alert TRIGGERED (SoC < 10%)
      notifier.step();
      expect(container.read(pitchSimulatorProvider).currentStepIndex, 3);
      final alertStep3 = container.read(pitchSimulatorAlertProvider);
      expect(alertStep3, isNotNull);
      expect(alertStep3!.alertType, 'LOW_SOC');
      expect(alertStep3.severity, 'critical');
      expect(alertStep3.metadata?['soc_pct'], 9.5);

      // Step 4: Pragati Maidan (8.0% SoC) -> Alert remains active
      notifier.step();
      expect(container.read(pitchSimulatorProvider).currentStepIndex, 4);
      expect(container.read(pitchSimulatorAlertProvider), isNotNull);

      // Step 5: Supreme Court (7.0% SoC) -> Alert remains active
      notifier.step();
      expect(container.read(pitchSimulatorProvider).currentStepIndex, 5);
      expect(container.read(pitchSimulatorAlertProvider), isNotNull);

      // CRITICAL BOUNDARY TEST: Step 6 wraps around back to Index 0 (Connaught Place, 18.0% SoC)
      // Since 18.0% is >= 10.0%, activeAlert MUST BE CLEARED (null)!
      notifier.step();
      final loopState = container.read(pitchSimulatorProvider);
      expect(loopState.currentStepIndex, 0);
      expect(loopState.currentWaypoint.socPct, 18.0);
      expect(loopState.activeAlert, isNull,
          reason: 'Alert must be cleared when vehicle SoC returns to normal (>= 10%)');
      expect(container.read(pitchSimulatorAlertProvider), isNull);
    });

    test('StateNotifier listener notification counts are discrete and free of notification storms', () async {
      final notifier = container.read(pitchSimulatorProvider.notifier);
      int simulatorStateChangeCount = 0;
      int alertStateChangeCount = 0;

      container.listen<PitchSimulatorState>(
        pitchSimulatorProvider,
        (previous, next) {
          simulatorStateChangeCount++;
        },
      );

      container.listen<AlertModel?>(
        pitchSimulatorAlertProvider,
        (previous, next) {
          alertStateChangeCount++;
        },
      );

      // Each step produces 2 notifications on pitchSimulatorProvider:
      // (1: waypoint step update, 2: activeAlert update in _applyCurrentWaypoint)
      notifier.step();
      await pumpEventQueue();
      expect(simulatorStateChangeCount, 2);
      // SoC changed from 18% to 15%, so alert remained null -> 0 alert notifications
      expect(alertStateChangeCount, 0);

      // Step to index 2 (12%) -> 2 more notifications on pitchSimulatorProvider
      notifier.step();
      await pumpEventQueue();
      expect(simulatorStateChangeCount, 4);
      expect(alertStateChangeCount, 0);

      // Step to index 3 (9.5% -> alert created)
      notifier.step();
      await pumpEventQueue();
      expect(simulatorStateChangeCount, 6);
      expect(alertStateChangeCount, 1); // alert fired exactly once
    });

    test('ActiveVehicleState receives telemetry updates via vehicle notifier applyTelemetryUpdate', () async {
      final testVehicle = VehicleModel(
        id: 'dl-01-ev-sim',
        vehicleCode: 'DL-01-EV-SIM',
        vehicleType: 'bus',
        departmentId: 'dept-delhi-01',
        isActive: true,
        latitude: 28.6000,
        longitude: 77.2000,
        speedKph: 0.0,
        headingDeg: 0.0,
        socPct: 100.0,
        estimatedRangeKm: 220.0,
        charging: false,
        connectivityStatus: 'online',
        lastSeen: DateTime.now().toUtc(),
      );

      final customContainer = ProviderContainer(
        overrides: [
          vehicleRepositoryProvider.overrideWithValue(StubVehicleRepository(testVehicle)),
          localStorageProvider.overrideWithValue(LocalStorage()),
        ],
      );

      // Select vehicle and load it into active vehicle notifier
      await customContainer.read(selectedVehicleIdProvider.notifier).selectVehicle('dl-01-ev-sim');
      await customContainer.read(activeVehicleProvider.notifier).loadVehicle();
      expect(customContainer.read(activeVehicleProvider).vehicle, isNotNull);

      final notifier = customContainer.read(pitchSimulatorProvider.notifier);

      // Step to index 1 (Janpath Road: lat 28.6250, lng 77.2205, speed 42.0, soc 15.0)
      notifier.step();

      final updatedState = customContainer.read(activeVehicleProvider);
      expect(updatedState.vehicle, isNotNull);
      final v = updatedState.vehicle!;
      expect(v.latitude, 28.6250);
      expect(v.longitude, 77.2205);
      expect(v.speedKph, 42.0);
      expect(v.headingDeg, 172.0);
      expect(v.socPct, 15.0);
      expect(v.estimatedRangeKm, 15.0 * 2.2);

      customContainer.dispose();
    });

    test('Disposing simulator while active cancels timer safely without exceptions', () {
      final localContainer = ProviderContainer();
      final localNotifier = localContainer.read(pitchSimulatorProvider.notifier);

      localNotifier.start();
      expect(localContainer.read(isPitchSimulatorRunningProvider), isTrue);

      // Disposing container cancels all subscriptions and notifiers
      expect(() => localContainer.dispose(), returnsNormally);
    });
  });
}
