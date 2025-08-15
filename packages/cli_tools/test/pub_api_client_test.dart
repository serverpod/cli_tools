import 'dart:io';

import 'package:cli_tools/package_version.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

MockClient createMockClient({
  required final String body,
  required final int status,
  final Duration responseDelay = const Duration(seconds: 0),
}) {
  return MockClient((final request) {
    if (request.method != 'GET') throw NoSuchMethodError;
    return Future<http.Response>(() async {
      await Future.delayed(responseDelay);
      return http.Response(body, status);
    });
  });
}

abstract class PubApiClientTestConstants {
  static const String testPackageName = 'serverpod_cli';
}

void main() {
  test(
    'Empty body and not found status response when fetching latest version exception with message is thrown.',
    () async {
      // Issue: https://github.com/leoafarias/pub_api_client/issues/35
      final httpClient =
          createMockClient(body: '', status: HttpStatus.notFound);
      final pubApiClient = PubApiClient(httpClient: httpClient);

      await expectLater(
        pubApiClient.tryFetchLatestStableVersion(
          PubApiClientTestConstants.testPackageName,
        ),
        throwsA(
          isA<VersionFetchException>().having(
            (final e) => e.message,
            'message',
            contains('Failed to fetch latest version for'),
          ),
        ),
      );
    },
  );

  test(
    'Empty body and not found status response when fetching latest version then returns null.',
    () async {
      // Issue: https://github.com/leoafarias/pub_api_client/issues/35
      final httpClient =
          createMockClient(body: '', status: HttpStatus.notFound);
      final pubApiClient = PubApiClient(httpClient: httpClient);

      await expectLater(
        pubApiClient.tryFetchLatestStableVersion(
          PubApiClientTestConstants.testPackageName,
        ),
        throwsA(
          isA<VersionFetchException>().having(
            (final e) => e.message,
            'message',
            contains('Failed to fetch latest version for'),
          ),
        ),
      );
    },
  );

  test(
    'Timeout is reached when fetching latest version then throws version fetch exception.',
    () async {
      const timeout = Duration(milliseconds: 1);
      final httpClient = createMockClient(
        body: '',
        status: HttpStatus.ok,
        responseDelay:
            timeout * 10, // Messaged is delayed longer than the timeout
      );
      final pubApiClient = PubApiClient(
        httpClient: httpClient,
        requestTimeout: timeout,
      );

      await expectLater(
        pubApiClient.tryFetchLatestStableVersion(
          PubApiClientTestConstants.testPackageName,
        ),
        throwsA(isA<VersionFetchException>()),
      );
    },
  );

  test(
    'Non stable version before stable version when fetching latest then returns first stable',
    () async {
      final expectedVersion = Version(1, 2, 3);
      final httpClient = createMockClient(
        body: '''
{
    "name": "${PubApiClientTestConstants.testPackageName}",
    "versions": ["1.2.5-b", "1.2.4+a", "${expectedVersion.toString()}"]
}
''',
        status: HttpStatus.ok,
      );
      final pubApiClient = PubApiClient(httpClient: httpClient);

      final version = await pubApiClient.tryFetchLatestStableVersion(
        PubApiClientTestConstants.testPackageName,
      );

      expect(version, isNotNull);
      expect(version, expectedVersion);
    },
  );

  test(
    'Only non stable versions when fetching latest then returns null',
    () async {
      final httpClient = createMockClient(
        body: '''
{
    "name": "${PubApiClientTestConstants.testPackageName}",
    "versions": ["1.2.5-b", "1.2.4+a"]
}
''',
        status: HttpStatus.ok,
      );
      final pubApiClient = PubApiClient(httpClient: httpClient);

      final version = await pubApiClient.tryFetchLatestStableVersion(
        PubApiClientTestConstants.testPackageName,
      );

      expect(version, isNull);
    },
  );

  test(
    'Invalid version format when fetching latest from pub.dev then throws version parse exception.',
    () async {
      final httpClient = createMockClient(
        body: '''
{
    "name": "${PubApiClientTestConstants.testPackageName}",
    "versions": ["invalid_format"]
}
''',
        status: HttpStatus.ok,
      );
      final pubApiClient = PubApiClient(httpClient: httpClient);

      await expectLater(
        pubApiClient.tryFetchLatestStableVersion(
          PubApiClientTestConstants.testPackageName,
        ),
        throwsA(isA<VersionParseException>()),
      );
    },
  );
}
