import 'dart:async' show FutureOr;
import 'dart:io';

import 'package:path/path.dart' as p;

import 'completion.dart';
import 'exceptions.dart';
import 'options.dart';

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

  @override
  String format(final Directory value) {
    final path = value.path;
    return path.endsWith(p.separator) ? path : '$path${p.separator}';
  }
}

/// Directory path configuration option.
///
/// If the input is not valid according to the [mode],
/// the validation throws a [InvalidValueException].
class DirOption extends ConfigOptionBase<Directory> {
  final PathExistMode mode;

  const DirOption({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.configKeys,
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
          throw InvalidValueException(
            'Path "${value.path}" is not a directory',
          );
        }
        break;
      case PathExistMode.mustExist:
        if (type == FileSystemEntityType.notFound) {
          throw InvalidValueException(
            'Directory "${value.path}" does not exist',
          );
        }
        if (type != FileSystemEntityType.directory) {
          throw InvalidValueException(
            'Path "${value.path}" is not a directory',
          );
        }
        break;
      case PathExistMode.mustNotExist:
        if (type != FileSystemEntityType.notFound) {
          throw InvalidValueException('Path "${value.path}" already exists');
        }
        break;
    }
  }

  /// Offers native directory completion from the shell.
  @override
  FutureOr<CompletionResult> complete(final CompletionContext context) {
    return const CompletionResult.directories();
  }
}

class FileParser extends ValueParser<File> {
  const FileParser();

  @override
  File parse(final String value) {
    return File(value);
  }

  @override
  String format(final File value) {
    return value.path;
  }
}

/// File path configuration option.
///
/// If the input is not valid according to the [mode],
/// the validation throws a [InvalidValueException].
class FileOption extends ConfigOptionBase<File> {
  final PathExistMode mode;

  const FileOption({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.configKeys,
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
          throw InvalidValueException('Path "${value.path}" is not a file');
        }
        break;
      case PathExistMode.mustExist:
        if (type == FileSystemEntityType.notFound) {
          throw InvalidValueException('File "${value.path}" does not exist');
        }
        if (type != FileSystemEntityType.file) {
          throw InvalidValueException('Path "${value.path}" is not a file');
        }
        break;
      case PathExistMode.mustNotExist:
        if (type != FileSystemEntityType.notFound) {
          throw InvalidValueException('Path "${value.path}" already exists');
        }
        break;
    }
  }

  /// Offers native file completion from the shell.
  @override
  FutureOr<CompletionResult> complete(final CompletionContext context) {
    return const CompletionResult.files();
  }
}
