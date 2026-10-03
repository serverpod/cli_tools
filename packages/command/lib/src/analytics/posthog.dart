import 'dart:convert';
import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:ci/ci.dart' as ci;
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

import 'analytics.dart';
import 'helpers.dart';

/// Analytics service for PostHog.
class PostHogAnalytics extends Analytics {
  static const _defaultHost = 'https://eu.i.posthog.com';
  static const _defaultTimeout = Duration(seconds: 2);
  static const _defaultLibName = 'command';

  final String _uniqueUserId;
  final String _projectApiKey;
  final String _version;
  final String _libName;

  final Uri _endpoint;
  final Duration _timeout;

  PostHogAnalytics({
    required String uniqueUserId,
    required String projectApiKey,
    required String version,
    String? host,
    Duration timeout = _defaultTimeout,
    String libName = _defaultLibName,
  }) : _uniqueUserId = uniqueUserId,
       _projectApiKey = projectApiKey,
       _version = version,
       _endpoint = Uri.parse('${host ?? _defaultHost}/capture/'),
       _timeout = timeout,
       _libName = libName;

  @override
  Future<void> sendEvent({
    required String event,
    Map<String, dynamic> properties = const {},
  }) async {
    final eventData = {
      'api_key': _projectApiKey,
      'event': event,
      'distinct_id': _uniqueUserId,
      'properties': {
        '\$lib': _libName,
        '\$lib_version': _version,
        'platform': getPlatformString(),
        'dart_version': Platform.version,
        'is_ci': ci.isCI,
        ...properties,
      },
    };

    await http
        .post(
          _endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(eventData),
        )
        .timeout(_timeout);
  }
}
