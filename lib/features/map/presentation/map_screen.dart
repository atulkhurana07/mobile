import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../vehicle/providers/vehicle_provider.dart';
import '../../vehicle/models/vehicle_model.dart';
import '../providers/map_provider.dart';
import '../repositories/charging_repository.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();

  static const LatLng _defaultCenter = LatLng(28.6139, 77.2090); // Central Delhi

  void _recenter(VehicleModel? vehicle) {
    if (vehicle?.latitude != null && vehicle?.longitude != null) {
      _mapController.move(LatLng(vehicle!.latitude!, vehicle.longitude!), 14.5);
    } else {
      _mapController.move(_defaultCenter, 13.0);
    }
  }

  void _showChargingStationDetails(
    BuildContext context,
    ChargingCenterModel center,
    VehicleModel? vehicle,
  ) {
    double? distanceKm;
    if (vehicle?.latitude != null && vehicle?.longitude != null) {
      const distance = Distance();
      distanceKm = distance.as(
        LengthUnit.Kilometer,
        LatLng(vehicle!.latitude!, vehicle.longitude!),
        LatLng(center.latitude, center.longitude),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ChargingStationDetailSheet(
        center: center,
        distanceKm: distanceKm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeState = ref.watch(activeVehicleProvider);
    final vehicle = activeState.vehicle;
    final chargingCentersAsync = ref.watch(publicChargingCentersProvider);
    final trackAsync = ref.watch(activeVehicleTrackProvider);

    final vehicleLatLng = (vehicle?.latitude != null && vehicle?.longitude != null)
        ? LatLng(vehicle!.latitude!, vehicle.longitude!)
        : _defaultCenter;

    // Build GPS trail points
    final List<LatLng> trailPoints = [];
    trackAsync.whenData((tracks) {
      for (final t in tracks) {
        final lat = (t['latitude'] ?? t['lat'] as num?)?.toDouble();
        final lng = (t['longitude'] ?? t['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          trailPoints.add(LatLng(lat, lng));
        }
      }
    });
    if (vehicle?.latitude != null && vehicle?.longitude != null) {
      trailPoints.add(vehicleLatLng);
    }

    // Build charging station markers
    final List<Marker> chargingMarkers = [];
    chargingCentersAsync.whenData((centers) {
      for (final center in centers) {
        chargingMarkers.add(
          Marker(
            point: LatLng(center.latitude, center.longitude),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () => _showChargingStationDetails(context, center, vehicle),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.ev_station_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        );
      }
    });

    // Active vehicle marker with directional heading indicator
    Marker? vehicleMarker;
    if (vehicle?.latitude != null && vehicle?.longitude != null) {
      final heading = vehicle!.headingDeg ?? 0.0;
      vehicleMarker = Marker(
        point: vehicleLatLng,
        width: 80,
        height: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cardDark.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.primaryLight, width: 1),
              ),
              child: Text(
                vehicle.vehicleCode.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.6),
                    blurRadius: 10,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Transform.rotate(
                angle: (heading * math.pi / 180),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Navigation & Charging'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: () {
              ref.invalidate(publicChargingCentersProvider);
              ref.invalidate(activeVehicleTrackProvider);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Crash-Proof Interactive FlutterMap Visualization
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: vehicleLatLng,
              initialZoom: 14.0,
              minZoom: 4.0,
              maxZoom: 18.0,
            ),
            children: [
              // CartoDB Dark Matter Tile Layer
              TileLayer(
                urlTemplate: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.chargeease.mobile',
              ),
              // GPS Trail Polyline Layer
              if (trailPoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: trailPoints,
                      color: AppColors.primaryLight,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              // Government-Verified Charging Stations Marker Layer
              MarkerLayer(markers: chargingMarkers),
              // Active Vehicle Marker Layer
              if (vehicleMarker != null)
                MarkerLayer(markers: [vehicleMarker]),
            ],
          ),

          // 2. Floating Live Vehicle HUD (Top)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _LiveVehicleHUD(
              vehicle: vehicle,
              isStale: activeState.isStale,
            ),
          ),

          // 3. Floating Quick Action Controls (Bottom Right)
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'map_zoom_in',
                  backgroundColor: AppColors.cardDark,
                  child: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom + 1);
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'map_zoom_out',
                  backgroundColor: AppColors.cardDark,
                  child: const Icon(Icons.remove, color: Colors.white),
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom - 1);
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'map_recenter',
                  backgroundColor: AppColors.primary,
                  tooltip: 'Recenter on Vehicle',
                  onPressed: () => _recenter(vehicle),
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating HUD displaying live vehicle status over the map
class _LiveVehicleHUD extends StatelessWidget {
  final VehicleModel? vehicle;
  final bool isStale;

  const _LiveVehicleHUD({
    required this.vehicle,
    required this.isStale,
  });

  @override
  Widget build(BuildContext context) {
    if (vehicle == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardDark.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.offline, size: 18),
            SizedBox(width: 8),
            Text(
              'No active vehicle selected',
              style: TextStyle(color: AppColors.offline, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final speed = vehicle!.speedKph ?? 0.0;
    final soc = vehicle!.socPct ?? 0.0;
    final range = vehicle!.estimatedRangeKm ?? (soc * 2.5);
    final status = vehicle!.operationalStatus;

    Color statusColor;
    switch (status) {
      case 'CHARGING':
        statusColor = AppColors.success;
        break;
      case 'MOVING':
        statusColor = AppColors.primaryLight;
        break;
      default:
        statusColor = AppColors.offline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    vehicle!.vehicleCode.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Lat: ${vehicle!.latitude?.toStringAsFixed(4) ?? "---"}  Lng: ${vehicle!.longitude?.toStringAsFixed(4) ?? "---"}',
                style: const TextStyle(fontSize: 11, color: AppColors.offline),
              ),
            ],
          ),
          Row(
            children: [
              _HudMetric(
                label: 'SPEED',
                value: '${speed.toStringAsFixed(0)} km/h',
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              _HudMetric(
                label: 'BATTERY',
                value: '${soc.toStringAsFixed(0)}%',
                color: soc < 15 ? AppColors.error : (soc < 25 ? AppColors.warning : AppColors.success),
              ),
              const SizedBox(width: 12),
              _HudMetric(
                label: 'RANGE',
                value: '${range.toStringAsFixed(0)} km',
                color: AppColors.primaryLight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HudMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HudMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppColors.offline,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Clickable detail modal sheet displaying comprehensive charging center details
class _ChargingStationDetailSheet extends StatelessWidget {
  final ChargingCenterModel center;
  final double? distanceKm;

  const _ChargingStationDetailSheet({
    required this.center,
    this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.borderDark, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.offline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Station Name & Verified Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: const Icon(
                  Icons.ev_station_rounded,
                  color: AppColors.success,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      center.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.verified, size: 14, color: AppColors.primaryLight),
                        const SizedBox(width: 4),
                        const Text(
                          'Government Verified Hub',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (distanceKm != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '\u2022  ${distanceKm!.toStringAsFixed(1)} km away',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.offline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: AppColors.borderDark, height: 1),
          const SizedBox(height: 16),

          // Station Details Grid
          Row(
            children: [
              Expanded(
                child: _DetailTile(
                  icon: Icons.flash_on_rounded,
                  label: 'Power Rating',
                  value: center.powerKw != null
                      ? '${center.powerKw!.round()} kW Fast Charger'
                      : 'Standard Output',
                  accentColor: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailTile(
                  icon: Icons.location_on_outlined,
                  label: 'GPS Location',
                  value: '${center.latitude.toStringAsFixed(4)}, ${center.longitude.toStringAsFixed(4)}',
                  accentColor: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Address section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                const Icon(Icons.place_outlined, color: AppColors.offline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${center.name}, Delhi EV Corridor, New Delhi - 110001',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Available Connectors
          if (center.connectors != null && center.connectors!.isNotEmpty) ...[
            const Text(
              'AVAILABLE CONNECTOR TYPES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.offline,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (center.connectors!['fast_dc'] == true)
                  const Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    labelPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    label: Text(
                      '⚡ Fast DC Supported',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight),
                    ),
                    backgroundColor: AppColors.cardDark,
                    side: BorderSide(color: AppColors.primaryLight),
                  ),
                ...center.connectors!.entries
                    .where((e) => e.key != 'fast_dc' && e.value is! bool && num.tryParse(e.value.toString()) != null)
                    .map((e) {
                  return Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    label: Text(
                      '${e.key}: ${e.value} ${e.value.toString() == "1" ? "Plug" : "Plugs"}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    backgroundColor: AppColors.cardDark,
                    side: const BorderSide(color: AppColors.borderDark),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Close / Done button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'CLOSE DETAILS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.offline,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
