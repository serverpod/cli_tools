import 'dart:io';

import 'package:args/command_runner.dart';

import 'configuration.dart';

enum PathExistMode {
  mayExist,
  mustExist,
  mustNotExist,
}

class DirParser extends ValueParser<Directory> {
  const DirParser();

  @override
  Directory parse(final String value) {
    return Directory(value);
  }
}

/// Directory path configuration option.
///
/// If the input is not valid according to the [mode],
/// the validation throws a [UsageException].
class DirOption extends ConfigOptionBase<Directory> {
  final PathExistMode mode;

  const DirOption({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.helpText,
    super.valueHelp,
    super.group,
    super.customValidator,
    super.mandatory,
    super.hide,
    this.mode = PathExistMode.mayExist,
  }) : super(valueParser: const DirParser());

  @override
  void validateValue(final Directory value) {
    super.validateValue(value);

    final type = FileSystemEntity.typeSync(value.path);
    switch (mode) {
      case PathExistMode.mayExist:
        if (type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.directory) {
          throw UsageException('Path "${value.path}" is not a directory', '');
        }
        break;
      case PathExistMode.mustExist:
        if (type == FileSystemEntityType.notFound) {
          throw UsageException('Directory "${value.path}" does not exist', '');
        }
        if (type != FileSystemEntityType.directory) {
          throw UsageException('Path "${value.path}" is not a directory', '');
        }
        break;
      case PathExistMode.mustNotExist:
        if (type != FileSystemEntityType.notFound) {
          throw UsageException('Path "${value.path}" already exists', '');
        }
        break;
    }
  }
}

class FileParser extends ValueParser<File> {
  const FileParser();

  @override
  File parse(final String value) {
    return File(value);
  }
}

/// File path configuration option.
///
/// If the input is not valid according to the [mode],
/// the validation throws a [UsageException].
class FileOption extends ConfigOptionBase<File> {
  final PathExistMode mode;

  const FileOption({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.helpText,
    super.valueHelp,
    super.group,
    super.customValidator,
    super.mandatory,
    super.hide,
    this.mode = PathExistMode.mayExist,
  }) : super(valueParser: const FileParser());

  @override
  void validateValue(final File value) {
    super.validateValue(value);

    final type = FileSystemEntity.typeSync(value.path);
    switch (mode) {
      case PathExistMode.mayExist:
        if (type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.file) {
          throw UsageException('Path "${value.path}" is not a file', '');
        }
        break;
      case PathExistMode.mustExist:
        if (type == FileSystemEntityType.notFound) {
          throw UsageException('File "${value.path}" does not exist', '');
        }
        if (type != FileSystemEntityType.file) {
          throw UsageException('Path "${value.path}" is not a file', '');
        }
        break;
      case PathExistMode.mustNotExist:
        if (type != FileSystemEntityType.notFound) {
          throw UsageException('Path "${value.path}" already exists', '');
        }
        break;
    }
  }
}
