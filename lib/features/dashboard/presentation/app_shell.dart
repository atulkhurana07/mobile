import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/websocket/websocket_service.dart';
import '../../alerts/providers/alert_provider.dart';
import 'home_screen.dart';
import '../../alerts/presentation/alerts_screen.dart';
import '../../map/presentation/map_screen.dart';
import '../../health/presentation/vehicle_health_screen.dart';
import '../../profile/presentation/profile_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(webSocketServiceProvider).connect();
    });
  }

  void _onNavigateToAlerts() {
    setState(() {
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehicleAlerts = ref.watch(vehicleAlertsProvider);
    final activeAlertCount = vehicleAlerts.where((a) => a.isActive).length;

    final screens = [
      HomeScreen(onNavigateToAlerts: _onNavigateToAlerts),
      const AlertsScreen(),
      const MapScreen(),
      const VehicleHealthScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primaryLight),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeAlertCount > 0,
              label: Text('$activeAlertCount'),
              backgroundColor: AppColors.error,
              child: const Icon(Icons.warning_amber_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: activeAlertCount > 0,
              label: Text('$activeAlertCount'),
              backgroundColor: AppColors.error,
              child: const Icon(Icons.warning_rounded, color: AppColors.error),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: AppColors.primaryLight),
            label: 'Map',
          ),
          const NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart, color: AppColors.primaryLight),
            label: 'Health',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primaryLight),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
