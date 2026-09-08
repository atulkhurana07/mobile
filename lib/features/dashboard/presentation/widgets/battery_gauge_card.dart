import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class BatteryGaugeCard extends StatelessWidget {
  final double socPct;
  final double estimatedRangeKm;
  final bool isCharging;

  const BatteryGaugeCard({
    super.key,
    required this.socPct,
    required this.estimatedRangeKm,
    required this.isCharging,
  });

  @override
  Widget build(BuildContext context) {
    final batteryColor = isCharging ? AppColors.success : AppColors.batteryColor(socPct);
    final clampedSoc = socPct.clamp(0.0, 100.0);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isCharging ? AppColors.success.withOpacity(0.5) : AppColors.borderDark,
          width: isCharging ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
        child: Column(
          children: [
            // Gauge and SoC %
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: CircularProgressIndicator(
                    value: clampedSoc / 100.0,
                    strokeWidth: 14,
                    backgroundColor: AppColors.cardDark,
                    valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCharging ? Icons.bolt_rounded : Icons.battery_charging_full_rounded,
                      color: batteryColor,
                      size: 28,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${clampedSoc.round()}%',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'STATE OF CHARGE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: AppColors.offline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Estimated Range
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.route_outlined, size: 20, color: AppColors.primaryLight),
                const SizedBox(width: 8),
                Text(
                  '${estimatedRangeKm.round()} km',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ESTIMATED RANGE',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.offline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Charging Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isCharging
                    ? AppColors.success.withOpacity(0.2)
                    : AppColors.cardDark.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCharging ? AppColors.success : AppColors.borderDark,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCharging ? Icons.power : Icons.power_off_outlined,
                    size: 16,
                    color: isCharging ? AppColors.success : AppColors.offline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCharging ? 'CHARGING IN PROGRESS' : 'NOT CHARGING',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isCharging ? AppColors.success : AppColors.offline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
