import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../vehicle/providers/vehicle_provider.dart';
import '../../alerts/providers/alert_provider.dart';

class VehicleHealthScreen extends ConsumerWidget {
  const VehicleHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeState = ref.watch(activeVehicleProvider);
    final vehicle = activeState.vehicle;
    final vehicleAlerts = ref.watch(vehicleAlertsProvider);

    final diagnosticAlerts = vehicleAlerts
        .where((a) => a.isActive && (a.alertType == 'DIAGNOSTIC_FAULT' || a.alertType == 'HIGH_BATTERY_TEMP'))
        .toList();

    final hasFaults = diagnosticAlerts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Health & Diagnostics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Overall Health Status Banner
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: hasFaults
                    ? AppColors.error.withOpacity(0.15)
                    : AppColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasFaults ? AppColors.error : AppColors.success,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasFaults ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                    color: hasFaults ? AppColors.error : AppColors.success,
                    size: 36,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasFaults ? 'ACTIVE FAULTS DETECTED' : 'SYSTEMS OPERATIONAL',
                          style: TextStyle(
                            color: hasFaults ? AppColors.error : AppColors.success,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasFaults
                              ? '${diagnosticAlerts.length} active diagnostic alerts require attention.'
                              : 'No critical telemetry or battery faults recorded.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Battery Subsystem Health
            const Text(
              'HIGH VOLTAGE BATTERY SUBSYSTEM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.offline,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _diagnosticRow(
                      'Battery State of Charge',
                      '${vehicle?.socPct?.round() ?? 0}%',
                      Icons.battery_charging_full,
                      AppColors.primaryLight,
                    ),
                    const Divider(color: AppColors.borderDark, height: 16),
                    _diagnosticRow(
                      'Thermal Management',
                      hasFaults && diagnosticAlerts.any((a) => a.alertType == 'HIGH_BATTERY_TEMP')
                          ? 'HIGH TEMP ALERT'
                          : 'Normal (Under 45\u00B0C Threshold)',
                      Icons.thermostat,
                      hasFaults && diagnosticAlerts.any((a) => a.alertType == 'HIGH_BATTERY_TEMP')
                          ? AppColors.error
                          : AppColors.success,
                    ),
                    const Divider(color: AppColors.borderDark, height: 16),
                    _diagnosticRow(
                      'Charging Status',
                      vehicle?.charging == true ? 'Active (Connected)' : 'Not Connected',
                      Icons.power,
                      vehicle?.charging == true ? AppColors.success : AppColors.offline,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Telematics & Device Gateway
            const Text(
              'TELEMATICS & ON-BOARD UNIT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.offline,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _diagnosticRow(
                      'Connectivity State',
                      vehicle?.connectivityStatus?.toUpperCase() ?? 'ONLINE',
                      Icons.wifi,
                      vehicle?.connectivityStatus == 'offline' ? AppColors.error : AppColors.success,
                    ),
                    const Divider(color: AppColors.borderDark, height: 16),
                    _diagnosticRow(
                      'Telemetry Ingest Pipeline',
                      'Connected (Neon PostgreSQL SOT)',
                      Icons.dns_outlined,
                      AppColors.primaryLight,
                    ),
                    const Divider(color: AppColors.borderDark, height: 16),
                    _diagnosticRow(
                      'Firmware Version',
                      'v0.3.1 (Approved Government Build)',
                      Icons.system_update_alt,
                      AppColors.offline,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 4. Standard Operating Procedure
            const Text(
              'OPERATIONAL SAFETY PROTOCOL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.offline,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: AppColors.cardDark.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: const Text(
                'In case of High Battery Temperature (>45\u00B0C) or Critical Low SoC (<10%), navigate immediately to the nearest approved depot charging station and notify the department dispatcher.',
                style: TextStyle(
                  color: AppColors.offline,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagnosticRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color == AppColors.offline ? Colors.white70 : color,
          ),
        ),
      ],
    );
  }
}
