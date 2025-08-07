// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: deprecated_member_use_from_same_package

import 'package:test/test.dart';

import 'package:config/config.dart';

import 'test_utils.dart';

void main() {
  group('ConfigParser.parse()', () {
    test('does not destructively modify the argument list', () {
      var parser = ConfigParser();
      parser.addFlag('verbose');

      var args = ['--verbose'];
      var results = parser.parse(args);
      expect(args, equals(['--verbose']));
      expect(results['verbose'], isTrue);
    });

    group('flags', () {
      test('are true if present', () {
        var parser = ConfigParser();
        parser.addFlag('verbose');

        var args = parser.parse(['--verbose']);
        expect(args['verbose'], isTrue);
      });

      test('default if missing', () {
        var parser = ConfigParser();
        parser.addFlag('a', defaultsTo: true);
        parser.addFlag('b', defaultsTo: false);

        var args = parser.parse([]);
        expect(args['a'], isTrue);
        expect(args['b'], isFalse);
      });

      test('are false if missing with no default', () {
        var parser = ConfigParser();
        parser.addFlag('verbose');

        var args = parser.parse([]);
        expect(args['verbose'], isFalse);
      });

      test('throws if given a value', () {
        var parser = ConfigParser();
        parser.addFlag('verbose');

        throwsFormat(parser, ['--verbose=true']);
      });

      test('are case-sensitive', () {
        var parser = ConfigParser();
        parser.addFlag('verbose');
        parser.addFlag('Verbose');
        var results = parser.parse(['--verbose']);
        expect(results['verbose'], isTrue);
        expect(results['Verbose'], isFalse);
      });

      test('match letters, numbers, hyphens and underscores', () {
        var parser = ConfigParser();
        var allCharacters =
            'abcdefghijklmnopqrstuvwxyz-ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789';
        parser.addFlag(allCharacters);
        var results = parser.parse(['--$allCharacters']);
        expect(results[allCharacters], isTrue);
      });

      test('can match by alias', () {
        var parser = ConfigParser()..addFlag('a', aliases: ['b']);
        var results = parser.parse(['--b']);
        expect(results['a'], isTrue);
      });

      test('can be negated by alias', () {
        var parser = ConfigParser()
          ..addFlag('a', aliases: ['b'], defaultsTo: true, negatable: true);
        var results = parser.parse(['--no-b']);
        expect(results['a'], isFalse);
      });

      test('throws if requested as a multi-option', () {
        var parser = ConfigParser();
        parser.addFlag('a', defaultsTo: true);
        var results = parser.parse(['--a']);
        throwsIllegalArg(() => results.multiOption('a'));
      });
    });

    group('flag()', () {
      test('returns true if present', () {
        var parser = ConfigParser();
        parser.addFlag('verbose');

        var args = parser.parse(['--verbose']);
        expect(args.flag('verbose'), isTrue);
      });

      test('returns default if missing', () {
        var parser = ConfigParser();
        parser.addFlag('a', defaultsTo: true);
        parser.addFlag('b', defaultsTo: false);

        var args = parser.parse([]);
        expect(args.flag('a'), isTrue);
        expect(args.flag('b'), isFalse);
      });

      test('are false if missing with no default', () {
        var parser = ConfigParser();
        parser.addFlag('verbose');

        var args = parser.parse([]);
        expect(args.flag('verbose'), isFalse);
      });

      test('are case-sensitive', () {
        var parser = ConfigParser();
        parser.addFlag('verbose');
        parser.addFlag('Verbose');
        var results = parser.parse(['--verbose']);
        expect(results.flag('verbose'), isTrue);
        expect(results.flag('Verbose'), isFalse);
      });

      test('match letters, numbers, hyphens and underscores', () {
        var parser = ConfigParser();
        var allCharacters =
            'abcdefghijklmnopqrstuvwxyz-ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789';
        parser.addFlag(allCharacters);
        var results = parser.parse(['--$allCharacters']);
        expect(results.flag(allCharacters), isTrue);
      });

      test('can match by alias', () {
        var parser = ConfigParser()..addFlag('a', aliases: ['b']);
        var results = parser.parse(['--b']);
        expect(results.flag('a'), isTrue);
      });

      test('can be negated by alias', () {
        var parser = ConfigParser()
          ..addFlag('a', aliases: ['b'], defaultsTo: true, negatable: true);
        var results = parser.parse(['--no-b']);
        expect(results.flag('a'), isFalse);
      });

      test('throws if requested as a multi-option', () {
        var parser = ConfigParser();
        parser.addFlag('a', defaultsTo: true);
        var results = parser.parse(['--a']);
        throwsIllegalArg(() => results.multiOption('a'));
      });
    });

    group('flags negated with "no-"', () {
      test('set the flag to false', () {
        var parser = ConfigParser();
        parser.addFlag('verbose');

        var args = parser.parse(['--no-verbose']);
        expect(args['verbose'], isFalse);
      });

      test('set the flag to true if the flag actually starts with "no-"', () {
        var parser = ConfigParser();
        parser.addFlag('no-body');

        var args = parser.parse(['--no-body']);
        expect(args['no-body'], isTrue);
      });

      test('are not preferred over a colliding one without', () {
        var parser = ConfigParser();
        parser.addFlag('no-strum');
        parser.addFlag('strum');

        var args = parser.parse(['--no-strum']);
        expect(args['no-strum'], isTrue);
        expect(args['strum'], isFalse);
      });

      test('fail for non-negatable flags', () {
        var parser = ConfigParser();
        parser.addFlag('strum', negatable: false);

        throwsFormat(parser, ['--no-strum']);
      });
    });

    group('callbacks', () {
      test('for present flags are invoked with the value', () {
        bool? a;
        var parser = ConfigParser();
        parser.addFlag('a', callback: (value) => a = value);

        parser.parse(['--a']);
        expect(a, isTrue);
      });

      test('for absent flags are invoked with the default value', () {
        bool? a;
        var parser = ConfigParser();
        parser.addFlag('a', defaultsTo: false, callback: (value) => a = value);

        parser.parse([]);
        expect(a, isFalse);
      });

      test('are invoked even if the flag is not present', () {
        var a = true;
        var parser = ConfigParser();
        parser.addFlag('a', callback: (value) => a = value);

        parser.parse([]);
        expect(a, isFalse);
      });

      test('for present options are invoked with the value', () {
        String? a;
        var parser = ConfigParser();
        parser.addOption('a', callback: (value) => a = value);

        parser.parse(['--a=v']);
        expect(a, equals('v'));
      });

      test('for absent options are invoked with the default value', () {
        var parser = ConfigParser();
        parser.addOption('a',
            defaultsTo: 'v',
            callback: expectAsync1((value) => expect(value, 'v')));

        parser.parse([]);
      });

      test('for absent options are invoked with null if there is no default',
          () {
        var parser = ConfigParser();
        parser.addOption('a',
            callback: expectAsync1((value) => expect(value, isNull)));

        parser.parse([]);
      });

      group('with addMultiOption', () {
        test('for multiple present, options are invoked with value as a list',
            () {
          List<String>? a;
          var parser = ConfigParser();
          parser.addMultiOption('a', callback: (value) => a = value);

          parser.parse(['--a=v', '--a=x']);
          expect(a, equals(['v', 'x']));

          // This reified type is important in strong mode so that people can
          // safely write "as List<String>".
          expect(a, isA<List<String>>());
        });

        test(
            'for single present, options are invoked with value as a single '
            'element list', () {
          List<String>? a;
          var parser = ConfigParser();
          parser.addMultiOption('a', callback: (value) => a = value);

          parser.parse(['--a=v']);
          expect(a, equals(['v']));
        });

        test('for absent, options are invoked with default value', () {
          List<String>? a;
          var parser = ConfigParser();
          parser.addMultiOption('a',
              defaultsTo: ['v', 'w'], callback: (value) => a = value);

          parser.parse([]);
          expect(a, equals(['v', 'w']));
        });

        test('for absent, options are invoked with value as an empty list', () {
          List<String>? a;
          var parser = ConfigParser();
          parser.addMultiOption('a', callback: (value) => a = value);

          parser.parse([]);
          expect(a, isEmpty);
        });

        test('parses comma-separated strings', () {
          List<String>? a;
          var parser = ConfigParser();
          parser.addMultiOption('a', callback: (value) => a = value);

          parser.parse(['--a=v,w', '--a=x']);
          expect(a, equals(['v', 'w', 'x']));
        });

        test("doesn't parse comma-separated strings with splitCommas: false",
            () {
          List<String>? a;
          var parser = ConfigParser();
          parser.addMultiOption('a',
              splitCommas: false, callback: (value) => a = value);

          parser.parse(['--a=v,w', '--a=x']);
          expect(a, equals(['v,w', 'x']));
        });

        test('parses empty strings', () {
          List<String>? a;
          var parser = ConfigParser();
          parser.addMultiOption('a', callback: (value) => a = value);

          parser.parse(['--a=,v', '--a=w,', '--a=,', '--a=x,,y', '--a', '']);
          expect(a, equals(['', 'v', 'w', '', '', '', 'x', '', 'y', '']));
        });

        test('with allowed parses comma-separated strings', () {
          List<String>? a;
          var parser = ConfigParser();
          parser.addMultiOption('a',
              allowed: ['v', 'w', 'x'], callback: (value) => a = value);

          parser.parse(['--a=v,w', '--a=x']);
          expect(a, equals(['v', 'w', 'x']));
        });

        test('can mix and match alias and regular name', () {
          var parser = ConfigParser()..addMultiOption('a', aliases: ['b']);
          var results = parser.parse(['--a=1', '--b=2']);
          expect(results['a'], ['1', '2']);
        });
      });
    });

    group('abbreviations', () {
      test('are parsed with a preceding "-"', () {
        var parser = ConfigParser();
        parser.addFlag('arg', abbr: 'a');

        var args = parser.parse(['-a']);
        expect(args['arg'], isTrue);
      });

      test('can use multiple after a single "-"', () {
        var parser = ConfigParser();
        parser.addFlag('first', abbr: 'f');
        parser.addFlag('second', abbr: 's');
        parser.addFlag('third', abbr: 't');

        var args = parser.parse(['-tf']);
        expect(args['first'], isTrue);
        expect(args['second'], isFalse);
        expect(args['third'], isTrue);
      });

      test('can have multiple "-" args', () {
        var parser = ConfigParser();
        parser.addFlag('first', abbr: 'f');
        parser.addFlag('second', abbr: 's');
        parser.addFlag('third', abbr: 't');

        var args = parser.parse(['-s', '-tf']);
        expect(args['first'], isTrue);
        expect(args['second'], isTrue);
        expect(args['third'], isTrue);
      });

      test('can take arguments without a space separating', () {
        var parser = ConfigParser();
        parser.addOption('file', abbr: 'f');

        var args = parser.parse(['-flip']);
        expect(args['file'], equals('lip'));
      });

      test('can take arguments with a space separating', () {
        var parser = ConfigParser();
        parser.addOption('file', abbr: 'f');

        var args = parser.parse(['-f', 'name']);
        expect(args['file'], equals('name'));
      });

      test('allow non-option characters in the value', () {
        var parser = ConfigParser();
        parser.addOption('apple', abbr: 'a');

        var args = parser.parse(['-ab?!c']);
        expect(args['apple'], equals('b?!c'));
      });

      test('throw if unknown', () {
        var parser = ConfigParser();
        throwsFormat(parser, ['-f']);
      });

      test('throw if the value is missing', () {
        var parser = ConfigParser();
        parser.addOption('file', abbr: 'f');

        throwsFormat(parser, ['-f']);
      });

      test('does not throw if the value looks like an option', () {
        var parser = ConfigParser();
        parser.addOption('file', abbr: 'f');
        parser.addOption('other');

        expect(parser.parse(['-f', '--other'])['file'], equals('--other'));
        expect(parser.parse(['-f', '--unknown'])['file'], equals('--unknown'));
        expect(parser.parse(['-f', '-abbr'])['file'], equals('-abbr'));
        expect(parser.parse(['-f', '--'])['file'], equals('--'));
      });

      test('throw if the value is not allowed', () {
        var parser = ConfigParser();
        parser.addOption('mode', abbr: 'm', allowed: ['debug', 'release']);

        throwsUsageException(parser, ['-mprofile']);
      });

      group('throw if a comma-separated value is not allowed', () {
        test('with addMultiOption', () {
          var parser = ConfigParser();
          parser
              .addMultiOption('mode', abbr: 'm', allowed: ['debug', 'release']);

          throwsUsageException(parser, ['-mdebug,profile']);
        });
      });

      test('throw if any but the first is not a flag', () {
        var parser = ConfigParser();
        parser.addFlag('apple', abbr: 'a');
        parser.addOption('banana', abbr: 'b'); // Takes an argument.
        parser.addFlag('cherry', abbr: 'c');

        throwsFormat(parser, ['-abc']);
      });

      test('throw if it has a value but the option is a flag', () {
        var parser = ConfigParser();
        parser.addFlag('apple', abbr: 'a');
        parser.addFlag('banana', abbr: 'b');

        // The '?!' means this can only be understood as '--apple b?!c'.
        throwsFormat(parser, ['-ab?!c']);
      });

      test('are case-sensitive', () {
        var parser = ConfigParser();
        parser.addFlag('file', abbr: 'f');
        parser.addFlag('force', abbr: 'F');
        var results = parser.parse(['-f']);
        expect(results['file'], isTrue);
        expect(results['force'], isFalse);
      });
    });

    group('options', () {
      test('are parsed if present', () {
        var parser = ConfigParser();
        parser.addOption('mode');
        var args = parser.parse(['--mode=release']);
        expect(args['mode'], equals('release'));
      });

      test('are null if not present', () {
        var parser = ConfigParser();
        parser.addOption('mode');
        var args = parser.parse([]);
        expect(args['mode'], isNull);
      });

      test('default if missing', () {
        var parser = ConfigParser();
        parser.addOption('mode', defaultsTo: 'debug');
        var args = parser.parse([]);
        expect(args['mode'], equals('debug'));
      });

      test('allow the value to be separated by whitespace', () {
        var parser = ConfigParser();
        parser.addOption('mode');
        var args = parser.parse(['--mode', 'release']);
        expect(args['mode'], equals('release'));
      });

      test('throw if unknown', () {
        var parser = ConfigParser();
        throwsFormat(parser, ['--unknown']);
        throwsFormat(parser, ['--nobody']); // Starts with "no".
      });

      test('throw if the arg does not include a value', () {
        var parser = ConfigParser();
        parser.addOption('mode');
        throwsFormat(parser, ['--mode']);
      });

      test('do not throw if the value looks like an option', () {
        var parser = ConfigParser();
        parser.addOption('mode');
        parser.addOption('other');

        expect(parser.parse(['--mode', '--other'])['mode'], equals('--other'));
        expect(
            parser.parse(['--mode', '--unknown'])['mode'], equals('--unknown'));
        expect(parser.parse(['--mode', '-abbr'])['mode'], equals('-abbr'));
        expect(parser.parse(['--mode', '--'])['mode'], equals('--'));
      });

      test('do not throw if the value is in the allowed set', () {
        var parser = ConfigParser();
        parser.addOption('mode', allowed: ['debug', 'release']);
        var args = parser.parse(['--mode=debug']);
        expect(args['mode'], equals('debug'));
      });

      test('do not throw if there is no allowed set with allowedHelp', () {
        var parser = ConfigParser();
        parser.addOption('mode', allowedHelp: {
          'debug': 'During development.',
          'release': 'For customers.'
        });
        var args = parser.parse(['--mode=profile']);
        expect(args['mode'], equals('profile'));
      });

      test('throw if the value is not in the allowed set', () {
        var parser = ConfigParser();
        parser.addOption('mode', allowed: ['debug', 'release']);
        throwsUsageException(parser, ['--mode=profile']);
      });

      test('returns last provided value', () {
        var parser = ConfigParser();
        parser.addOption('define');
        var args = parser.parse(['--define=1', '--define=2']);
        expect(args['define'], equals('2'));
      });

      test('throw if requested as a multi-option', () {
        var parser = ConfigParser();
        parser.addOption('a', defaultsTo: 'b');
        var results = parser.parse(['--a=c']);
        throwsIllegalArg(() => results.multiOption('a'));
      });

      group('returns a List', () {
        test('with addMultiOption', () {
          var parser = ConfigParser();
          parser.addMultiOption('define');
          var args = parser.parse(['--define=1']);
          expect(args['define'], equals(['1']));
          args = parser.parse(['--define=1', '--define=2']);
          expect(args['define'], equals(['1', '2']));
        });
      });

      group('returns the default value if not explicitly set', () {
        test('with addMultiOption', () {
          var parser = ConfigParser();
          parser.addMultiOption('define', defaultsTo: ['0']);
          // var args = parser.parse(['']);
          var args = parser.parse([]);
          expect(args['define'], equals(['0']));
        });
      });

      test('are case-sensitive', () {
        var parser = ConfigParser();
        parser.addOption('verbose', defaultsTo: 'no');
        parser.addOption('Verbose', defaultsTo: 'no');
        var results = parser.parse(['--verbose', 'chatty']);
        expect(results['verbose'], equals('chatty'));
        expect(results['Verbose'], equals('no'));
      });

      test('can be set by alias', () {
        var parser = ConfigParser()..addOption('a', aliases: ['b']);
        var results = parser.parse(['--b=1']);
        expect(results['a'], '1');
      });

      group('mandatory', () {
        test('throw if no args', () {
          var parser = ConfigParser();
          parser.addOption('username', mandatory: true);
          var results = parser.parse([]);
          expect(() => results['username'], throwsA(isA<ArgumentError>()));
        });

        test('throw if no mandatory args', () {
          var parser = ConfigParser();
          parser.addOption('test');
          parser.addOption('username', mandatory: true);
          var results = parser.parse(['--test', 'test']);
          expect(results['test'], equals('test'));
          expect(() => results['username'], throwsA(isA<ArgumentError>()));
        });

        test('parse successfully', () {
          var parser = ConfigParser();
          parser.addOption('test', mandatory: true);
          var results = parser.parse(['--test', 'test']);
          expect(results['test'], equals('test'));
        });

        test('throws when value retrieved', () {
          var parser = ConfigParser();
          parser.addFlag('help', abbr: 'h', negatable: false);
          parser.addOption('test', mandatory: true);
          var results = parser.parse(['-h']);
          expect(results['help'], true);
          expect(() => results['test'], throwsA(isA<ArgumentError>()));
          expect(() => results.option('test'), throwsA(isA<ArgumentError>()));
        });
      }, skip: 'different error types');
    });

    group('option()', () {
      test('are parsed if present', () {
        var parser = ConfigParser();
        parser.addOption('mode');
        var args = parser.parse(['--mode=release']);
        expect(args.option('mode'), equals('release'));
      });

      test('are null if not present', () {
        var parser = ConfigParser();
        parser.addOption('mode');
        var args = parser.parse([]);
        expect(args.option('mode'), isNull);
      });

      test('default if missing', () {
        var parser = ConfigParser();
        parser.addOption('mode', defaultsTo: 'debug');
        var args = parser.parse([]);
        expect(args.option('mode'), equals('debug'));
      });

      test('allow the value to be separated by whitespace', () {
        var parser = ConfigParser();
        parser.addOption('mode');
        var args = parser.parse(['--mode', 'release']);
        expect(args.option('mode'), equals('release'));
      });

      test('do not throw if the value is in the allowed set', () {
        var parser = ConfigParser();
        parser.addOption('mode', allowed: ['debug', 'release']);
        var args = parser.parse(['--mode=debug']);
        expect(args.option('mode'), equals('debug'));
      });

      test('do not throw if there is no allowed set with allowedHelp', () {
        var parser = ConfigParser();
        parser.addOption('mode', allowedHelp: {
          'debug': 'During development.',
          'release': 'For customers.'
        });
        var args = parser.parse(['--mode=profile']);
        expect(args.option('mode'), equals('profile'));
      });

      test('returns last provided value', () {
        var parser = ConfigParser();
        parser.addOption('define');
        var args = parser.parse(['--define=1', '--define=2']);
        expect(args.option('define'), equals('2'));
      });

      test('throw if requested as a multi-option', () {
        var parser = ConfigParser();
        parser.addOption('a', defaultsTo: 'b');
        var results = parser.parse(['--a=c']);
        throwsIllegalArg(() => results.multiOption('a'));
      });

      group('returns a List', () {
        test('with addMultiOption', () {
          var parser = ConfigParser();
          parser.addMultiOption('define');
          var args = parser.parse(['--define=1']);
          expect(args.multiOption('define'), equals(['1']));
          args = parser.parse(['--define=1', '--define=2']);
          expect(args.multiOption('define'), equals(['1', '2']));
        });
      });

      group('returns the default value if not explicitly set', () {
        test('with addMultiOption', () {
          var parser = ConfigParser();
          parser.addMultiOption('define', defaultsTo: ['0']);
          // var args = parser.parse(['']);
          var args = parser.parse([]);
          expect(args.multiOption('define'), equals(['0']));
        });
      });

      test('are case-sensitive', () {
        var parser = ConfigParser();
        parser.addOption('verbose', defaultsTo: 'no');
        parser.addOption('Verbose', defaultsTo: 'no');
        var results = parser.parse(['--verbose', 'chatty']);
        expect(results.option('verbose'), equals('chatty'));
        expect(results.option('Verbose'), equals('no'));
      });

      test('can be set by alias', () {
        var parser = ConfigParser()..addOption('a', aliases: ['b']);
        var results = parser.parse(['--b=1']);
        expect(results.option('a'), '1');
      });

      group('mandatory', () {
        test('parse successfully', () {
          var parser = ConfigParser();
          parser.addOption('test', mandatory: true);
          var results = parser.parse(['--test', 'test']);
          expect(results.option('test'), equals('test'));
        });
      });
    });

    group('remaining args', () {
      test('stops parsing args when a non-option-like arg is encountered', () {
        var parser = ConfigParser();
        parser.addFlag('woof');
        parser.addOption('meow');
        parser.addOption('tweet', defaultsTo: 'bird');

        var results = parser.parse(['--woof', '--meow', 'v', 'not', 'option']);
        expect(results['woof'], isTrue);
        expect(results['meow'], equals('v'));
        expect(results['tweet'], equals('bird'));
        expect(results.rest, equals(['not', 'option']));
      });

      test('consumes "--" and stops', () {
        var parser = ConfigParser();
        parser.addFlag('woof', defaultsTo: false);
        parser.addOption('meow', defaultsTo: 'kitty');

        var results = parser.parse(['--woof', '--', '--meow']);
        expect(results['woof'], isTrue);
        expect(results['meow'], equals('kitty'));
        expect(results.rest, equals(['--meow']));
      });

      test(
          'with allowTrailingOptions: false, leaves "--" if not the first '
          'non-option', () {
        var parser = ConfigParser(allowTrailingOptions: false);
        parser.addFlag('woof');

        var results = parser.parse(['--woof', 'stop', '--', 'arg']);
        expect(results['woof'], isTrue);
        expect(results.rest, equals(['stop', '--', 'arg']));
      });
    });

    group('ConfigParser Exception Tests', () {
      test('throws exception for unknown option', () {
        var parser = ConfigParser();
        throwsArgParserException(parser, ['--verbose'],
            'Could not find an option named "--verbose".', [], '--verbose');
        throwsArgParserException(
            parser, ['-v'], 'Could not find an option or flag "-v".', [], '-v');
      });

      test('throws exception for flag with value', () {
        var parser = ConfigParser();
        parser.addFlag('flag', abbr: 'f');
        throwsArgParserException(parser, ['--flag=1'],
            'Flag option "--flag" should not be given a value.', [], '--flag');
        throwsArgParserException(parser, ['-f=1'],
            'Option "-f" is a flag and cannot handle value "=1".', [], '-f');
      });

      test('throws exception after parsing multiple options', () {
        var parser = ConfigParser();
        parser.addOption('first');
        parser.addOption('second');
        throwsArgParserException(
            parser,
            ['--first', '1', '--second', '2', '--verbose', '3'],
            'Could not find an option named "--verbose".',
            [],
            '--verbose');
      });

      test('throws exception for option with invalid value', () {
        var parser = ConfigParser();
        parser.addOption('first', allowed: ['a', 'b']);
        throwsUsageException(parser, ['--first', 'c']);
      });

      test('throws exception after parsing command', () {
        var parser = ConfigParser();
        parser.addCommand('command', ConfigParser());
        throwsArgParserException(
            parser,
            ['command', '--verbose'],
            'Could not find an option named "--verbose".',
            ['command'],
            '--verbose');
      }, skip: 'commands not supported');
    });
  });
}
