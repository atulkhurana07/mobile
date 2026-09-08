import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum BadgeType {
  online,
  offline,
  charging,
  moving,
  idle,
  stale,
  critical,
  warning,
  info,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeType type;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData defaultIcon;

    switch (type) {
      case BadgeType.online:
      case BadgeType.charging:
        bg = AppColors.success.withOpacity(0.15);
        fg = AppColors.success;
        defaultIcon = type == BadgeType.charging ? Icons.bolt : Icons.wifi;
        break;
      case BadgeType.moving:
      case BadgeType.info:
        bg = AppColors.info.withOpacity(0.15);
        fg = AppColors.info;
        defaultIcon = Icons.directions_car;
        break;
      case BadgeType.warning:
      case BadgeType.stale:
        bg = AppColors.warning.withOpacity(0.15);
        fg = AppColors.warning;
        defaultIcon = type == BadgeType.stale ? Icons.history : Icons.warning_amber;
        break;
      case BadgeType.offline:
      case BadgeType.idle:
        bg = AppColors.offline.withOpacity(0.2);
        fg = AppColors.offline;
        defaultIcon = type == BadgeType.offline ? Icons.wifi_off : Icons.pause_circle_outline;
        break;
      case BadgeType.critical:
        bg = AppColors.error.withOpacity(0.15);
        fg = AppColors.error;
        defaultIcon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? defaultIcon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
