import 'dart:convert';
import 'dart:io';

import 'package:ci/ci.dart' as ci;
import 'package:http/http.dart' as http;

/// Interface for analytics services.
abstract interface class Analytics {
  /// Clean up resources.
  void cleanUp();

  /// Track an event.
  void track({required final String event});
}

/// Analytics service for MixPanel.
class MixPanelAnalytics implements Analytics {
  static const _defaultEndpoint = 'https://api.mixpanel.com/track';
  static const _defaultTimeout = Duration(seconds: 2);

  final String _uniqueUserId;
  final String _endpoint;
  final String _projectToken;
  final String _version;
  final Duration _timeout;

  MixPanelAnalytics({
    required final String uniqueUserId,
    required final String projectToken,
    required final String version,
    final String endpoint = _defaultEndpoint,
    final Duration timeout = _defaultTimeout,
  })  : _uniqueUserId = uniqueUserId,
        _projectToken = projectToken,
        _version = version,
        _endpoint = endpoint,
        _timeout = timeout;

  @override
  void cleanUp() {}

  @override
  void track({required final String event}) {
    final payload = jsonEncode({
      'event': event,
      'properties': {
        'distinct_id': _uniqueUserId,
        'token': _projectToken,
        'platform': _getPlatform(),
        'dart_version': Platform.version,
        'is_ci': ci.isCI,
        'version': _version,
      },
    });

    _quietPost(payload);
  }

  String _getPlatform() {
    if (Platform.isMacOS) {
      return 'MacOS';
    } else if (Platform.isWindows) {
      return 'Windows';
    } else if (Platform.isLinux) {
      return 'Linux';
    } else {
      return 'Unknown';
    }
  }

  Future<void> _quietPost(final String payload) async {
    try {
      await http.post(
        Uri.parse(_endpoint),
        body: 'data=$payload',
        headers: {
          'Accept': 'text/plain',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      ).timeout(_timeout);
    } catch (e) {
      return;
    }
  }
}
