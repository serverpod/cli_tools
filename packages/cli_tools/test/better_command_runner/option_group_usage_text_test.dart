import 'package:cli_tools/better_command_runner.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

void main() {
  const mockCommandName = 'mock';
  const mockCommandDescription = 'This is a Mock CLI';
  const mockHelpText = 'Mock Help Text.';
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

  String buildSeparatorView(final String name) => '\n$name\n';

  String buildSuffix([final Object? suffix = '', final String prefix = '']) =>
      suffix != null && suffix != '' ? '$prefix${suffix.toString()}' : '';

  String buildMockArgName([final Object? suffix = '']) =>
      'mock-arg${buildSuffix(suffix, '-')}';

  String buildMockGroupName([final Object? suffix = '']) =>
      'Mock Group${buildSuffix(suffix, ' ')}';

  String buildFallbackGroupName([final Object? suffix = '']) =>
      '$fallbackGroupName${buildSuffix(suffix, ' ')}';

  OptionGroup buildMockGroup([final Object? suffix = '']) =>
      OptionGroup(buildMockGroupName(suffix));

  OptionDefinition buildMockOption(
    final String name,
    final OptionGroup? group,
  ) =>
      FlagOption(
        argName: name,
        group: group,
        helpText: mockHelpText,
      );

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
                buildMockOption(buildMockArgName(i), buildMockGroup(i)),
              for (var i = 5; i < 10; ++i)
                buildMockOption(buildMockArgName(i), null),
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
                buildMockOption(buildMockArgName(i), buildMockGroup(i)),
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
                buildMockOption(
                  buildMockArgName(i),
                  OptionGroup(blankNameExamples[i]),
                ),
              for (var i = nBlankNameExamples; i < nBlankNameExamples + 5; ++i)
                buildMockOption(buildMockArgName(i), null),
            ],
          ).usage,
          allOf([
            for (final blankName in blankNameExamples)
              if (blankName != '' && blankName != '\n')
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
                buildMockOption(
                  buildMockArgName(i),
                  OptionGroup(blankNameExamples[i]),
                ),
            ],
          ).usage,
          allOf([
            for (final blankName in blankNameExamples)
              if (blankName != '' && blankName != '\n')
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
                buildMockOption(buildMockArgName(i), buildMockGroup(i)),
              for (var i = 5; i < 10; ++i)
                buildMockOption(buildMockArgName(i), null),
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
                buildMockOption(buildMockArgName(i), buildMockGroup(i)),
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
              buildMockOption(
                buildMockArgName(1),
                OptionGroup(blankNameExamples.first),
              ),
              buildMockOption(
                buildMockArgName(2),
                OptionGroup(buildMockGroupName('XYZ')),
              ),
              buildMockOption(
                buildMockArgName(3),
                OptionGroup(blankNameExamples.last),
              ),
              for (var i = 100; i < 105; ++i)
                buildMockOption(buildMockArgName(i), null),
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
              buildMockOption(
                buildMockArgName(1),
                OptionGroup(blankNameExamples.first),
              ),
              buildMockOption(
                buildMockArgName(2),
                OptionGroup(buildMockGroupName('XYZ')),
              ),
              buildMockOption(
                buildMockArgName(3),
                OptionGroup(blankNameExamples.last),
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
            buildMockOption(
              buildMockArgName(1),
              OptionGroup(blankNameExamples.first),
            ),
            buildMockOption(
              buildMockArgName(2),
              OptionGroup(buildMockGroupName('XYZ')),
            ),
            buildMockOption(
              buildMockArgName(3),
              OptionGroup(blankNameExamples.last),
            ),
            for (var i = 100; i < 105; ++i)
              buildMockOption(buildMockArgName(i), null),
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
              buildMockOption(buildMockArgName(++optionCount1), null),
            for (var i = 0; i < 3; ++i)
              for (var j = 0; j < 5; ++j)
                buildMockOption(
                  buildMockArgName(++optionCount1),
                  OptionGroup(buildMockGroupName(i)),
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
              buildMockOption(buildMockArgName(++optionCount), null),
            for (var i = 0; i < 3; ++i)
              for (var j = 0; j < 5; ++j)
                buildMockOption(
                  buildMockArgName(++optionCount),
                  buildMockGroup(++groupCount1),
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
