import 'package:cli_tools/package_version.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  final versionForTest = Version(1, 1, 0);

  group('Given version is returned from load', () {
    test(
      'when fetched with "valid until" time in the future then version is returned.',
      () async {
        final packageVersionData = PackageVersionData(
          versionForTest,
          DateTime.now().add(const Duration(hours: 1)),
        );

        final fetchedVersion = await PackageVersion.fetchLatestPackageVersion(
          storePackageVersionData: (final PackageVersionData _) async => (),
          loadPackageVersionData: () async => packageVersionData,
          fetchLatestPackageVersion: () async => null,
        );

        expect(fetchedVersion, isNotNull);
        expect(fetchedVersion, versionForTest);
      },
    );

    group('with "valid until" already passed', () {
      test(
        'when successful in fetching latest version from fetch then new version is stored and returned.',
        () async {
          PackageVersionData? storedPackageVersion;
          final PackageVersionData packageVersionData = PackageVersionData(
            versionForTest,
            DateTime.now().subtract(const Duration(hours: 1)),
          );
          final pubDevVersion = versionForTest.nextMajor;

          final fetchedVersion = await PackageVersion.fetchLatestPackageVersion(
            storePackageVersionData:
                (final PackageVersionData versionDataToStore) async =>
                    (storedPackageVersion = versionDataToStore),
            loadPackageVersionData: () async => packageVersionData,
            fetchLatestPackageVersion: () async => pubDevVersion,
          );

          expect(fetchedVersion, isNotNull);
          expect(fetchedVersion, pubDevVersion);
          expect(storedPackageVersion, isNotNull);
          expect(storedPackageVersion?.version, pubDevVersion);
          final timeDifferent = storedPackageVersion?.validUntil.difference(
            DateTime.now().add(
              PackageVersionConstants.localStorageValidityTime,
            ),
          );
          expect(
            timeDifferent,
            lessThan(const Duration(minutes: 1)),
            reason:
                'Successfully stored version should have a valid until time '
                'close to the current time plus the validity time.',
          );
        },
      );

      test('when failing to fetch latest then null is returned.', () async {
        PackageVersionData? storedPackageVersion;
        final version = await PackageVersion.fetchLatestPackageVersion(
          storePackageVersionData:
              (final PackageVersionData packageVersionData) async =>
                  (storedPackageVersion = packageVersionData),
          loadPackageVersionData: () async => null,
          fetchLatestPackageVersion: () async => null,
        );

        expect(version, isNull);
        expect(storedPackageVersion, isNotNull);
        final timeDifferent = storedPackageVersion?.validUntil.difference(
          DateTime.now().add(PackageVersionConstants.badConnectionRetryTimeout),
        );
        expect(
          timeDifferent,
          lessThan(const Duration(minutes: 1)),
          reason: 'Failed fetch stored version should have a valid until time '
              'close to the current time plus the bad connection retry timeout.',
        );
      });
    });
  });

  group('Given no version is returned from load', () {
    test(
      'when successful in fetching latest version then version is stored and returned.',
      () async {
        PackageVersionData? storedPackageVersion;
        final version = await PackageVersion.fetchLatestPackageVersion(
          storePackageVersionData:
              (final PackageVersionData packageVersionData) async =>
                  (storedPackageVersion = packageVersionData),
          loadPackageVersionData: () async => null,
          fetchLatestPackageVersion: () async => versionForTest,
        );

        expect(version, isNotNull);
        expect(version, versionForTest);
        expect(storedPackageVersion, isNotNull);
        expect(storedPackageVersion?.version, versionForTest);
        final timeDifferent = storedPackageVersion?.validUntil.difference(
          DateTime.now().add(PackageVersionConstants.localStorageValidityTime),
        );
        expect(
          timeDifferent,
          lessThan(const Duration(minutes: 1)),
          reason: 'Successfully stored version should have a valid until time '
              'close to the current time plus the validity time.',
        );
      },
    );

    test(
      'when failing to fetch latest then timeout is stored and null is returned.',
      () async {
        PackageVersionData? storedPackageVersion;
        final version = await PackageVersion.fetchLatestPackageVersion(
          storePackageVersionData:
              (final PackageVersionData packageVersionData) async =>
                  (storedPackageVersion = packageVersionData),
          loadPackageVersionData: () async => null,
          fetchLatestPackageVersion: () async => null,
        );

        expect(version, isNull);
        expect(storedPackageVersion, isNotNull);
        final timeDifferent = storedPackageVersion?.validUntil.difference(
          DateTime.now().add(PackageVersionConstants.badConnectionRetryTimeout),
        );
        expect(
          timeDifferent,
          lessThan(const Duration(minutes: 1)),
          reason: 'Failed fetch stored version should have a valid until time '
              'close to the current time plus the bad connection retry timeout.',
        );
      },
    );
  });
}
