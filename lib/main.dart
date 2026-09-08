import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/vehicle/providers/vehicle_provider.dart';
import 'features/vehicle/presentation/vehicle_selection_screen.dart';
import 'features/dashboard/presentation/app_shell.dart';
import 'shared/widgets/loading_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: ChargeEaseApp(),
    ),
  );
}

class ChargeEaseApp extends ConsumerWidget {
  const ChargeEaseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'URJA — Government EV Fleet Operator Terminal (ChargeEase)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _resolveHomeScreen(authState.status, ref),
    );
  }

  Widget _resolveHomeScreen(AuthStateStatus status, WidgetRef ref) {
    switch (status) {
      case AuthStateStatus.initial:
      case AuthStateStatus.loading:
        return const Scaffold(
          body: LoadingView(message: 'Initializing secure terminal...'),
        );
      case AuthStateStatus.unauthenticated:
      case AuthStateStatus.error:
        return const LoginScreen();
      case AuthStateStatus.authenticated:
        final selectedVehicleId = ref.watch(selectedVehicleIdProvider);
        if (selectedVehicleId == null) {
          return const VehicleSelectionScreen();
        }
        return const AppShell();
    }
  }
}
