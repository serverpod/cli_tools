import 'dart:convert';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:ci/ci.dart' as ci;
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

import 'analytics.dart';
import 'helpers.dart';

/// Analytics service for MixPanel.
class MixPanelAnalytics extends Analytics {
  static const _defaultEndpoint = 'https://api.mixpanel.com/track';
  static const _defaultTimeout = Duration(seconds: 2);

  final String _uniqueUserId;
  final String _projectToken;
  final String _version;

  final Uri _endpoint;
  final Duration _timeout;

  MixPanelAnalytics({
    required String uniqueUserId,
    required String projectToken,
    required String version,
    String? endpoint,
    Duration timeout = _defaultTimeout,
    bool disableIpTracking = false,
  }) : _uniqueUserId = uniqueUserId,
       _projectToken = projectToken,
       _version = version,
       _endpoint = _buildEndpoint(
         endpoint ?? _defaultEndpoint,
         disableIpTracking,
       ),
       _timeout = timeout;

  static Uri _buildEndpoint(
    String baseEndpoint,
    bool disableIpTracking,
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
  Future<void> sendEvent({
    required String event,
    Map<String, dynamic> properties = const {},
  }) async {
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

    await http
        .post(
          _endpoint,
          body: 'data=$payload',
          headers: {
            'Accept': 'text/plain',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        )
        .timeout(_timeout);
  }
}
