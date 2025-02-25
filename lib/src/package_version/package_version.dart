import 'package:pub_semver/pub_semver.dart';

/// Constants for the package version.
abstract class PackageVersionConstants {
  static const badConnectionRetryTimeout = Duration(hours: 1);
  static const localStorageValidityTime = Duration(days: 1);
}

/// A class that provides methods to fetch, store and validate the latest
/// package version with reasonable caching.
abstract class PackageVersion {
  /// Fetches the latest package version.
  /// If the stored version exists and is valid, it will be returned.
  /// Otherwise, the latest version will be fetched.
  /// If the fetch is successful the version will be stored and returned with
  /// a validity time of [PackageVersionConstants.localStorageValidityTime].
  ///
  /// If the fetch is unsuccessful, a timeout for
  /// [PackageVersionConstants.badConnectionRetryTimeout] is enforced before
  /// attempting to fetch the latest version again.
  static Future<Version?> fetchLatestPackageVersion({
    required Future<void> Function(PackageVersionData versionArtefact)
        storePackageVersionData,
    required Future<PackageVersionData?> Function() loadPackageVersionData,
    required Future<Version?> Function() fetchLatestPackageVersion,
  }) async {
    var storedVersionData = await loadPackageVersionData();

    if (storedVersionData != null && _validVersion(storedVersionData)) {
      return storedVersionData.version;
    }

    var latestPackageVersion = await fetchLatestPackageVersion();

    await _storePubDevVersion(
      latestPackageVersion,
      storePackageVersionData: storePackageVersionData,
    );

    return latestPackageVersion;
  }

  static bool _validVersion(PackageVersionData versionData) {
    return versionData.validUntil.isAfter(DateTime.now());
  }

  static Future<void> _storePubDevVersion(
    Version? version, {
    required Future<void> Function(PackageVersionData versionArtefact)
        storePackageVersionData,
  }) async {
    PackageVersionData versionArtefact;
    if (version != null) {
      versionArtefact = PackageVersionData(
        version,
        DateTime.now().add(PackageVersionConstants.localStorageValidityTime),
      );
    } else {
      versionArtefact = PackageVersionData(
        Version.none,
        DateTime.now().add(PackageVersionConstants.badConnectionRetryTimeout),
      );
    }

    await storePackageVersionData(versionArtefact);
  }
}

/// A class that holds the package version and the validity time that can be
/// stored and retrieved from a local storage.
class PackageVersionData {
  Version version;
  DateTime validUntil;

  PackageVersionData(this.version, this.validUntil);

  factory PackageVersionData.fromJson(Map<String, dynamic> json) =>
      PackageVersionData(
        Version.parse(json['version']),
        DateTime.fromMillisecondsSinceEpoch(json['valid_until']),
      );

  Map<String, dynamic> toJson() => {
        'version': version.toString(),
        'valid_until': validUntil.millisecondsSinceEpoch,
      };
}
