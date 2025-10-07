import 'package:cli_tools/better_command_runner.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

void main() {
  const mockCommandName = 'mock';
  const mockCommandDescription = 'This is a Mock CLI';
  const fallbackGroupName = 'Option Group';
  const blankNameExamples = <String>[
    '',
    ' ',
    '  ',
    '   ',
    '\n',
    '\n\n',
    '\n\n\n',
    '\t',
    '\t\t',
    '\t\t\t',
  ];
  final nBlankNameExamples = blankNameExamples.length;

  String buildSeparatorView(final String name) => '\n$name\n\n';

  String buildSuffix([final Object? suffix = '', final String prefix = '']) =>
      suffix != null && suffix != '' ? '$prefix${suffix.toString()}' : '';

  String buildMockArgName([final Object? suffix = '']) =>
      'mock-arg${buildSuffix(suffix, '-')}';

  String buildMockGroupName([final Object? suffix = '']) =>
      'Mock Group${buildSuffix(suffix, ' ')}';

  String buildFallbackGroupName([final Object? suffix = '']) =>
      '$fallbackGroupName${buildSuffix(suffix, ' ')}';

  group('All Group Names are properly padded with newlines', () {
    test(
      'in the presence of Groupless Options',
      () {
        expect(
          BetterCommandRunner(
            mockCommandName,
            mockCommandDescription,
            globalOptions: <OptionDefinition>[
              for (var i = 0; i < 5; ++i)
                FlagOption(
                  argName: buildMockArgName(i),
                  group: OptionGroup(buildMockGroupName(i)),
                ),
              for (var i = 5; i < 10; ++i)
                FlagOption(
                  argName: buildMockArgName(i),
                ),
            ],
          ).usage,
          allOf([
            for (var i = 0; i < 5; ++i)
              contains(buildSeparatorView(buildMockGroupName(i))),
          ]),
        );
      },
    );
    test(
      'in the absence of Groupless Options',
      () {
        expect(
          BetterCommandRunner(
            mockCommandName,
            mockCommandDescription,
            globalOptions: <OptionDefinition>[
              for (var i = 0; i < 5; ++i)
                FlagOption(
                  argName: buildMockArgName(i),
                  group: OptionGroup(buildMockGroupName(i)),
                ),
            ],
          ).usage,
          allOf([
            for (var i = 0; i < 5; ++i)
              contains(buildSeparatorView(buildMockGroupName(i))),
          ]),
        );
      },
    );
  });

  group('Blank Group Names are not rendered as-is', () {
    test(
      'in the presence of Groupless Options',
      () {
        expect(
          BetterCommandRunner(
            mockCommandName,
            mockCommandDescription,
            globalOptions: <OptionDefinition>[
              for (var i = 0; i < nBlankNameExamples; ++i)
                FlagOption(
                  argName: buildMockArgName(i),
                  group: OptionGroup(blankNameExamples[i]),
                ),
              for (var i = nBlankNameExamples; i < nBlankNameExamples + 5; ++i)
                FlagOption(
                  argName: buildMockArgName(i),
                ),
            ],
          ).usage,
          allOf([
            for (final blankName in blankNameExamples)
              isNot(contains(buildSeparatorView(blankName))),
          ]),
        );
      },
    );
    test(
      'in the absence of Groupless Options',
      () {
        expect(
          BetterCommandRunner(
            mockCommandName,
            mockCommandDescription,
            globalOptions: <OptionDefinition>[
              for (var i = 0; i < nBlankNameExamples; ++i)
                FlagOption(
                  argName: buildMockArgName(i),
                  group: OptionGroup(blankNameExamples[i]),
                ),
            ],
          ).usage,
          allOf([
            for (final blankName in blankNameExamples)
              isNot(contains(buildSeparatorView(blankName))),
          ]),
        );
      },
    );
  });

  group('Non-Blank Group Names are rendered as-is', () {
    test(
      'in the presence of Groupless Options',
      () {
        expect(
          BetterCommandRunner(
            mockCommandName,
            mockCommandDescription,
            globalOptions: <OptionDefinition>[
              for (var i = 0; i < 5; ++i)
                FlagOption(
                  argName: buildMockArgName(i),
                  group: OptionGroup(buildMockGroupName(i)),
                ),
              for (var i = 5; i < 10; ++i)
                FlagOption(
                  argName: buildMockArgName(i),
                ),
            ],
          ).usage,
          allOf([
            for (var i = 0; i < 5; ++i)
              contains(buildSeparatorView(buildMockGroupName(i))),
          ]),
        );
      },
    );
    test(
      'in the absence of Groupless Options',
      () {
        expect(
          BetterCommandRunner(
            mockCommandName,
            mockCommandDescription,
            globalOptions: <OptionDefinition>[
              for (var i = 0; i < 5; ++i)
                FlagOption(
                  argName: buildMockArgName(i),
                  group: OptionGroup(buildMockGroupName(i)),
                ),
            ],
          ).usage,
          allOf([
            for (var i = 0; i < 5; ++i)
              contains(buildSeparatorView(buildMockGroupName(i))),
          ]),
        );
      },
    );
  });

  group('Blank Group Names get a count-based default Group Name', () {
    test(
      'in the presence of Groupless Options',
      () {
        expect(
          BetterCommandRunner(
            mockCommandName,
            mockCommandDescription,
            globalOptions: <OptionDefinition>[
              FlagOption(
                argName: buildMockArgName(1),
                group: OptionGroup(blankNameExamples.first),
              ),
              FlagOption(
                argName: buildMockArgName(2),
                group: OptionGroup(buildMockGroupName('XYZ')),
              ),
              FlagOption(
                argName: buildMockArgName(3),
                group: OptionGroup(blankNameExamples.last),
              ),
              for (var i = 100; i < 105; ++i)
                FlagOption(
                  argName: buildMockArgName(i),
                ),
            ],
          ).usage,
          stringContainsInOrder([
            buildSeparatorView(buildFallbackGroupName(1)),
            buildSeparatorView(buildMockGroupName('XYZ')),
            buildSeparatorView(buildFallbackGroupName(3)),
          ]),
        );
      },
    );
    test(
      'in the absence of Groupless Options',
      () {
        expect(
          BetterCommandRunner(
            mockCommandName,
            mockCommandDescription,
            globalOptions: <OptionDefinition>[
              FlagOption(
                argName: buildMockArgName(1),
                group: OptionGroup(blankNameExamples.first),
              ),
              FlagOption(
                argName: buildMockArgName(2),
                group: OptionGroup(buildMockGroupName('XYZ')),
              ),
              FlagOption(
                argName: buildMockArgName(3),
                group: OptionGroup(blankNameExamples.last),
              ),
            ],
          ).usage,
          stringContainsInOrder([
            buildSeparatorView(buildFallbackGroupName(1)),
            buildSeparatorView(buildMockGroupName('XYZ')),
            buildSeparatorView(buildFallbackGroupName(3)),
          ]),
        );
      },
    );
  });

  test(
    'All Groupless Options are shown before Grouped Options',
    () {
      expect(
        BetterCommandRunner(
          mockCommandName,
          mockCommandDescription,
          globalOptions: <OptionDefinition>[
            FlagOption(
              argName: buildMockArgName(1),
              group: OptionGroup(blankNameExamples.first),
            ),
            FlagOption(
              argName: buildMockArgName(2),
              group: OptionGroup(buildMockGroupName('XYZ')),
            ),
            FlagOption(
              argName: buildMockArgName(3),
              group: OptionGroup(blankNameExamples.last),
            ),
            for (var i = 100; i < 105; ++i)
              FlagOption(
                argName: buildMockArgName(i),
              ),
          ],
        ).usage,
        stringContainsInOrder([
          '\n',
          for (var i = 100; i < 105; ++i) buildMockArgName(i),
          '\n',
          buildSeparatorView(buildFallbackGroupName(1)),
          buildSeparatorView(buildMockGroupName('XYZ')),
          buildSeparatorView(buildFallbackGroupName(3)),
        ]),
      );
    },
  );

  test(
    'Relative order of all Options within a Group is preserved',
    () {
      var optionCount1 = 0;
      var optionCount2 = 0;
      expect(
        BetterCommandRunner(
          mockCommandName,
          mockCommandDescription,
          globalOptions: <OptionDefinition>[
            for (var i = 0; i < 5; ++i)
              FlagOption(
                argName: buildMockArgName(++optionCount1),
              ),
            for (var i = 0; i < 3; ++i)
              for (var j = 0; j < 5; ++j)
                FlagOption(
                  argName: buildMockArgName(++optionCount1),
                  group: OptionGroup(buildMockGroupName(i)),
                ),
          ],
        ).usage,
        stringContainsInOrder([
          '\n',
          for (var i = 0; i < 5; ++i) buildMockArgName(++optionCount2),
          '\n',
          for (var i = 0; i < 3; ++i)
            for (var j = 0; j < 5; ++j) buildMockArgName(++optionCount2),
        ]),
      );
    },
  );

  test(
    'Relative order of all Groups is preserved',
    () {
      var optionCount = 0;
      var groupCount1 = 0;
      var groupCount2 = 0;
      expect(
        BetterCommandRunner(
          mockCommandName,
          mockCommandDescription,
          globalOptions: <OptionDefinition>[
            for (var i = 0; i < 5; ++i)
              FlagOption(
                argName: buildMockArgName(++optionCount),
              ),
            for (var i = 0; i < 3; ++i)
              for (var j = 0; j < 5; ++j)
                FlagOption(
                  argName: buildMockArgName(++optionCount),
                  group: OptionGroup(buildMockGroupName(++groupCount1)),
                ),
          ],
        ).usage,
        stringContainsInOrder([
          for (var i = 0; i < groupCount1; ++i)
            buildSeparatorView(buildMockGroupName(++groupCount2)),
        ]),
      );
    },
  );
}
