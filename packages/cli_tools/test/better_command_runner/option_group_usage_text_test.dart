import 'package:cli_tools/better_command_runner.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

void main() {
  const mockCommandName = 'mock';
  const mockCommandDescription = 'A mock CLI for Option Group Usage Text test.';
  const mockOptionHelpText = 'Help Text for this Mock Option.';
  const defaultFallbackGroupName = 'Option Group';
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

  String buildSeparatorView(final String name) => '\n\n$name\n';

  String buildSuffix([final Object? suffix = '', final String prefix = '']) =>
      suffix != null && suffix != '' ? '$prefix${suffix.toString()}' : '';

  String buildMockArgName([final Object? suffix = '']) =>
      'mock-arg${buildSuffix(suffix, '-')}';

  String buildMockGroupName([final Object? suffix = '']) =>
      'Mock Group${buildSuffix(suffix, ' ')}';

  String buildFallbackGroupName([final Object? suffix = '']) =>
      '$defaultFallbackGroupName${buildSuffix(suffix, ' ')}';

  OptionGroup buildMockGroup([final Object? suffix = '']) =>
      OptionGroup(buildMockGroupName(suffix));

  OptionDefinition buildMockOption(
    final String name, [
    final OptionGroup? group,
  ]) =>
      FlagOption(
        argName: name,
        group: group,
        helpText: mockOptionHelpText,
      );

  BetterCommandRunner buildRunner(final List<OptionDefinition> options) =>
      BetterCommandRunner(
        mockCommandName,
        mockCommandDescription,
        globalOptions: options,
      );

  group('Non-Blank Group Names are rendered as-is', () {
    final grouplessOptions = <OptionDefinition>[
      for (var i = 0; i < 5; ++i) buildMockOption(buildMockArgName(i)),
    ];
    final groupedOptions = <OptionDefinition>[
      for (var i = 5; i < 10; ++i)
        buildMockOption(buildMockArgName(i), buildMockGroup(i)),
    ];
    final expectation = allOf([
      for (var i = 5; i < 10; ++i) contains(buildMockGroupName(i)),
    ]);
    test(
      'in the presence of Groupless Options',
      () {
        expect(
          buildRunner(grouplessOptions + groupedOptions).usage,
          expectation,
        );
      },
    );
    test(
      'in the absence of Groupless Options',
      () {
        expect(
          buildRunner(groupedOptions).usage,
          expectation,
        );
      },
    );
  });

  group('Group Names are properly padded with newlines', () {
    final grouplessOptions = <OptionDefinition>[
      for (var i = 0; i < 5; ++i) buildMockOption(buildMockArgName(i)),
    ];
    final groupedOptions = <OptionDefinition>[
      for (var i = 5; i < 10; ++i)
        buildMockOption(buildMockArgName(i), buildMockGroup(i)),
    ];
    final expectation = allOf([
      for (var i = 5; i < 10; ++i)
        contains(buildSeparatorView(buildMockGroupName(i))),
    ]);
    test(
      'in the presence of Groupless Options',
      () {
        expect(
          buildRunner(grouplessOptions + groupedOptions).usage,
          expectation,
        );
      },
    );
    test(
      'in the absence of Groupless Options',
      () {
        expect(
          buildRunner(groupedOptions).usage,
          expectation,
        );
      },
    );
  });

  group('Blank Group Names are not rendered as-is', () {
    final nBlankNameExamples = blankNameExamples.length;
    final groupedOptions = <OptionDefinition>[
      for (var i = 0; i < nBlankNameExamples; ++i)
        buildMockOption(
          buildMockArgName(i),
          OptionGroup(blankNameExamples[i]),
        ),
    ];
    final grouplessOptions = <OptionDefinition>[
      for (var i = nBlankNameExamples; i < nBlankNameExamples + 5; ++i)
        buildMockOption(buildMockArgName(i)),
    ];
    final expectation = allOf([
      for (final blankName in blankNameExamples)
        isNot(contains(buildSeparatorView(blankName))),
    ]);
    test(
      'in the presence of Groupless Options',
      () {
        expect(
          buildRunner(grouplessOptions + groupedOptions).usage,
          expectation,
        );
      },
    );
    test(
      'in the absence of Groupless Options',
      () {
        expect(
          buildRunner(groupedOptions).usage,
          expectation,
        );
      },
    );
  });

  group('Blank Group Names get a count-based default Group Name', () {
    final grouplessOptions = <OptionDefinition>[
      for (var i = 0; i < 5; ++i) buildMockOption(buildMockArgName(i)),
    ];
    final groupedOptions = <OptionDefinition>[
      buildMockOption(
        buildMockArgName('a'),
        OptionGroup(blankNameExamples.first),
      ),
      buildMockOption(
        buildMockArgName('b'),
        OptionGroup(buildMockGroupName('XYZ')),
      ),
      buildMockOption(
        buildMockArgName('c'),
        OptionGroup(blankNameExamples.last),
      ),
    ];
    final expectation = stringContainsInOrder([
      buildSeparatorView(buildFallbackGroupName(1)),
      buildSeparatorView(buildMockGroupName('XYZ')),
      buildSeparatorView(buildFallbackGroupName(3)),
    ]);
    test(
      'in the presence of Groupless Options',
      () {
        expect(
          buildRunner(grouplessOptions + groupedOptions).usage,
          expectation,
        );
      },
    );
    test(
      'in the absence of Groupless Options',
      () {
        expect(
          buildRunner(groupedOptions).usage,
          expectation,
        );
      },
    );
  });

  group('No automatic count-based Group Name when only one Group exists', () {
    final anyBlankGroupName = blankNameExamples.first;
    final grouplessOptions = <OptionDefinition>[
      for (var i = 0; i < 5; ++i) buildMockOption(buildMockArgName(i)),
    ];
    final groupedOptions = <OptionDefinition>[
      for (var i = 5; i < 10; ++i)
        buildMockOption(
          buildMockArgName(i),
          OptionGroup(anyBlankGroupName),
        ),
    ];
    final expectation = allOf([
      for (final potentialSuffix in [1, 0, -1])
        isNot(
          contains(buildSeparatorView(buildFallbackGroupName(potentialSuffix))),
        ),
    ]);
    test(
      'in the presence of Groupless Options',
      () {
        expect(
          buildRunner(grouplessOptions + groupedOptions).usage,
          expectation,
        );
      },
    );
    test(
      'in the absence of Groupless Options',
      () {
        expect(
          buildRunner(groupedOptions).usage,
          expectation,
        );
      },
    );
  });

  test(
    'All Groupless Options are shown before Grouped Options',
    () {
      final groupedOptions = <OptionDefinition>[
        for (var i = 0; i < 5; ++i)
          buildMockOption(buildMockArgName(i), buildMockGroup(i)),
      ];
      final grouplessOptions = <OptionDefinition>[
        for (var i = 5; i < 10; ++i) buildMockOption(buildMockArgName(i)),
      ];
      final expectation = stringContainsInOrder([
        '\n',
        for (var i = 5; i < 10; ++i) ...[
          buildMockArgName(i),
          '\n',
        ],
        '\n',
        for (var i = 0; i < 5; ++i) ...[
          buildMockArgName(i),
          '\n',
        ],
        '\n',
      ]);
      expect(
        buildRunner(groupedOptions + grouplessOptions).usage,
        expectation,
      );
    },
  );

  test(
    'Relative order of all Options within a Group is preserved',
    () {
      var testOptionCount = 0;
      final grouplessOptions = <OptionDefinition>[
        for (var i = 0; i < 5; ++i)
          buildMockOption(buildMockArgName(++testOptionCount)),
      ];
      final groupedOptions = <OptionDefinition>[
        for (var i = 0; i < 3; ++i)
          for (var j = 0; j < 5; ++j)
            buildMockOption(
              buildMockArgName(++testOptionCount),
              buildMockGroup(i),
            ),
      ];
      var expectationOptionCount = 0;
      final expectation = stringContainsInOrder([
        '\n',
        for (var i = 0; i < 5; ++i) ...[
          buildMockArgName(++expectationOptionCount),
          '\n',
        ],
        '\n',
        for (var i = 0; i < 3; ++i)
          for (var j = 0; j < 5; ++j) ...[
            buildMockArgName(++expectationOptionCount),
            '\n',
          ],
        '\n',
      ]);
      expect(
        buildRunner(grouplessOptions + groupedOptions).usage,
        expectation,
      );
    },
  );

  test(
    'Relative order of all Groups is preserved',
    () {
      var optionCount = 0;
      var testGroupCount = 0;
      final grouplessOptions = <OptionDefinition>[
        for (var i = 0; i < 5; ++i)
          buildMockOption(buildMockArgName(++optionCount)),
      ];
      final groupedOptions = <OptionDefinition>[
        for (var i = 0; i < 3; ++i)
          for (var j = 0; j < 5; ++j)
            buildMockOption(
              buildMockArgName(++optionCount),
              buildMockGroup(++testGroupCount),
            ),
      ];
      var expectationGroupCount = 0;
      final expectation = stringContainsInOrder([
        for (var i = 0; i < testGroupCount; ++i)
          buildSeparatorView(buildMockGroupName(++expectationGroupCount)),
      ]);
      expect(
        buildRunner(grouplessOptions + groupedOptions).usage,
        expectation,
      );
    },
  );
}
