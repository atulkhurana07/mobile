import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:chargeease_mobile/features/map/presentation/map_screen.dart';
import 'package:chargeease_mobile/features/vehicle/providers/vehicle_provider.dart';
import 'package:chargeease_mobile/features/vehicle/models/vehicle_model.dart';
import 'package:chargeease_mobile/features/vehicle/repositories/vehicle_repository.dart';
import 'package:chargeease_mobile/features/map/providers/map_provider.dart';
import 'package:chargeease_mobile/features/map/repositories/charging_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapScreen Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    final testVehicle = VehicleModel(
      id: 'v-test-01',
      vehicleCode: 'DL-01-EV-2024',
      vehicleType: 'electric_bus',
      departmentId: 'dept-001',
      isActive: true,
      latitude: 28.6139,
      longitude: 77.2090,
      speedKph: 45.2,
      headingDeg: 180.0,
      socPct: 74.5,
      estimatedRangeKm: 145.0,
      charging: false,
      connectivityStatus: 'online',
      lastSeen: DateTime.now().toUtc(),
    );

    const testChargingCenters = [
      ChargingCenterModel(
        id: 'station-01',
        name: 'Connaught Place Fast Charging Hub',
        latitude: 28.6050,
        longitude: 77.2090,
        powerKw: 150.0,
        connectors: {
          'fast_dc': true,
          'CCS2': 4,
          'Type2': 2,
        },
      ),
    ];

    final testTrack = [
      {'latitude': 28.6328, 'longitude': 77.2197, 'speed_kph': 32.0},
      {'latitude': 28.6250, 'longitude': 77.2205, 'speed_kph': 42.0},
    ];

    testWidgets('Renders FlutterMap with live vehicle HUD and action controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockActiveVehicleNotifier(testVehicle),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value(testChargingCenters),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value(testTrack),
            ),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Screen Title
      expect(find.text('Live Navigation & Charging'), findsOneWidget);

      // Verify FlutterMap instance
      expect(find.byType(FlutterMap), findsOneWidget);

      // Verify Floating Live Vehicle HUD content
      expect(find.text('DL-01-EV-2024'), findsAtLeastNWidgets(1));
      expect(find.text('SPEED'), findsOneWidget);
      expect(find.text('45 km/h'), findsOneWidget);
      expect(find.text('BATTERY'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('RANGE'), findsOneWidget);
      expect(find.text('145 km'), findsOneWidget);

      // Verify Action Controls
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets('Tapping charging station opens detail modal sheet with full station info', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeVehicleProvider.overrideWith(
              (ref) => _MockActiveVehicleNotifier(testVehicle),
            ),
            publicChargingCentersProvider.overrideWith(
              (ref) => Future.value(testChargingCenters),
            ),
            activeVehicleTrackProvider.overrideWith(
              (ref) => Future.value(testTrack),
            ),
          ],
          child: const MaterialApp(
            home: MapScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find charging station marker icon
      final stationMarkerFinder = find.byIcon(Icons.ev_station_rounded);
      expect(stationMarkerFinder, findsWidgets);

      // Tap marker to open bottom sheet
      await tester.tap(stationMarkerFinder.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify modal bottom sheet details
      expect(find.text('Connaught Place Fast Charging Hub'), findsOneWidget);
      expect(find.text('Government Verified Hub'), findsOneWidget);
      expect(find.text('150 kW Fast Charger'), findsOneWidget);
      expect(find.text('⚡ Fast DC Supported'), findsOneWidget);
      expect(find.text('CCS2: 4 Plugs'), findsOneWidget);
      expect(find.text('Type2: 2 Plugs'), findsOneWidget);
      expect(find.text('CLOSE DETAILS'), findsOneWidget);

      // Tap close button
      await tester.tap(find.text('CLOSE DETAILS'));
      await tester.pumpAndSettle();

      expect(find.text('CLOSE DETAILS'), findsNothing);
    });
  });
}

class _MockActiveVehicleNotifier extends ActiveVehicleNotifier {
  final VehicleModel _initial;
  _MockActiveVehicleNotifier(this._initial)
      : super(_EmptyVehicleRepository(), null) {
    state = ActiveVehicleState.data(_initial);
  }

  @override
  Future<void> loadVehicle() async {
    state = ActiveVehicleState.data(_initial);
  }
}

class _EmptyVehicleRepository extends VehicleRepository {
  _EmptyVehicleRepository() : super(Dio());
}
