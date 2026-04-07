import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api.dart';

class BackendHeartbeatService {
  BackendHeartbeatService._internal();
  static final BackendHeartbeatService _instance =
      BackendHeartbeatService._internal();
  factory BackendHeartbeatService() => _instance;

  Timer? _timer;
  int _activeConsumers = 0;
  DateTime? _lastPingAt;

  void start() {
    _activeConsumers++;
    _timer ??= Timer.periodic(const Duration(minutes: 10), (_) => _ping());
    _ping();
  }

  void stop() {
    if (_activeConsumers > 0) _activeConsumers--;
    if (_activeConsumers == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _ping() async {
    final now = DateTime.now();
    if (_lastPingAt != null &&
        now.difference(_lastPingAt!) < const Duration(seconds: 30)) {
      return;
    }
    _lastPingAt = now;

    final urls = <Uri>[
      Uri.parse(ApiConstants.baseUrl),
      Uri.parse('${ApiConstants.baseUrl}/health'),
    ];

    for (final url in urls) {
      try {
        await http.get(url).timeout(const Duration(seconds: 8));
        return;
      } catch (e) {
        debugPrint('Heartbeat ping failed for $url: $e');
      }
    }
  }
}

