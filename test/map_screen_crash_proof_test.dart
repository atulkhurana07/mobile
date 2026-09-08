import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

import 'package:chargeease_mobile/features/map/presentation/map_screen.dart';
import 'package:chargeease_mobile/features/vehicle/providers/vehicle_provider.dart';
import 'package:chargeease_mobile/features/vehicle/models/vehicle_model.dart';
import 'package:chargeease_mobile/features/vehicle/repositories/vehicle_repository.dart';
import 'package:chargeease_mobile/features/map/providers/map_provider.dart';
import 'package:chargeease_mobile/features/map/repositories/charging_repository.dart';

class _MockEmptyVehicleRepo extends VehicleRepository {
  _MockEmptyVehicleRepo() : super(Dio());
}

class _MockVehicleNotifier extends ActiveVehicleNotifier {
  _MockVehicleNotifier(ActiveVehicleState initialState)
      : super(_MockEmptyVehicleRepo(), null) {
    state = initialState;
  }

  @override
  Future<void> loadVehicle() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  final standardVehicle = VehicleModel(
    id: 'veh-001',
    vehicleCode: 'DL-01-EV-2024',
    vehicleType: 'electric_bus',
    departmentId: 'dept-transit',
    isActive: true,
    latitude: 28.6139,
    longitude: 77.2090,
    speedKph: 35.0,
    headingDeg: 120.0,
    socPct: 68.0,
    estimatedRangeKm: 120.0,
    charging: false,
    connectivityStatus: 'online',
    lastSeen: DateTime.now().toUtc(),
  );

  // Station positioned south of center (28.6050, 77.2090) so it is not obscured by the top HUD
  final standardChargingCenter = ChargingCenterModel(
    id: 'hub-01',
    name: 'Connaught Place Fast Charging Hub',
    latitude: 28.6050,
    longitude: 77.2090,
    powerKw: 150.0,
    connectors: {
      'fast_dc': true,
      'CCS2': 4,
      'Type2': 2,
    },
  );

