import 'package:http/http.dart' as http;
import 'package:pub_api_client/pub_api_client.dart';
import 'package:pub_semver/pub_semver.dart';

/// A client for the pub.dev API.
class PubApiClient {
  final PubClient _pubClient;
  final Duration _requestTimeout;
  final void Function(String error)? _onError;

  PubApiClient({
    void Function(String error)? onError,
    http.Client? httpClient,
    requestTimeout = const Duration(seconds: 2),
  })  : _pubClient = PubClient(client: httpClient),
        _requestTimeout = requestTimeout,
        _onError = onError;

  /// Tries to fetch the latest stable version, version does not include '-' or '+',
  /// for the package named [packageName].
  ///
  /// If it fails [Null] is returned.
  Future<Version?> tryFetchLatestStableVersion(String packageName) async {
    String? latestStableVersion;
    try {
      var packageVersions = await _pubClient
          .packageVersions(packageName)
          .timeout(_requestTimeout);
      latestStableVersion = _tryGetLatestStableVersion(packageVersions);
    } catch (e) {
      _onError?.call('Failed to fetch latest version for $packageName.');
      _logPubClientException(e);
      return null;
    }

    if (latestStableVersion == null) return null;

    try {
      return Version.parse(latestStableVersion);
    } catch (e) {
      _onError
          ?.call('Failed to parse version for $packageName: ${e.toString()}');
      return null;
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
  void _logPubClientException(Object exception) {
    try {
      _onError?.call(exception.toString());
    } catch (_) {
      _onError?.call(exception.runtimeType.toString());
    }
  }

  void close() {
    _pubClient.close();
  }
}
