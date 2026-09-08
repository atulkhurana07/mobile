import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class Env {
  // Stored runtime override (can be changed dynamically in terminal settings)
  static String? _customApiBaseUrl;
  static String? _customWsBaseUrl;

  static void setCustomUrls({String? apiUrl, String? wsUrl}) {
    if (apiUrl != null && apiUrl.isNotEmpty) {
      _customApiBaseUrl = apiUrl.trim();
    }
    if (wsUrl != null && wsUrl.isNotEmpty) {
      _customWsBaseUrl = wsUrl.trim();
    }
  }

  static String get defaultHost {
    return 'https://backend-ce2c.onrender.com';
  }

  static String get defaultWsHost {
    return 'wss://backend-ce2c.onrender.com';
  }

  static String get apiBaseUrl {
    if (_customApiBaseUrl != null) return _customApiBaseUrl!;
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return defaultHost;
  }

  static String get wsBaseUrl {
    if (_customWsBaseUrl != null) return _customWsBaseUrl!;
    const fromEnv = String.fromEnvironment('WS_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return defaultWsHost;
  }

  // Stale telemetry timeout: if no telemetry received within this duration, display STALE
  static const Duration staleTelemetryThreshold = Duration(seconds: 30);

  // Periodic polling fallback if WebSocket disconnects
  static const Duration pollingFallbackInterval = Duration(seconds: 8);
}
