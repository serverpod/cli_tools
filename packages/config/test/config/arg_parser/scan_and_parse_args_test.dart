import 'package:config/config.dart';
import 'package:config/src/config/arg_parser/arg_parser.dart';
import 'package:config/src/config/arg_parser/arg_scanner.dart';
import 'package:test/test.dart';

void main() {
  group('Given no options and no arguments', () {
    late ArgParseResult result;

    setUp(() {
      result = scanAndParseArgs(<String>[], options: []);
    });

    test('then the result has no command', () {
      expect(result.command, isNull);
    });

    test('then the result has no parent', () {
      expect(result.parent, isNull);
    });

    test('then the result has no child', () {
      expect(result.child, isNull);
    });

    test('then no flags are set', () {
      expect(result.flagOptions, isEmpty);
    });

    test('then no regular options are set', () {
      expect(result.regularOptions, isEmpty);
    });

    test('then no multi options are set', () {
      expect(result.multiOptions, isEmpty);
    });

    test('then there are no positional words', () {
      expect(result.positionalWords, isEmpty);
    });

    test('then there are no unparsed arguments', () {
      expect(result.unparsedArgs, isEmpty);
    });

    test('then there are no errors', () {
      expect(result.errors, isEmpty);
    });

    test('then toList returns that result alone', () {
      expect(result.toList(), [result]);
    });
  });

  group('Given no options', () {
    test('when words are parsed then they stay positional in order', () {
      final ArgParseResult result = scanAndParseArgs(
        ['alpha', '', 'gamma'],
        options: [],
      );

      expect(result.positionalWords, ['alpha', '', 'gamma']);
    });

    test('when a word matches an option shape without dashes '
        'then it stays positional', () {
      const name = StringOption(argName: 'name');
      final result = scanAndParseArgs(['name', 'ada'], options: [name]);

      expect(result.positionalWords, ['name', 'ada']);
    });

    test('when -- is parsed then the error is recorded', () {
      final result = scanAndParseArgs(['--'], options: <OptionDefinition>[]);

      expect(result.errors, ['Unexpected value: --']);
    });

    test('when - is parsed then the error is recorded', () {
      final result = scanAndParseArgs(['-'], options: <OptionDefinition>[]);

      expect(result.errors, ['Unexpected value: -']);
    });

    test(
      'when an unknown long option is parsed then the error is recorded',
      () {
        final result = scanAndParseArgs(
          ['--unknown'],
          options: <OptionDefinition>[],
        );

        expect(result.errors, ['Unknown option: --unknown']);
      },
    );

    test(
      'when an unknown short option is parsed then the error is recorded',
      () {
        final result = scanAndParseArgs(['-x'], options: <OptionDefinition>[]);

        expect(result.errors, ['Unknown option: -x']);
      },
    );

    test('when a long option name is empty '
        'then the name and the attached value are recorded', () {
      final result = scanAndParseArgs(['--='], options: <OptionDefinition>[]);

      expect(result.errors, ['Unknown option: --', 'Unexpected value: ']);
    });

    test('when a long option name starts with a dash '
        'then the error is recorded', () {
      final result = scanAndParseArgs(['---'], options: <OptionDefinition>[]);

      expect(result.errors, ['Unknown option: ---']);
    });

    test('when several arguments are invalid then every error is recorded', () {
      const name = StringOption(argName: 'name');
      const verbose = FlagOption(argName: 'verbose');
      final result = scanAndParseArgs(
        ['--missing', '-x', '--verbose', '--verbose', '--name'],
        options: <OptionDefinition>[name, verbose],
      );

      expect(result.errors, [
        'Unknown option: --missing',
        'Unknown option: -x',
        'Option --verbose cannot be specified more than once',
        'Missing value for option: --name',
      ]);
    });

    test('when several arguments are invalid '
        'then the valid flag is still recorded', () {
      const name = StringOption(argName: 'name');
      const verbose = FlagOption(argName: 'verbose');
      final result = scanAndParseArgs(
        ['--missing', '-x', '--verbose', '--verbose', '--name'],
        options: <OptionDefinition>[name, verbose],
      );

      expect(result.flagOptions[verbose], isTrue);
    });
  });

  group('Given options that declare positional indexes', () {
    const first = StringOption(argName: 'first', argPos: 0);
    const second = StringOption(argPos: 1);

    group('when two words are parsed', () {
      late ArgParseResult result;

      setUp(() {
        result = scanAndParseArgs(
          ['a', 'b'],
          options: [first, second],
        );
      });

      test('then both words stay positional', () {
        expect(result.positionalWords, ['a', 'b']);
      });

      test('then the indexed options are not assigned', () {
        expect(result.regularOptions, isEmpty);
      });
    });
  });

  group('Given option metadata this parser does not apply', () {
    test('when a mandatory option is omitted then it is absent', () {
      const name = StringOption(argName: 'name', mandatory: true);
      final result = scanAndParseArgs(<String>[], options: [name]);

      expect(result.regularOptions[name], isNull);
    });

    test(
      'when an option default is omitted then the default is not filled',
      () {
        const name = StringOption(argName: 'name', defaultsTo: 'fallback');
        final result = scanAndParseArgs(<String>[], options: [name]);

        expect(result.regularOptions[name], isNull);
      },
    );
  });

  group('Given a negatable flag with a name, abbreviation, and alias', () {
    const verbose = FlagOption(
      argName: 'verbose',
      argAbbrev: 'v',
      argAliases: ['verbose-mode'],
    );

    ArgParseResult<FlagOption> parse(final List<String> args) {
      return scanAndParseArgs(args, options: [verbose]);
    }

    test('when passed as --verbose then it is set', () {
      expect(parse(['--verbose']).flagOptions[verbose], isTrue);
    });

    test('when passed as --no-verbose then it is cleared', () {
      expect(parse(['--no-verbose']).flagOptions[verbose], isFalse);
    });

    test('when passed as -v then it is set', () {
      expect(parse(['-v']).flagOptions[verbose], isTrue);
    });

    test('when passed by alias then it is set', () {
      expect(parse(['--verbose-mode']).flagOptions[verbose], isTrue);
    });

    test('when omitted then it is absent', () {
      expect(parse(<String>[]).flagOptions[verbose], isNull);
    });

    test('when a long value is attached then the error is recorded', () {
      expect(
        parse(['--verbose=true']).errors,
        ['Unexpected value: true'],
      );
    });

    test('when a short value is attached then the error is recorded', () {
      expect(parse(['-v=true']).errors, ['Unexpected value: true']);
    });

    test('when an empty long value is attached then the error is recorded', () {
      expect(parse(['--verbose=']).errors, ['Unexpected value: ']);
    });

    test('when the alias is negated then the error is recorded', () {
      expect(
        parse(['--no-verbose-mode']).errors,
        ['Unknown option: --no-verbose-mode'],
      );
    });

    test('when the long name is repeated then the error is recorded', () {
      expect(
        parse(['--verbose', '--verbose']).errors,
        ['Option --verbose cannot be specified more than once'],
      );
    });

    test('when the long name is repeated then the first value is kept', () {
      expect(parse(['--verbose', '--verbose']).flagOptions[verbose], isTrue);
    });

    test('when the long name and abbreviation are both passed '
        'then the error is recorded', () {
      expect(
        parse(['--verbose', '-v']).errors,
        ['Option --verbose cannot be specified more than once'],
      );
    });

    test('when the flag and its negation are both passed '
        'then the error is recorded', () {
      expect(
        parse(['--verbose', '--no-verbose']).errors,
        ['Option --verbose cannot be specified more than once'],
      );
    });

    test('when the alias and the long name are both passed '
        'then the error is recorded', () {
      expect(
        parse(['--verbose-mode', '--verbose']).errors,
        ['Option --verbose cannot be specified more than once'],
      );
    });

    group('when a single dash is followed by the long name', () {
      late ArgParseResult<FlagOption> result;

      setUp(() {
        result = parse(['-verbose']);
      });

      test('then the abbreviation is set', () {
        expect(result.flagOptions[verbose], isTrue);
      });

      test('then each other letter is an unknown option', () {
        expect(result.errors, [
          'Unknown option: -e',
          'Unknown option: -r',
          'Unknown option: -b',
          'Unknown option: -o',
          'Unknown option: -s',
          'Unknown option: -e',
        ]);
      });
    });

    test('when the abbreviation is used as a long option '
        'then the error is recorded', () {
      expect(parse(['--v']).errors, ['Unknown option: --v']);
    });

    test('when the abbreviation is repeated in one cluster '
        'then the error is recorded', () {
      expect(
        parse(['-vv']).errors,
        ['Option --verbose cannot be specified more than once'],
      );
    });
  });

  group('Given a non-negatable flag', () {
    const color = FlagOption(argName: 'color', negatable: false);

    test('when passed as --color then it is set', () {
      final result = scanAndParseArgs(['--color'], options: [color]);

      expect(result.flagOptions[color], isTrue);
    });

    test('when passed as --no-color then the error is recorded', () {
      final result = scanAndParseArgs(['--no-color'], options: [color]);

      expect(result.errors, ['Unknown option: --no-color']);
    });
  });

  group('Given a non-negatable flag with an alias that starts with no-', () {
    const color = FlagOption(
      argName: 'color',
      negatable: false,
      argAliases: ['no-color'],
    );

    ArgParseResult<FlagOption> parse(final List<String> args) {
      return scanAndParseArgs(args, options: [color]);
    }

    test('when passed as --color then it is set', () {
      expect(parse(['--color']).flagOptions[color], isTrue);
    });

    test('when the alias is passed then the flag is set', () {
      expect(parse(['--no-color']).flagOptions[color], isTrue);
    });
  });

  group('Given a negatable flag with an alias that starts with no-', () {
    const color = FlagOption(
      argName: 'color',
      argAliases: ['no-problem'],
    );

    ArgParseResult<FlagOption> parse(final List<String> args) {
      return scanAndParseArgs(args, options: [color]);
    }

    test('when the alias is passed then the flag is set', () {
      expect(parse(['--no-problem']).flagOptions[color], isTrue);
    });

    test('when the generated negation is passed then the flag is cleared', () {
      expect(parse(['--no-color']).flagOptions[color], isFalse);
    });
  });

  group('Given several short flags', () {
    const alpha = FlagOption(argName: 'alpha', argAbbrev: 'a');
    const beta = FlagOption(argName: 'beta', argAbbrev: 'b');
    const gamma = FlagOption(argName: 'gamma', argAbbrev: 'c');

    group('when they are clustered as -abc', () {
      late ArgParseResult result;

      setUp(() {
        result = scanAndParseArgs(
          ['-abc'],
          options: [alpha, beta, gamma],
        );
      });

      test('then alpha is set', () {
        expect(result.flagOptions[alpha], isTrue);
      });

      test('then beta is set', () {
        expect(result.flagOptions[beta], isTrue);
      });

      test('then gamma is set', () {
        expect(result.flagOptions[gamma], isTrue);
      });
    });

    group('when the cluster contains an unknown letter', () {
      late ArgParseResult result;

      setUp(() {
        result = scanAndParseArgs(
          ['-abq'],
          options: [alpha, beta],
        );
      });

      test('then the known flags are set', () {
        expect(result.flagOptions[alpha], isTrue);
        expect(result.flagOptions[beta], isTrue);
      });

      test('then the unknown letter is recorded', () {
        expect(result.errors, ['Unknown option: -q']);
      });
    });
  });

  group('Given a string option with a name, abbreviation, and aliases', () {
    const name = StringOption(
      argName: 'name',
      argAbbrev: 'n',
      argAliases: ['title', 'label'],
    );

    ArgParseResult<StringOption> parse(final List<String> args) {
      return scanAndParseArgs(args, options: [name]);
    }

    test(
      'when the value is a separate argument then that argument is used',
      () {
        expect(parse(['--name', 'ada']).regularOptions[name], 'ada');
      },
    );

    test('when the value is attached with = then the text after = is used', () {
      expect(parse(['--name=ada']).regularOptions[name], 'ada');
    });

    test('when the attached value contains = then only the first = splits', () {
      expect(parse(['--name=a=b']).regularOptions[name], 'a=b');
    });

    test(
      'when the separate value starts with a dash then it is kept whole',
      () {
        expect(parse(['--name', '-123']).regularOptions[name], '-123');
      },
    );

    test('when the attached value starts with a dash then it is kept', () {
      expect(parse(['--name=-123']).regularOptions[name], '-123');
    });

    test(
      'when the short option has a separate value then that value is used',
      () {
        expect(parse(['-n', 'ada']).regularOptions[name], 'ada');
      },
    );

    test('when the short option attaches a value with = '
        'then the value is the text after =', () {
      expect(parse(['-n=ada']).regularOptions[name], 'ada');
    });

    test('when the short option value is a dash cluster '
        'then the whole argument is the value', () {
      expect(parse(['-n', '-abc']).regularOptions[name], '-abc');
    });

    test('when the separate value is itself an option assignment '
        'then the whole argument is the value', () {
      expect(
        parse(['--name', '--file=value']).regularOptions[name],
        '--file=value',
      );
    });

    test('when the attached value is empty then the value is empty', () {
      expect(parse(['--name=']).regularOptions[name], '');
    });

    test('when the separate value is empty then the value is empty', () {
      expect(parse(['--name', '']).regularOptions[name], '');
    });

    test('when the value contains spaces then it is kept whole', () {
      expect(
        parse(['--name', 'ada lovelace']).regularOptions[name],
        'ada lovelace',
      );
    });

    test('when the value follows -- then -- is the value', () {
      expect(parse(['--name', '--']).regularOptions[name], '--');
    });

    test('when the value follows - then - is the value', () {
      expect(parse(['--name', '-']).regularOptions[name], '-');
    });

    test('when passed by the title alias then the value is recorded', () {
      expect(parse(['--title', 'ada']).regularOptions[name], 'ada');
    });

    test('when passed by the label alias then the value is recorded', () {
      expect(parse(['--label', 'ada']).regularOptions[name], 'ada');
    });

    test(
      'when a non-ascii abbreviation is used then the value is recorded',
      () {
        const labelled = StringOption(argName: 'name', argAbbrev: 'ä');

        final result = scanAndParseArgs(['-ä', 'ada'], options: [labelled]);

        expect(result.regularOptions[labelled], 'ada');
      },
    );

    test('when omitted then it is absent', () {
      expect(parse(<String>[]).regularOptions[name], isNull);
    });

    group('when --name=ada is followed by another word', () {
      late ArgParseResult<StringOption> result;

      setUp(() {
        result = parse(['--name=ada', 'extra']);
      });

      test('then the attached text is the option value', () {
        expect(result.regularOptions[name], 'ada');
      });

      test('then the following word stays positional', () {
        expect(result.positionalWords, ['extra']);
      });
    });

    test('when the value is missing then the error is recorded', () {
      expect(parse(['--name']).errors, ['Missing value for option: --name']);
    });

    test('when a short option that takes a value is clustered '
        'then the error says the value is missing', () {
      expect(parse(['-nfile']).errors, ['Missing value for option: -n']);
    });

    test('when it is specified twice then the error is recorded', () {
      expect(
        parse(['--name', 'ada', '--name', 'grace']).errors,
        ['Option --name cannot be specified more than once'],
      );
    });

    test('when it is specified twice then the first value is kept', () {
      expect(
        parse(['--name', 'ada', '--name', 'grace']).regularOptions[name],
        'ada',
      );
    });

    test('when the name and an alias are both passed '
        'then the error is recorded', () {
      expect(
        parse(['--name', 'ada', '--title', 'grace']).errors,
        ['Option --name cannot be specified more than once'],
      );
    });

    test('when an alias is missing its value '
        'then the error uses the alias that was written', () {
      expect(
        parse(['--title']).errors,
        ['Missing value for option: --title'],
      );
    });

    test('when the abbreviation is missing its value '
        'then the error uses the abbreviation that was written', () {
      expect(parse(['-n']).errors, ['Missing value for option: -n']);
    });
  });

  group('Given a string option and another option after a -- value', () {
    const name = StringOption(argName: 'name');
    const file = StringOption(argName: 'file');

    group('when --name takes -- and --file follows', () {
      late ArgParseResult result;

      setUp(() {
        result = scanAndParseArgs(
          ['--name', '--', '--file', 'a.txt'],
          options: [name, file],
        );
      });

      test('then -- is the name value', () {
        expect(result.regularOptions[name], '--');
      });

      test('then the later option is still parsed', () {
        expect(result.regularOptions[file], 'a.txt');
      });
    });
  });

  group('Given a multi option with a name, abbreviation, and alias', () {
    const files = MultiStringOption(
      argName: 'file',
      argAbbrev: 'f',
      argAliases: ['input'],
    );

    ArgParseResult<MultiStringOption> parse(final List<String> args) {
      return scanAndParseArgs(args, options: [files]);
    }

    test('when one value contains a comma then it stays one value', () {
      expect(parse(['--file', 'a,b']).multiOptions[files], ['a,b']);
    });

    test('when the value starts with a dash then it is kept whole', () {
      expect(parse(['--file', '-123']).multiOptions[files], ['-123']);
    });

    test('when omitted then it is absent', () {
      expect(parse(<String>[]).multiOptions[files], isNull);
    });

    test('when the value is missing then the error is recorded', () {
      expect(
        parse(['--file']).errors,
        ['Missing value for option: --file'],
      );
    });

    group('when values use the name, an alias, and the abbreviation', () {
      late ArgParseResult<MultiStringOption> result;

      setUp(() {
        result = parse(['--file=a', '--input', 'b', '-f', 'c', '-f=d']);
      });

      test('then the values accumulate in order', () {
        expect(result.multiOptions[files], ['a', 'b', 'c', 'd']);
      });

      test('then they are not stored as a single-value option', () {
        expect(result.regularOptions[files], isNull);
      });
    });
  });

  group('Given a flag, a string option, and a multi option', () {
    const verbose = FlagOption(argName: 'verbose', argAbbrev: 'v');
    const name = StringOption(argName: 'name', argAbbrev: 'n');
    const files = MultiStringOption(argName: 'file', argAbbrev: 'f');

    group('when options and positional words are interleaved', () {
      late ArgParseResult result;

      setUp(() {
        result = scanAndParseArgs(
          [
            'src',
            '-v',
            '--name',
            'ada',
            'mid',
            '--file',
            'a',
            '-f',
            'b',
            'out',
          ],
          options: [verbose, name, files],
        );
      });

      test('then positional words exclude option values', () {
        expect(result.positionalWords, ['src', 'mid', 'out']);
      });

      test('then the flag is set', () {
        expect(result.flagOptions[verbose], isTrue);
      });

      test('then the string option is recorded', () {
        expect(result.regularOptions[name], 'ada');
      });

      test('then the multi option accumulates each value', () {
        expect(result.multiOptions[files], ['a', 'b']);
      });

      test('then the result has no command', () {
        expect(result.command, isNull);
      });

      test('then there are no unparsed arguments', () {
        expect(result.unparsedArgs, isEmpty);
      });

      test('then the flag is not stored as a value', () {
        expect(result.regularOptions[verbose], isNull);
      });

      test('then the string option is not stored as a multi option', () {
        expect(result.multiOptions.keys, isNot(contains(name)));
      });

      test('then the multi option is not stored as a single value', () {
        expect(result.regularOptions[files], isNull);
      });
    });
  });

  group('Given two options with the same name', () {
    const first = StringOption(argName: 'name', argAbbrev: 'a');
    const second = StringOption(argName: 'name', argAbbrev: 'b');

    test('when the options are parsed then parsing fails', () {
      expect(
        () => scanAndParseArgs(
          ['--name', 'ada'],
          options: [first, second],
        ),
        throwsA(
          isA<OptionDefinitionError>().having(
            (final e) => e.toString(),
            'toString',
            contains('Duplicate argument name: name'),
          ),
        ),
      );
    });
  });

  group('Given two options with the same abbreviation', () {
    const first = StringOption(argName: 'first', argAbbrev: 'x');
    const second = StringOption(argName: 'second', argAbbrev: 'x');

    test('when the options are parsed then parsing fails', () {
      expect(
        () => scanAndParseArgs(
          ['-x', 'ada'],
          options: [first, second],
        ),
        throwsA(
          isA<OptionDefinitionError>().having(
            (final e) => e.toString(),
            'toString',
            contains('Duplicate argument abbreviation: x'),
          ),
        ),
      );
    });
  });

  group('Given a negatable flag and a string option named no-verbose', () {
    const verbose = FlagOption(argName: 'verbose');
    const negatedName = StringOption(argName: 'no-verbose');

    test('when the options are parsed then parsing fails', () {
      expect(
        () => scanAndParseArgs(
          ['--verbose'],
          options: <OptionDefinition>[verbose, negatedName],
        ),
        throwsA(
          isA<OptionDefinitionError>().having(
            (final e) => e.toString(),
            'toString',
            contains('Duplicate argument name: no-verbose'),
          ),
        ),
      );
    });
  });

  group('Given a flag that only has an abbreviation', () {
    const verbose = FlagOption(argAbbrev: 'v');

    test('when passed as -v then it is set', () {
      final result = scanAndParseArgs(['-v'], options: [verbose]);

      expect(result.flagOptions[verbose], isTrue);
    });

    test('when passed twice then the error labels the abbreviation', () {
      final result = scanAndParseArgs(['-v', '-v'], options: [verbose]);

      expect(result.errors, ['Option -v cannot be specified more than once']);
    });
  });

  group('Given pass-through of the rest after --', () {
    const verbose = FlagOption(argName: 'verbose', argAbbrev: 'v');
    const name = StringOption(argName: 'name', argAbbrev: 'n');
    const file = StringOption(argName: 'file', argAbbrev: 'f');

    const passThroughRest = ScanMode(
      doubleDashHandling: DoubleDashHandling.passThroughRest,
    );

    ArgParseResult parse(final List<String> args) {
      return scanAndParseArgs(
        args,
        options: [verbose, name, file],
        scanMode: passThroughRest,
      );
    }

    group('when options and words precede --', () {
      late ArgParseResult result;

      setUp(() {
        result = parse([
          'src',
          '--name',
          'ada',
          '--',
          '-v',
          '--file=a.txt',
          '-abc',
          '--',
          '',
          'rest',
        ]);
      });

      test('then the option before -- is recorded', () {
        expect(result.regularOptions[name], 'ada');
      });

      test('then words before -- stay positional', () {
        expect(result.positionalWords, ['src']);
      });

      test('then arguments after -- are unparsed in order', () {
        expect(
          result.unparsedArgs,
          ['-v', '--file=a.txt', '-abc', '--', '', 'rest'],
        );
      });

      test('then the result is the last node', () {
        expect(result.child, isNull);
      });

      test('then a flag after -- is not set', () {
        expect(result.flagOptions[verbose], isNull);
      });

      test('then an option after -- is not recorded', () {
        expect(result.regularOptions[file], isNull);
      });
    });

    group('when -- is the first argument', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['--', '-v', 'file']);
      });

      test('then every following argument is unparsed', () {
        expect(result.unparsedArgs, ['-v', 'file']);
      });

      test('then no flag is set', () {
        expect(result.flagOptions[verbose], isNull);
      });

      test('then there are no positional words', () {
        expect(result.positionalWords, isEmpty);
      });
    });

    group('when -- is the last argument', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['src', '--']);
      });

      test('then there are no unparsed arguments', () {
        expect(result.unparsedArgs, isEmpty);
      });

      test('then the preceding word stays positional', () {
        expect(result.positionalWords, ['src']);
      });
    });

    group('when an option value is -- and more arguments follow', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['--name', '--', '--file', 'a.txt', 'rest']);
      });

      test('then -- is the option value', () {
        expect(result.regularOptions[name], '--');
      });

      test('then the later option is recorded', () {
        expect(result.regularOptions[file], 'a.txt');
      });

      test('then the later word stays positional', () {
        expect(result.positionalWords, ['rest']);
      });

      test('then there are no unparsed arguments', () {
        expect(result.unparsedArgs, isEmpty);
      });
    });

    group('when an option value is -- and a later -- follows', () {
      late ArgParseResult result;

      setUp(() {
        result = parse([
          '--name',
          '--',
          '--file',
          'a.txt',
          'src',
          '--',
          '-v',
          '--name',
          'other',
          'tail',
        ]);
      });

      test('then the first -- is the option value', () {
        expect(result.regularOptions[name], '--');
      });

      test('then the option before the later -- is recorded', () {
        expect(result.regularOptions[file], 'a.txt');
      });

      test('then words before the later -- stay positional', () {
        expect(result.positionalWords, ['src']);
      });

      test('then arguments after the later -- are unparsed', () {
        expect(result.unparsedArgs, ['-v', '--name', 'other', 'tail']);
      });

      test('then a flag after the later -- is not set', () {
        expect(result.flagOptions[verbose], isNull);
      });
    });

    group('when two options take -- and a third -- follows', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['--name', '--', '--file', '--', 'src', '--', 'tail']);
      });

      test('then the first -- is the name value', () {
        expect(result.regularOptions[name], '--');
      });

      test('then the second -- is the file value', () {
        expect(result.regularOptions[file], '--');
      });

      test('then the word before the third -- stays positional', () {
        expect(result.positionalWords, ['src']);
      });

      test('then arguments after the third -- are unparsed', () {
        expect(result.unparsedArgs, ['tail']);
      });
    });

    group('when -- is absent', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['-v', 'src']);
      });

      test('then the flag is set', () {
        expect(result.flagOptions[verbose], isTrue);
      });

      test('then there are no unparsed arguments', () {
        expect(result.unparsedArgs, isEmpty);
      });
    });

    test('when the same arguments use the default scan mode '
        'then the unexpected -- is recorded', () {
      final result = scanAndParseArgs(
        ['src', '--', 'rest'],
        options: <OptionDefinition>[verbose, name, file],
      );

      expect(result.errors, ['Unexpected value: --']);
    });

    test('when the same arguments use the default scan mode '
        'then later words stay positional', () {
      final result = scanAndParseArgs(
        ['src', '--', 'rest'],
        options: <OptionDefinition>[verbose, name, file],
      );

      expect(result.positionalWords, ['src', 'rest']);
    });
  });
}
