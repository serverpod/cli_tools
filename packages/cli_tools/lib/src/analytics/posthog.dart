import 'dart:convert';
import 'dart:io';

import 'package:ci/ci.dart' as ci;
import 'package:http/http.dart' as http;

import 'analytics.dart';
import 'helpers.dart';

/// Analytics service for PostHog.
class PostHogAnalytics implements Analytics {
  static const _defaultHost = 'https://eu.i.posthog.com';
  static const _defaultTimeout = Duration(seconds: 2);

  final String _uniqueUserId;
  final String _projectApiKey;
  final String _version;

  final Uri _endpoint;
  final Duration _timeout;

  PostHogAnalytics({
    required final String uniqueUserId,
    required final String projectApiKey,
    required final String version,
    final String? host,
    final Duration timeout = _defaultTimeout,
  })  : _uniqueUserId = uniqueUserId,
        _projectApiKey = projectApiKey,
        _version = version,
        _endpoint = Uri.parse('${host ?? _defaultHost}/capture/'),
        _timeout = timeout;

  @override
  void cleanUp() {}

  @override
  void track({
    required final String event,
    final Map<String, dynamic> properties = const {},
  }) {
    final eventData = {
      'api_key': _projectApiKey,
      'event': event,
      'distinct_id': _uniqueUserId,
      'properties': {
        '\$lib': 'cli_tools',
        '\$lib_version': _version,
        'platform': getPlatformString(),
        'dart_version': Platform.version,
        'is_ci': ci.isCI,
        ...properties,
      },
    };

    _quietPost(eventData);
  }

  Future<void> _quietPost(final Map<String, dynamic> eventData) async {
    try {
      await http
          .post(
            _endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(eventData),
          )
          .timeout(_timeout);
    } catch (e) {
      return;
    }
  }
}
