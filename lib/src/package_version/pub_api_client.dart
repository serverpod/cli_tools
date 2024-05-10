import 'dart:async';

import 'package:cli_tools/src/package_version/pub_api_client_exceptions.dart';
import 'package:http/http.dart' as http;
import 'package:pub_api_client/pub_api_client.dart';
import 'package:pub_semver/pub_semver.dart';

/// A client for the pub.dev API.
class PubApiClient {
  final PubClient _pubClient;
  final Duration _requestTimeout;

  PubApiClient({
    void Function(String error)? onError,
    http.Client? httpClient,
    requestTimeout = const Duration(seconds: 2),
  })  : _pubClient = PubClient(client: httpClient),
        _requestTimeout = requestTimeout;

  /// Tries to fetch the latest stable version, version does not include '-' or '+',
  /// for the package named [packageName].
  ///
  /// Returns [Null] if a new stable version could not be fetched or the request
  /// timeout duration expires.
  ///
  /// Throws a [VersionFetchException] if the request fails.
  /// Throws a [VersionParseException] if the version can not be parsed.
  Future<Version?> tryFetchLatestStableVersion(String packageName) async {
    String? latestStableVersion;
    try {
      var packageVersions = await _pubClient
          .packageVersions(packageName)
          .timeout(_requestTimeout);
      latestStableVersion = _tryGetLatestStableVersion(packageVersions);
    } catch (e, stackTrace) {
      throw VersionFetchException(
        'Failed to fetch latest version for $packageName.'
        '${_formatPubClientException(e)}',
        e,
        stackTrace,
      );
    }

    if (latestStableVersion == null) return null;

    try {
      return Version.parse(latestStableVersion);
    } catch (e, stackTrace) {
      throw VersionParseException(
        'Failed to parse version for $packageName: $latestStableVersion.',
        e,
        stackTrace,
      );
    }
  }

  String? _tryGetLatestStableVersion(List<String> packageVersions) {
    for (var version in packageVersions) {
      if (!version.contains('-') && !version.contains('+')) {
        return version;
      }
    }

    return null;
  }

  /// Required because of an issue with the pub_api_client package.
  /// Issue: https://github.com/leoafarias/pub_api_client/issues/35
  String _formatPubClientException(Object exception) {
    try {
      return exception.toString();
    } catch (_) {
      return exception.runtimeType.toString();
    }
  }

  void close() {
    _pubClient.close();
  }
}
