import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../vehicle/providers/vehicle_provider.dart';
import '../../alerts/providers/alert_provider.dart';
import '../../simulator/providers/pitch_simulator_provider.dart';
import 'widgets/battery_gauge_card.dart';
import 'widgets/status_metrics_row.dart';
import 'widgets/critical_alert_banner.dart';
import 'widgets/telemetry_freshness_badge.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onNavigateToAlerts;

  const HomeScreen({super.key, this.onNavigateToAlerts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeState = ref.watch(activeVehicleProvider);
    final user = ref.watch(authProvider).user;
    final isSimulating = ref.watch(isPitchSimulatorRunningProvider);
    final topCriticalAlert = ref.watch(pitchSimulatorAlertProvider) ?? ref.watch(topCriticalAlertProvider);
    final dateFormat = DateFormat('HH:mm:ss (MMM dd)');

    if (activeState.isLoading && activeState.vehicle == null) {
      return const Scaffold(
        body: LoadingView(message: 'Connecting to vehicle terminal...'),
      );
    }

    if (activeState.errorMessage != null && activeState.vehicle == null) {
      return Scaffold(
        body: ErrorStateView(
          message: activeState.errorMessage!,
          onRetry: () => ref.read(activeVehicleProvider.notifier).loadVehicle(),
        ),
      );
    }

    final vehicle = activeState.vehicle;
    if (vehicle == null) {
      return Scaffold(
        body: EmptyStateView(
          icon: Icons.directions_car_outlined,
          title: 'No Vehicle Selected',
          description: 'Please select a vehicle assigned to your department.',
          action: ElevatedButton(
            onPressed: () {
              ref.read(selectedVehicleIdProvider.notifier).clear();
            },
            child: const Text('SELECT VEHICLE'),
          ),
        ),
      );
    }

    final soc = vehicle.socPct ?? 0.0;
    final range = vehicle.estimatedRangeKm ?? (soc * 2.5);
    final isCharging = vehicle.charging == true;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  vehicle.vehicleCode.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                TelemetryFreshnessBadge(
                  isStale: activeState.isStale,
                  lastSeen: vehicle.lastSeen,
                ),
              ],
            ),
            Text(
              '${user?.departmentName ?? "Department"} \u2022 ${user?.fullName ?? "Operator"}',
              style: const TextStyle(fontSize: 12, color: AppColors.offline),
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: isSimulating ? 'Stop Pitch Drive Simulation' : 'Start Pitch Drive Simulation',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                ref.read(pitchSimulatorProvider.notifier).toggle();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSimulating
                      ? AppColors.warning.withValues(alpha: 0.2)
                      : AppColors.cardDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSimulating ? AppColors.warning : AppColors.borderDark,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSimulating ? Icons.sensors : Icons.sensors_off,
                      size: 16,
                      color: isSimulating ? AppColors.warning : AppColors.offline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'SIM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSimulating ? AppColors.warning : AppColors.offline,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 20,
                      width: 32,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: Switch.adaptive(
                          value: isSimulating,
                          activeThumbColor: AppColors.warning,
                          onChanged: (_) {
                            ref.read(pitchSimulatorProvider.notifier).toggle();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Switch Vehicle',
            onPressed: () {
              ref.read(selectedVehicleIdProvider.notifier).clear();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Telemetry',
            onPressed: () {
              ref.read(activeVehicleProvider.notifier).loadVehicle();
              ref.invalidate(departmentAlertsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(activeVehicleProvider.notifier).loadVehicle();
          ref.invalidate(departmentAlertsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Critical Alert Banner (if active)
              if (topCriticalAlert != null)
                CriticalAlertBanner(
                  alert: topCriticalAlert,
                  onTap: () {
                    if (onNavigateToAlerts != null) {
                      onNavigateToAlerts!();
                    }
                  },
                ),

              // 2. Main High-Visibility Battery Section
              BatteryGaugeCard(
                socPct: soc,
                estimatedRangeKm: range,
                isCharging: isCharging,
              ),
              const SizedBox(height: 14),

              // 3. Operational State & Speed Metrics
              StatusMetricsRow(
                speedKph: vehicle.speedKph,
                headingDeg: vehicle.headingDeg,
                connectivityStatus: vehicle.connectivityStatus ?? 'online',
                operationalStatus: vehicle.operationalStatus,
              ),
              const SizedBox(height: 14),

              // 4. Live Vehicle & GPS Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.satellite_alt_outlined, size: 16, color: AppColors.primaryLight),
                          SizedBox(width: 8),
                          Text(
                            'LIVE POSITION & TELEMETRY SYNC',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.offline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _infoRow(
                        'GPS Coordinates',
                        vehicle.latitude != null && vehicle.longitude != null
                            ? '${vehicle.latitude!.toStringAsFixed(5)}, ${vehicle.longitude!.toStringAsFixed(5)}'
                            : 'Acquiring GPS fix...',
                      ),
                      const Divider(color: AppColors.borderDark, height: 16),
                      _infoRow(
                        'Last Observed At',
                        vehicle.lastSeen != null
                            ? dateFormat.format(vehicle.lastSeen!.toLocal())
                            : 'Awaiting first telemetry ping',
                      ),
                      const Divider(color: AppColors.borderDark, height: 16),
                      _infoRow(
                        'Vehicle Class',
                        vehicle.vehicleTypeFormatted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.offline),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
