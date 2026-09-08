import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/networking/dio_client.dart';
import '../../core/networking/api_endpoints.dart';

final offlineTelemetryQueueProvider = Provider<OfflineTelemetryQueue>((ref) {
  final dio = ref.watch(dioProvider);
  final queue = OfflineTelemetryQueue(dio);
  queue.loadFromDisk();
  return queue;
});

class OfflineTelemetryQueue {
  static const String storageKey = 'offline_telemetry_queue_v1';

  final Dio _dio;
  final SharedPreferences? _prefs;
  final List<Map<String, dynamic>> _queue = [];
  bool _isFlushing = false;
  bool _isInitialized = false;

  OfflineTelemetryQueue(this._dio, [this._prefs]);

  int get queuedCount => _queue.length;
  bool get isFlushing => _isFlushing;
  bool get isInitialized => _isInitialized;
  List<Map<String, dynamic>> get queue => List.unmodifiable(_queue);

  /// Reload queue from SharedPreferences on app/service startup
  Future<void> loadFromDisk() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _queue.clear();
          for (final item in decoded) {
            if (item is Map) {
              _queue.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
    } catch (_) {
      // Gracefully handle storage deserialization errors
    } finally {
      _isInitialized = true;
    }
  }

  /// Persists current memory queue state to disk
  Future<void> _persistToDisk() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      if (_queue.isEmpty) {
        await prefs.remove(storageKey);
      } else {
        await prefs.setString(storageKey, jsonEncode(_queue));
      }
    } catch (_) {
      // Ignore disk write failure to maintain in-memory stability
    }
  }

  /// Serialize queue on enqueue and attempt to flush
  Future<void> enqueue(Map<String, dynamic> payload) async {
    if (!_isInitialized) {
      await loadFromDisk();
    }
    _queue.add(payload);
    await _persistToDisk();
    await flush();
  }

  /// Drains successfully sent items and updates persistent storage; keeps unsent items on failure
  Future<void> flush() async {
    if (!_isInitialized) {
      await loadFromDisk();
    }
    if (_isFlushing || _queue.isEmpty) return;
    _isFlushing = true;

    while (_queue.isNotEmpty) {
      final payload = _queue.first;
      try {
        final response = await _dio.post(
          ApiEndpoints.ingestTelemetry,
          data: payload,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          _queue.removeAt(0); // Successfully ingested or duplicate accepted
          await _persistToDisk();
        } else {
          break; // Stop flushing on server errors
        }
      } catch (_) {
        // Network offline, keep remaining items on disk and stop
        break;
      }
    }

    _isFlushing = false;
  }

  /// Clears in-memory and persisted storage (useful for resets and testing)
  Future<void> clear() async {
    _queue.clear();
    await _persistToDisk();
  }
}
