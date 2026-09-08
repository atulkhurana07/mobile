import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class StatusMetricsRow extends StatelessWidget {
  final double? speedKph;
  final double? headingDeg;
  final String connectivityStatus;
  final String operationalStatus;

  const StatusMetricsRow({
    super.key,
    this.speedKph,
    this.headingDeg,
    required this.connectivityStatus,
    required this.operationalStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = connectivityStatus.toLowerCase() == 'online';
    final speed = speedKph?.round() ?? 0;
    final headingStr = _getHeadingDirection(headingDeg);

    return Row(
      children: [
        // Metric 1: Speed & Heading
        Expanded(
          child: _MetricCard(
            title: 'SPEED & HEADING',
            value: '$speed km/h',
            subtitle: headingStr,
            icon: Icons.speed,
            accentColor: speed > 0 ? AppColors.info : AppColors.offline,
          ),
        ),
        const SizedBox(width: 12),

        // Metric 2: Operational Status
        Expanded(
          child: _MetricCard(
            title: 'OPERATIONAL STATE',
            value: operationalStatus,
            subtitle: isOnline ? 'Device Online' : 'Device Offline',
            icon: operationalStatus == 'CHARGING'
                ? Icons.bolt
                : (operationalStatus == 'MOVING'
                    ? Icons.directions_car
                    : Icons.pause_circle_outline),
            accentColor: operationalStatus == 'CHARGING'
                ? AppColors.success
                : (operationalStatus == 'MOVING' ? AppColors.info : AppColors.offline),
          ),
        ),
      ],
    );
  }

  String _getHeadingDirection(double? heading) {
    if (heading == null) return 'Stationary';
    if (heading >= 337.5 || heading < 22.5) return 'Heading North (N)';
    if (heading >= 22.5 && heading < 67.5) return 'Heading North-East (NE)';
    if (heading >= 67.5 && heading < 112.5) return 'Heading East (E)';
    if (heading >= 112.5 && heading < 157.5) return 'Heading South-East (SE)';
    if (heading >= 157.5 && heading < 202.5) return 'Heading South (S)';
    if (heading >= 202.5 && heading < 247.5) return 'Heading South-West (SW)';
    if (heading >= 247.5 && heading < 292.5) return 'Heading West (W)';
    return 'Heading North-West (NW)';
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.offline,
                  ),
                ),
                Icon(icon, size: 18, color: accentColor),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: accentColor == AppColors.offline ? Colors.white : accentColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.offline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