  group('MapScreen Empirical Crash-Proof Tests', () {
    testWidgets('1. Handles completely null vehicle state gracefully without crash', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.initial()),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value(<ChargingCenterModel>[]),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value(<Map<String, dynamic>>[]),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Navigation & Charging'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('No active vehicle selected'), findsOneWidget);
      expect(find.text('DL-01-EV-2024'), findsNothing);

      // Recenter button with null vehicle
      await tester.tap(find.byTooltip('Recenter on Vehicle'));
      await tester.pumpAndSettle();

      // Zoom controls with null vehicle
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      // Refresh button
      await tester.tap(find.byTooltip('Refresh Data'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Handles vehicle with all null telemetry metrics without crash', (tester) async {
      const nullTelemetryVehicle = VehicleModel(
        id: 'veh-null',
        vehicleCode: 'DL-99-TEST',
        vehicleType: 'utility_ev',
        departmentId: 'dept-null',
        isActive: true,
        latitude: null,
        longitude: null,
        speedKph: null,
        headingDeg: null,
        socPct: null,
        estimatedRangeKm: null,
        charging: null,
        connectivityStatus: null,
        lastSeen: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.data(nullTelemetryVehicle)),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value(<ChargingCenterModel>[]),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value(<Map<String, dynamic>>[]),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DL-99-TEST'), findsOneWidget);
      expect(find.text('Lat: ---  Lng: ---'), findsOneWidget);
      expect(find.text('0 km/h'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('0 km'), findsOneWidget);
      expect(find.text('IDLE'), findsOneWidget);

      await tester.tap(find.byTooltip('Recenter on Vehicle'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('3a. Zero waypoints with null vehicle: PolylineLayer is omitted', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.initial()),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value(<ChargingCenterModel>[]),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value(<Map<String, dynamic>>[]),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PolylineLayer), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3b. Single waypoint with null vehicle: trailPoints length is 1, PolylineLayer is omitted', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.initial()),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value(<ChargingCenterModel>[]),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value([
                {'latitude': 28.6250, 'longitude': 77.2205},
              ]),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Only 1 point: polyline cannot form, so PolylineLayer must NOT render
      expect(find.byType(PolylineLayer), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3c. Zero track waypoints with active vehicle: trailPoints has only vehicle, PolylineLayer is omitted', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.data(standardVehicle)),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value(<ChargingCenterModel>[]),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value(<Map<String, dynamic>>[]),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Only vehicleLatLng in trailPoints -> length is 1 -> PolylineLayer omitted
      expect(find.byType(PolylineLayer), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3d. Single track waypoint with active vehicle: trailPoints has 2 points, PolylineLayer renders cleanly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.data(standardVehicle)),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value(<ChargingCenterModel>[]),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value([
                {'latitude': 28.6250, 'longitude': 77.2205},
              ]),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 2 points: 1 track waypoint + vehicle position -> PolylineLayer renders
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Handles malformed and alternate key track history records', (tester) async {
      final malformedTracks = [
        {'lat': 28.6200, 'lng': 77.2100}, // alternate keys
        {'latitude': null, 'longitude': null}, // null values
        {'invalid_key': 'corrupt_data'}, // missing keys
        {'latitude': 28.6280, 'longitude': 77.2150}, // valid record
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.data(standardVehicle)),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value(<ChargingCenterModel>[]),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value(malformedTracks),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Handles empty charging centers list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.data(standardVehicle)),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value(<ChargingCenterModel>[]),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value(<Map<String, dynamic>>[]),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.ev_station_rounded), findsNothing);
      expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Accurately calculates distance and presents detail sheet on pin tap', (tester) async {
      // Vehicle at (28.6139, 77.2090)
      // Center at (28.6050, 77.2090)
      const distanceCalc = Distance();
      final expectedKm = distanceCalc.as(
        LengthUnit.Kilometer,
        LatLng(standardVehicle.latitude!, standardVehicle.longitude!),
        LatLng(standardChargingCenter.latitude, standardChargingCenter.longitude),
      );
      final expectedDistanceText = '${expectedKm.toStringAsFixed(1)} km away';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.data(standardVehicle)),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value([standardChargingCenter]),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value(<Map<String, dynamic>>[]),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap charging pin
      final pinFinder = find.byIcon(Icons.ev_station_rounded);
      expect(pinFinder, findsOneWidget);
      await tester.tap(pinFinder);
      await tester.pumpAndSettle();

      // Verify detail sheet content
      expect(find.text('Connaught Place Fast Charging Hub'), findsOneWidget);
      expect(find.text('Government Verified Hub'), findsOneWidget);
      expect(find.textContaining(expectedDistanceText), findsOneWidget);
      expect(find.text('150 kW Fast Charger'), findsOneWidget);
      expect(find.text('⚡ Fast DC Supported'), findsOneWidget);
      expect(find.text('CCS2: 4 Plugs'), findsOneWidget);
      expect(find.text('Type2: 2 Plugs'), findsOneWidget);

      // Verify Close button dismisses modal sheet
      await tester.tap(find.text('CLOSE DETAILS'));
      await tester.pumpAndSettle();
      expect(find.text('CLOSE DETAILS'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. Handles pin tap and detail sheet when vehicle is null (no distance crash)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.initial()),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value([standardChargingCenter]),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value(<Map<String, dynamic>>[]),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final pinFinder = find.byIcon(Icons.ev_station_rounded);
      expect(pinFinder, findsOneWidget);
      await tester.tap(pinFinder);
      await tester.pumpAndSettle();

      // Station sheet opens without distance indicator and without crashing
      expect(find.text('Connaught Place Fast Charging Hub'), findsOneWidget);
      expect(find.textContaining('km away'), findsNothing);

      await tester.tap(find.text('CLOSE DETAILS'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Handles charging center with null powerKw, null connectors, and single plug grammar', (tester) async {
      const edgeCaseCenter = ChargingCenterModel(
        id: 'hub-minimal',
        name: 'Depot Slow Point',
        latitude: 28.6050,
        longitude: 77.2090,
        powerKw: null,
        connectors: {
          'Type2': 1, // singular test
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.data(standardVehicle)),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value([edgeCaseCenter]),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value(<Map<String, dynamic>>[]),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.ev_station_rounded));
      await tester.pumpAndSettle();

      // Power fallback
      expect(find.text('Standard Output'), findsOneWidget);

      // Singular connector grammar: "1 Plug" not "1 Plugs"
      expect(find.text('Type2: 1 Plug'), findsOneWidget);

      await tester.tap(find.text('CLOSE DETAILS'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('9. Gracefully handles async provider errors without unhandled exceptions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.error('Vehicle backend network timeout')),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.error(Exception('503 Service Unavailable')),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.error(Exception('Track query failure')),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.text('No active vehicle selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10. Directional vehicle marker heading rotation behaves properly', (tester) async {
      for (final heading in [0.0, 90.0, 180.0, 270.0]) {
        final orientedVehicle = standardVehicle.copyWith(headingDeg: heading);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeVehicleProvider.overrideWith(
                (ref) => _MockVehicleNotifier(ActiveVehicleState.data(orientedVehicle)),
              ),
              publicChargingCentersProvider.overrideWith(
                (ref) => Future.value(<ChargingCenterModel>[]),
              ),
              activeVehicleTrackProvider.overrideWith(
                (ref) => Future.value(<Map<String, dynamic>>[]),
              ),
            ],
            child: const MaterialApp(home: MapScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('11. Stress harness: interactive zooming, recentering, and opening/closing sheets', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockVehicleNotifier(ActiveVehicleState.data(standardVehicle)),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value([standardChargingCenter]),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value([
                {'lat': 28.6100, 'lng': 77.2000},
                {'lat': 28.6139, 'lng': 77.2090},
              ]),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final zoomIn = find.byIcon(Icons.add);
      final zoomOut = find.byIcon(Icons.remove);
      final recenter = find.byIcon(Icons.my_location);
      final pin = find.byIcon(Icons.ev_station_rounded);

      // Perform interactions with pumpAndSettle
      await tester.tap(zoomIn);
      await tester.pumpAndSettle();
      await tester.tap(zoomIn);
      await tester.pumpAndSettle();
      await tester.tap(zoomOut);
      await tester.pumpAndSettle();
      await tester.tap(recenter);
      await tester.pumpAndSettle();
      await tester.tap(pin);
      await tester.pumpAndSettle();

      expect(find.text('CLOSE DETAILS'), findsOneWidget);
      await tester.tap(find.text('CLOSE DETAILS'));
      await tester.pumpAndSettle();

      await tester.tap(recenter);
      await tester.pumpAndSettle();

      // Verify zero red screens or crashes
      expect(tester.takeException(), isNull);
    });
  });
}
