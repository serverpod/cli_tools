import 'dart:convert';
import 'dart:io';

import 'package:ci/ci.dart' as ci;
import 'package:http/http.dart' as http;

import 'analytics.dart';
import 'helpers.dart';

/// Analytics service for MixPanel.
class MixPanelAnalytics implements Analytics {
  static const _defaultEndpoint = 'https://api.mixpanel.com/track';
  static const _defaultTimeout = Duration(seconds: 2);

  final String _uniqueUserId;
  final String _projectToken;
  final String _version;

  final Uri _endpoint;
  final Duration _timeout;

  MixPanelAnalytics({
    required final String uniqueUserId,
    required final String projectToken,
    required final String version,
    final String? endpoint,
    final Duration timeout = _defaultTimeout,
    final bool disableIpTracking = false,
  })  : _uniqueUserId = uniqueUserId,
        _projectToken = projectToken,
        _version = version,
        _endpoint = _buildEndpoint(
          endpoint ?? _defaultEndpoint,
          disableIpTracking,
        ),
        _timeout = timeout;

  static Uri _buildEndpoint(
    final String baseEndpoint,
    final bool disableIpTracking,
  ) {
    final uri = Uri.parse(baseEndpoint);
    final ipValue = disableIpTracking ? '0' : '1';

    final updatedUri = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'ip': ipValue,
      },
    );
    return updatedUri;
  }

  @override
  void cleanUp() {}

  @override
  void track({
    required final String event,
    final Map<String, dynamic> properties = const {},
  }) {
    final payload = jsonEncode({
      'event': event,
      'properties': {
        'distinct_id': _uniqueUserId,
        'token': _projectToken,
        'platform': getPlatformString(),
        'dart_version': Platform.version,
        'is_ci': ci.isCI,
        'version': _version,
      },
    });

    _quietPost(payload);
  }

  Future<void> _quietPost(final String payload) async {
    try {
      await http.post(
        _endpoint,
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
