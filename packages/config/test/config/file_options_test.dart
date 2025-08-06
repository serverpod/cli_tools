import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:config/config.dart';

void main() async {
  group('Given a DirOption', () {
    group('with mode mayExist', () {
      const dirOpt = DirOption(
        argName: 'folder',
        mode: PathExistMode.mayExist,
        mandatory: true,
      );

      group('when passing arg that is non-existent', () {
        final config = Configuration.resolveNoExcept(
          options: [dirOpt],
          args: ['--folder', 'does-not-exist'],
        );

        test('then it is parsed successfully', () async {
          expect(config.errors, isEmpty);
          expect(
            config.value(dirOpt).path,
            equals('does-not-exist'),
          );
        });
      });

      group('when passing arg that is an existing directory', () {
        const existingDirName = 'existing-dir';
        late final String dirPath;
        late final Configuration config;

        setUp(() async {
          await d.dir(existingDirName).create();
          dirPath = p.join(d.sandbox, existingDirName);

          config = Configuration.resolveNoExcept(
            options: [dirOpt],
            args: ['--folder', dirPath],
          );
        });

        test('then it is parsed successfully', () async {
          expect(config.errors, isEmpty);
          expect(
            config.value(dirOpt).path,
            equals(dirPath),
          );
        });
      });

      group('when passing arg that is an existing file', () {
        const existingFileName = 'existing-file';
        late final String filePath;
        late final Configuration config;

        setUp(() async {
          await d.file(existingFileName).create();
          filePath = p.join(d.sandbox, existingFileName);

          config = Configuration.resolveNoExcept(
            options: [dirOpt],
            args: ['--folder', filePath],
          );
        });

        test('then it reports a "not a directory" error', () async {
          expect(config.errors, hasLength(1));
          expect(
            config.errors.single,
            equals(
              'Invalid value for option `folder`: Path "$filePath" is not a directory',
            ),
          );
        });
      });
    });

    group('with mode mustExist', () {
      const dirOpt = DirOption(
        argName: 'folder',
        mode: PathExistMode.mustExist,
        mandatory: true,
      );

      group('when passing arg that is non-existent', () {
        final config = Configuration.resolveNoExcept(
          options: [dirOpt],
          args: ['--folder', 'does-not-exist'],
        );

        test('then it reports a "does not exist" error', () async {
          expect(config.errors, hasLength(1));
          expect(
            config.errors.single,
            equals(
              'Invalid value for option `folder`: Directory "does-not-exist" does not exist',
            ),
          );
        });
      });

      group('when passing arg that is an existing directory', () {
        const existingDirName = 'existing-dir';
        late final String dirPath;
        late final Configuration config;

        setUp(() async {
          await d.dir(existingDirName).create();
          dirPath = p.join(d.sandbox, existingDirName);

          config = Configuration.resolveNoExcept(
            options: [dirOpt],
            args: ['--folder', dirPath],
          );
        });

        test('then it is parsed successfully', () async {
          expect(config.errors, isEmpty);
          expect(
            config.value(dirOpt).path,
            equals(dirPath),
          );
        });
      });

      group('when passing arg that is an existing file', () {
        const existingFileName = 'existing-file';
        late final String filePath;
        late final Configuration config;

        setUp(() async {
          await d.file(existingFileName).create();
          filePath = p.join(d.sandbox, existingFileName);

          config = Configuration.resolveNoExcept(
            options: [dirOpt],
            args: ['--folder', filePath],
          );
        });

        test('then it reports a "not a directory" error', () async {
          expect(config.errors, hasLength(1));
          expect(
            config.errors.single,
            equals(
              'Invalid value for option `folder`: Path "$filePath" is not a directory',
            ),
          );
        });
      });
    });

    group('with mode mustNotExist', () {
      const dirOpt = DirOption(
        argName: 'folder',
        mode: PathExistMode.mustNotExist,
        mandatory: true,
      );

      group('when passing arg that is non-existent', () {
        final config = Configuration.resolveNoExcept(
          options: [dirOpt],
          args: ['--folder', 'does-not-exist'],
        );

        test('then it is parsed successfully', () async {
          expect(config.errors, isEmpty);
          expect(
            config.value(dirOpt).path,
            equals('does-not-exist'),
          );
        });
      });

      group('when passing arg that is an existing directory', () {
        const existingDirName = 'existing-dir';
        late final String dirPath;
        late final Configuration config;

        setUp(() async {
          await d.dir(existingDirName).create();
          dirPath = p.join(d.sandbox, existingDirName);

          config = Configuration.resolveNoExcept(
            options: [dirOpt],
            args: ['--folder', dirPath],
          );
        });

        test('then it reports an "already exists" error', () async {
          expect(config.errors, hasLength(1));
          expect(
            config.errors.single,
            equals(
              'Invalid value for option `folder`: Path "$dirPath" already exists',
            ),
          );
        });
      });

      group('when passing arg that is an existing file', () {
        const existingFileName = 'existing-file';
        late final String filePath;
        late final Configuration config;

        setUp(() async {
          await d.file(existingFileName).create();
          filePath = p.join(d.sandbox, existingFileName);

          config = Configuration.resolveNoExcept(
            options: [dirOpt],
            args: ['--folder', filePath],
          );
        });

        test('then it reports an "already exists" error', () async {
          expect(config.errors, hasLength(1));
          expect(
            config.errors.single,
            equals(
              'Invalid value for option `folder`: Path "$filePath" already exists',
            ),
          );
        });
      });
    });
  });

  group('Given a FileOption', () {
    group('with mode mayExist', () {
      const fileOpt = FileOption(
        argName: 'file',
        mode: PathExistMode.mayExist,
        mandatory: true,
      );

      group('when passing arg that is non-existent', () {
        final config = Configuration.resolveNoExcept(
          options: [fileOpt],
          args: ['--file', 'does-not-exist'],
        );

        test('then it is parsed successfully', () async {
          expect(config.errors, isEmpty);
          expect(
            config.value(fileOpt).path,
            equals('does-not-exist'),
          );
        });
      });

      group('when passing arg that is an existing directory', () {
        const existingDirName = 'existing-dir';
        late final String dirPath;
        late final Configuration config;

        setUp(() async {
          await d.dir(existingDirName).create();
          dirPath = p.join(d.sandbox, existingDirName);

          config = Configuration.resolveNoExcept(
            options: [fileOpt],
            args: ['--file', dirPath],
          );
        });

        test('then it reports a "not a directory" error', () async {
          expect(config.errors, hasLength(1));
          expect(
            config.errors.single,
            equals(
              'Invalid value for option `file`: Path "$dirPath" is not a file',
            ),
          );
        });
      });

      group('when passing arg that is an existing file', () {
        const existingFileName = 'existing-file';
        late final String filePath;
        late final Configuration config;

        setUp(() async {
          await d.file(existingFileName).create();
          filePath = p.join(d.sandbox, existingFileName);

          config = Configuration.resolveNoExcept(
            options: [fileOpt],
            args: ['--file', filePath],
          );
        });

        test('then it is parsed successfully', () async {
          expect(config.errors, isEmpty);
          expect(
            config.value(fileOpt).path,
            equals(filePath),
          );
        });
      });
    });

    group('with mode mustExist', () {
      const fileOpt = FileOption(
        argName: 'file',
        mode: PathExistMode.mustExist,
        mandatory: true,
      );

      group('when passing arg that is non-existent', () {
        final config = Configuration.resolveNoExcept(
          options: [fileOpt],
          args: ['--file', 'does-not-exist'],
        );

        test('then it reports a "does not exist" error', () async {
          expect(config.errors, hasLength(1));
          expect(
            config.errors.single,
            equals(
              'Invalid value for option `file`: File "does-not-exist" does not exist',
            ),
          );
        });
      });

      group('when passing arg that is an existing directory', () {
        const existingDirName = 'existing-dir';
        late final String dirPath;
        late final Configuration config;

        setUp(() async {
          await d.dir(existingDirName).create();
          dirPath = p.join(d.sandbox, existingDirName);

          config = Configuration.resolveNoExcept(
            options: [fileOpt],
            args: ['--file', dirPath],
          );
        });

        test('then it reports a "not a directory" error', () async {
          expect(config.errors, hasLength(1));
          expect(
            config.errors.single,
            equals(
              'Invalid value for option `file`: Path "$dirPath" is not a file',
            ),
          );
        });
      });

      group('when passing arg that is an existing file', () {
        const existingFileName = 'existing-file';
        late final String filePath;
        late final Configuration config;

        setUp(() async {
          await d.file(existingFileName).create();
          filePath = p.join(d.sandbox, existingFileName);

          config = Configuration.resolveNoExcept(
            options: [fileOpt],
            args: ['--file', filePath],
          );
        });

        test('then it is parsed successfully', () async {
          expect(config.errors, isEmpty);
          expect(
            config.value(fileOpt).path,
            equals(filePath),
          );
        });
      });
    });

    group('with mode mustNotExist', () {
      const fileOpt = FileOption(
        argName: 'file',
        mode: PathExistMode.mustNotExist,
        mandatory: true,
      );

      group('when passing arg that is non-existent', () {
        final config = Configuration.resolveNoExcept(
          options: [fileOpt],
          args: ['--file', 'does-not-exist'],
        );

        test('then it is parsed successfully', () async {
          expect(config.errors, isEmpty);
          expect(
            config.value(fileOpt).path,
            equals('does-not-exist'),
          );
        });
      });

      group('when passing arg that is an existing directory', () {
        const existingDirName = 'existing-dir';
        late final String dirPath;
        late final Configuration config;

        setUp(() async {
          await d.dir(existingDirName).create();
          dirPath = p.join(d.sandbox, existingDirName);

          config = Configuration.resolveNoExcept(
            options: [fileOpt],
            args: ['--file', dirPath],
          );
        });

        test('then it reports an "already exists" error', () async {
          expect(config.errors, hasLength(1));
          expect(
            config.errors.single,
            equals(
              'Invalid value for option `file`: Path "$dirPath" already exists',
            ),
          );
        });
      });

      group('when passing arg that is an existing file', () {
        const existingFileName = 'existing-file';
        late final String filePath;
        late final Configuration config;

        setUp(() async {
          await d.file(existingFileName).create();
          filePath = p.join(d.sandbox, existingFileName);

          config = Configuration.resolveNoExcept(
            options: [fileOpt],
            args: ['--file', filePath],
          );
        });

        test('then it reports an "already exists" error', () async {
          expect(config.errors, hasLength(1));
          expect(
            config.errors.single,
            equals(
              'Invalid value for option `file`: Path "$filePath" already exists',
            ),
          );
        });
      });
    });
  });
}
