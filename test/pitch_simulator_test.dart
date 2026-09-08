import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chargeease_mobile/features/simulator/providers/pitch_simulator_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PitchSimulatorProvider Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('Initializes with stopped state and Connaught Place waypoint', () {
      final state = container.read(pitchSimulatorProvider);

      expect(state.isRunning, isFalse);
      expect(state.currentStepIndex, 0);
      expect(state.currentWaypoint.locationName, contains('Connaught Place'));
      expect(state.currentWaypoint.socPct, 18.0);
      expect(state.activeAlert, isNull);
    });

    test('Has 6 Delhi waypoints with depleting SoC down to 7.0%', () {
      final notifier = container.read(pitchSimulatorProvider.notifier);
      final waypoints = notifier.waypoints;

      expect(waypoints.length, 6);
      expect(waypoints[0].socPct, 18.0);
      expect(waypoints[1].socPct, 15.0);
      expect(waypoints[2].socPct, 12.0);
      expect(waypoints[3].socPct, 9.5);
      expect(waypoints[4].socPct, 8.0);
      expect(waypoints[5].socPct, 7.0);

      // Verify route landmarks
      expect(waypoints[0].locationName, contains('Connaught Place'));
      expect(waypoints[1].locationName, contains('Janpath'));
      expect(waypoints[2].locationName, contains('Kartavya Path'));
      expect(waypoints[3].locationName, contains('India Gate'));
      expect(waypoints[4].locationName, contains('Pragati Maidan'));
      expect(waypoints[5].locationName, contains('ITO'));
    });

    test('Triggers dynamic critical LOW_SOC alert when SoC < 10%', () {
      final notifier = container.read(pitchSimulatorProvider.notifier);

      // Step to index 1 (Janpath, SoC 15%)
      notifier.step();
      expect(container.read(pitchSimulatorProvider).currentStepIndex, 1);
      expect(container.read(pitchSimulatorAlertProvider), isNull);

      // Step to index 2 (Kartavya Path, SoC 12%)
      notifier.step();
      expect(container.read(pitchSimulatorProvider).currentStepIndex, 2);
      expect(container.read(pitchSimulatorAlertProvider), isNull);

      // Step to index 3 (India Gate, SoC 9.5% < 10%)
      notifier.step();
      final stateStep3 = container.read(pitchSimulatorProvider);
      expect(stateStep3.currentStepIndex, 3);
      expect(stateStep3.currentWaypoint.socPct, 9.5);

      final alert = container.read(pitchSimulatorAlertProvider);
      expect(alert, isNotNull);
      expect(alert!.alertType, 'LOW_SOC');
      expect(alert.severity, 'critical');
      expect(alert.isCritical, isTrue);
      expect(alert.isActive, isTrue);
      expect(alert.metadata?['soc_pct'], 9.5);

      // Step to index 4 (Pragati Maidan, SoC 8.0%)
      notifier.step();
      final alertStep4 = container.read(pitchSimulatorAlertProvider);
      expect(alertStep4, isNotNull);
      expect(alertStep4!.alertType, 'LOW_SOC');
      expect(alertStep4.metadata?['soc_pct'], 8.0);

      // Step to index 5 (ITO, SoC 7.0%)
      notifier.step();
      final alertStep5 = container.read(pitchSimulatorAlertProvider);
      expect(alertStep5, isNotNull);
      expect(alertStep5!.metadata?['soc_pct'], 7.0);
    });

    test('Toggle toggles simulation state properly', () {
      final notifier = container.read(pitchSimulatorProvider.notifier);

      expect(container.read(isPitchSimulatorRunningProvider), isFalse);

      notifier.toggle();
      expect(container.read(isPitchSimulatorRunningProvider), isTrue);

      notifier.toggle();
      expect(container.read(isPitchSimulatorRunningProvider), isFalse);
    });

    test('Reset stops simulation and restores initial waypoint', () {
      final notifier = container.read(pitchSimulatorProvider.notifier);

      notifier.step();
      notifier.step();
      notifier.step(); // At India Gate with alert
      expect(container.read(pitchSimulatorAlertProvider), isNotNull);

      notifier.reset();
      final resetState = container.read(pitchSimulatorProvider);
      expect(resetState.isRunning, isFalse);
      expect(resetState.currentStepIndex, 0);
      expect(resetState.currentWaypoint.socPct, 18.0);
      expect(resetState.activeAlert, isNull);
      expect(container.read(pitchSimulatorAlertProvider), isNull);
    });
  });
}
