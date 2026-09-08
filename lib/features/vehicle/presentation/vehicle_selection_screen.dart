import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle_model.dart';

class VehicleSelectionScreen extends ConsumerStatefulWidget {
  const VehicleSelectionScreen({super.key});

  @override
  ConsumerState<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends ConsumerState<VehicleSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final vehiclesAsync = ref.watch(vehicleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Assigned Vehicle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              user?.departmentName ?? 'Department Fleet',
              style: const TextStyle(fontSize: 12, color: AppColors.offline),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Fleet',
            onPressed: () => ref.invalidate(vehicleListProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: 'Logout',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: vehiclesAsync.when(
        data: (vehicles) {
          final filtered = vehicles.where((v) {
            final query = _searchQuery.toLowerCase();
            return v.vehicleCode.toLowerCase().contains(query) ||
                v.vehicleType.toLowerCase().contains(query);
          }).toList();

          if (vehicles.isEmpty) {
            return const EmptyStateView(
              icon: Icons.directions_car_outlined,
              title: 'No Vehicles in Department',
              description: 'No active vehicles registered for your department.',
            );
          }

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by vehicle ID or type...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.offline),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.offline),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // Vehicle List
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No vehicles match your search.',
                          style: TextStyle(color: AppColors.offline),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(vehicleListProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final vehicle = filtered[index];
                            return _VehicleCard(
                              vehicle: vehicle,
                              onSelect: () {
                                ref
                                    .read(selectedVehicleIdProvider.notifier)
                                    .selectVehicle(vehicle.id);
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const LoadingView(message: 'Loading department vehicles...'),
        error: (err, _) => ErrorStateView(
          message: err.toString(),
          onRetry: () => ref.invalidate(vehicleListProvider),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final VehicleModel vehicle;
  final VoidCallback onSelect;

  const _VehicleCard({
    required this.vehicle,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final soc = vehicle.socPct ?? 0;
    final range = vehicle.estimatedRangeKm?.round() ?? 0;
    final charging = vehicle.charging == true;
    final batteryColor = AppColors.batteryColor(soc);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Vehicle Code + Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getVehicleIcon(vehicle.vehicleType),
                          color: AppColors.primaryLight,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.vehicleCode.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            vehicle.vehicleTypeFormatted,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.offline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  StatusBadge(
                    label: vehicle.operationalStatus,
                    type: charging
                        ? BadgeType.charging
                        : (vehicle.operationalStatus == 'MOVING'
                            ? BadgeType.moving
                            : BadgeType.idle),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Row 2: Battery SoC + Range
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${soc.round()}% SoC',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: batteryColor,
                              ),
                            ),
                            Text(
                              '$range km Est. Range',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (soc / 100).clamp(0.0, 1.0),
                            backgroundColor: AppColors.borderDark,
                            valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Select Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSelect,
                  icon: const Icon(Icons.touch_app_outlined, size: 18),
                  label: const Text('OPERATE THIS VEHICLE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getVehicleIcon(String type) {
    switch (type) {
      case 'electric_bus':
        return Icons.directions_bus;
      case 'fire_ev':
        return Icons.local_fire_department;
      case 'utility_ev':
        return Icons.build_circle_outlined;
      case 'ambulance_ev':
        return Icons.medical_services_outlined;
      default:
        return Icons.directions_car;
    }
  }
}
