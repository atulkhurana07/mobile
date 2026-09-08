import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/alert_model.dart';
import '../providers/alert_provider.dart';
import '../repositories/alert_repository.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  final DateFormat _dateFormat = DateFormat('MMM dd, HH:mm:ss');

  Future<void> _showAckDialog(BuildContext context, AlertModel alert) async {
    final noteController = TextEditingController(
      text: 'Verified & handled by vehicle operator on duty.',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.primaryLight),
            const SizedBox(width: 10),
            const Text(
              'Acknowledge Alert',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alert: ${alert.alertTypeFormatted}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              alert.shortExplanation,
              style: const TextStyle(color: AppColors.offline, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Operational Resolution Note',
                hintText: 'e.g. Navigating to depot charger...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.offline)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('SUBMIT ACK'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(alertRepositoryProvider)
            .acknowledgeAlert(alert.id, resolutionNote: noteController.text.trim());
        ref.invalidate(departmentAlertsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alert acknowledged and logged to central audit.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Acknowledgment failed: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(departmentAlertsProvider);
    final currentFilter = ref.watch(alertFilterProvider);
    final user = ref.watch(authProvider).user;
    final canAck = user?.canAcknowledgeAlerts ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operational Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Alerts',
            onPressed: () => ref.invalidate(departmentAlertsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _filterChip('All Alerts', null, currentFilter),
                const SizedBox(width: 8),
                _filterChip('Active Only', 'active', currentFilter),
                const SizedBox(width: 8),
                _filterChip('Acknowledged', 'acknowledged', currentFilter),
                const SizedBox(width: 8),
                _filterChip('Resolved', 'resolved', currentFilter),
              ],
            ),
          ),
          const Divider(color: AppColors.borderDark, height: 1),

          // Alerts List
          Expanded(
            child: alertsAsync.when(
              data: (alerts) {
                if (alerts.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.check_circle_outline,
                    title: 'No Alerts Found',
                    description: 'No active or filtered alerts recorded for this department.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(departmentAlertsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      return _AlertItemCard(
                        alert: alert,
                        dateFormat: _dateFormat,
                        canAck: canAck,
                        onAck: () => _showAckDialog(context, alert),
                      );
                    },
                  ),
                );
              },
              loading: () => const LoadingView(message: 'Loading telemetry alerts...'),
              error: (err, _) => ErrorStateView(
                message: err.toString(),
                onRetry: () => ref.invalidate(departmentAlertsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value, String? selectedValue) {
    final isSelected = value == selectedValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceDark,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.offline,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) {
        ref.read(alertFilterProvider.notifier).state = value;
      },
    );
  }
}

class _AlertItemCard extends StatelessWidget {
  final AlertModel alert;
  final DateFormat dateFormat;
  final bool canAck;
  final VoidCallback onAck;

  const _AlertItemCard({
    required this.alert,
    required this.dateFormat,
    required this.canAck,
    required this.onAck,
  });

  @override
  Widget build(BuildContext context) {
    Color severityColor;
    IconData severityIcon;

    if (alert.isCritical) {
      severityColor = AppColors.error;
      severityIcon = Icons.report_problem;
    } else if (alert.isHigh) {
      severityColor = AppColors.warning;
      severityIcon = Icons.warning_amber_rounded;
    } else {
      severityColor = AppColors.info;
      severityIcon = Icons.info_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Severity Badge + Status + Timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(severityIcon, color: severityColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      alert.severity.toUpperCase(),
                      style: TextStyle(
                        color: severityColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                StatusBadge(
                  label: alert.status,
                  type: alert.isActive ? BadgeType.warning : BadgeType.online,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Alert Title
            Text(
              alert.alertTypeFormatted,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),

            // Row 3: Short Explanation
            Text(
              alert.shortExplanation,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.offline,
              ),
            ),
            const SizedBox(height: 12),

            // Row 4: Timestamps
            Row(
              children: [
                const Icon(Icons.access_time, size: 13, color: AppColors.offline),
                const SizedBox(width: 4),
                Text(
                  'First Seen: ${dateFormat.format(alert.firstSeen.toLocal())}',
                  style: const TextStyle(fontSize: 11, color: AppColors.offline),
                ),
              ],
            ),

            if (alert.resolutionNote != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Note: ${alert.resolutionNote}',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Row 5: Action Button (Only for active alerts)
            if (alert.isActive) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canAck ? onAck : null,
                  icon: const Icon(Icons.done_all, size: 16),
                  label: Text(
                    canAck ? 'ACKNOWLEDGE ALERT' : 'ACKNOWLEDGE (RESTRICTED TO DISPATCHER)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
