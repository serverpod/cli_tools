import 'package:cli_tools/better_command_runner.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

void main() {
  const mockCommandName = 'mock';
  const mockCommandDescription = 'A mock CLI for Option Group Usage Text test.';

  String buildSeparatorView(final String name) => '\n\n$name\n';

  String buildSuffix([final Object? suffix = '', final String prefix = '']) =>
      suffix != null && suffix != '' ? '$prefix${suffix.toString()}' : '';

  String buildMockArgName([final Object? suffix = '']) =>
      'mock-arg${buildSuffix(suffix, '-')}';

  String buildMockGroupName([final Object? suffix = '']) =>
      'Mock Group${buildSuffix(suffix, ' ')}';

  OptionDefinition buildMockOption(
    final String argName,
    final String? groupName, {
    final bool hide = false,
  }) =>
      FlagOption(
        argName: argName,
        hide: hide,
        group: groupName != null ? OptionGroup(groupName) : null,
        helpText: 'Help section for $argName.',
      );

  BetterCommandRunner buildRunner(final List<OptionDefinition> options) =>
      BetterCommandRunner(
        mockCommandName,
        mockCommandDescription,
        globalOptions: options,
      );

  int howManyMatches(final String pattern, final String target) =>
      RegExp(pattern).allMatches(target).length;

  group('Group Names (of visible Groups) are rendered as-is', () {
    final grouplessOptions = <OptionDefinition>[
      for (var i = 0; i < 5; ++i) buildMockOption(buildMockArgName(i), null),
    ];
    final groupedOptions = <OptionDefinition>[
      for (var i = 5; i < 10; ++i)
        buildMockOption(buildMockArgName(i), buildMockGroupName(i)),
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

  group('Group Names (of invisible Groups) are hidden', () {
    var testOptionCount = 0;
    var testGroupCount = 0;
    final grouplessOptions = <OptionDefinition>[
      for (var i = 0; i < 5; ++i)
        buildMockOption(buildMockArgName(++testOptionCount), null),
    ];
    final groupedOptions = <OptionDefinition>[
      for (var i = 0; i < 5; ++i)
        buildMockOption(
          buildMockArgName(++testOptionCount),
          buildMockGroupName(++testGroupCount),
        ),
    ];
    final hiddenGroups = <OptionDefinition>[
      for (var i = 0; i < 5; ++i)
        buildMockOption(
          buildMockArgName(++testOptionCount),
          buildMockGroupName(++testGroupCount),
          hide: true,
        ),
    ];
    var expectationGroupCount = 0;
    final expectation = allOf([
      for (var i = 0; i < 5; ++i)
        contains(buildMockGroupName(++expectationGroupCount)),
      for (var i = 0; i < 5; ++i)
        isNot(contains(buildMockGroupName(++expectationGroupCount))),
    ]);
    test(
      'in the presence of Groupless Options',
      () {
        expect(
          buildRunner(grouplessOptions + groupedOptions + hiddenGroups).usage,
          expectation,
        );
      },
    );
    test(
      'in the absence of Groupless Options',
      () {
        expect(
          buildRunner(groupedOptions + hiddenGroups).usage,
          expectation,
        );
      },
    );
  });

  group('Group Names are properly padded with newlines', () {
    final grouplessOptions = <OptionDefinition>[
      for (var i = 0; i < 5; ++i) buildMockOption(buildMockArgName(i), null),
    ];
    final groupedOptions = <OptionDefinition>[
      for (var i = 5; i < 10; ++i)
        buildMockOption(buildMockArgName(i), buildMockGroupName(i)),
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

  group('Only one Separator per unique Group Name', () {
    final grouplessOptions = <OptionDefinition>[
      for (var i = 0; i < 5; ++i) buildMockOption(buildMockArgName(i), null),
    ];
    final groupedOptions = <OptionDefinition>[
      for (var i = 5; i < 10; ++i)
        buildMockOption(buildMockArgName(i), buildMockGroupName('A')),
      for (var i = 10; i < 15; ++i)
        buildMockOption(buildMockArgName(i), buildMockGroupName('B')),
      for (var i = 15; i < 20; ++i)
        buildMockOption(buildMockArgName(i), buildMockGroupName('A')),
    ];
    void checkExpectation(final String usage) {
      expect(
        usage,
        stringContainsInOrder([
          buildSeparatorView(buildMockGroupName('A')),
          for (var i = 5; i < 10; ++i) buildMockArgName(i),
          for (var i = 15; i < 20; ++i) buildMockArgName(i),
          buildSeparatorView(buildMockGroupName('B')),
          for (var i = 10; i < 15; ++i) buildMockArgName(i),
        ]),
      );
      expect(
        howManyMatches(buildSeparatorView(buildMockGroupName('A')), usage),
        equals(1),
      );
      expect(
        howManyMatches(buildSeparatorView(buildMockGroupName('B')), usage),
        equals(1),
      );
    }

    test(
      'in the presence of Groupless Options',
      () {
        checkExpectation(buildRunner(grouplessOptions + groupedOptions).usage);
      },
    );
    test(
      'in the absence of Groupless Options',
      () {
        checkExpectation(buildRunner(groupedOptions).usage);
      },
    );
  });

  test(
    'All Groupless Options are shown before Grouped Options',
    () {
      final groupedOptions = <OptionDefinition>[
        for (var i = 0; i < 5; ++i)
          buildMockOption(buildMockArgName(i), buildMockGroupName(i)),
      ];
      final grouplessOptions = <OptionDefinition>[
        for (var i = 5; i < 10; ++i) buildMockOption(buildMockArgName(i), null),
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
          buildMockOption(buildMockArgName(++testOptionCount), null),
      ];
      final groupedOptions = <OptionDefinition>[
        for (var i = 0; i < 3; ++i)
          for (var j = 0; j < 5; ++j)
            buildMockOption(
              buildMockArgName(++testOptionCount),
              buildMockGroupName(i),
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
          buildMockOption(buildMockArgName(++optionCount), null),
      ];
      final groupedOptions = <OptionDefinition>[
        for (var i = 0; i < 3; ++i)
          for (var j = 0; j < 5; ++j)
            buildMockOption(
              buildMockArgName(++optionCount),
              buildMockGroupName(++testGroupCount),
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

  test(
    'Combined Behavior check (Groupless Options, Grouped Options, Hidden Groups)',
    () {
      final usage = buildRunner(<OptionDefinition>[
        buildMockOption('option-1', null),
        buildMockOption('option-2', 'Group 1'),
        buildMockOption('option-3', 'Group 2'),
        buildMockOption('option-4', 'Group 1'),
        buildMockOption('option-5', null),
        buildMockOption('option-6', 'Group 2'),
        buildMockOption('option-7', 'Group 3', hide: true),
        buildMockOption('option-8', 'Group 4', hide: true),
        buildMockOption('option-9', 'Group 4', hide: true),
        buildMockOption('option-10', 'Group 5', hide: true),
        buildMockOption('option-11', 'Group 5'),
      ]).usage;
      expect(
        usage,
        allOf([
          stringContainsInOrder([
            'option-1',
            'option-5',
            'Group 1',
            'option-2',
            'option-4',
            'Group 2',
            'option-3',
            'option-6',
            'Group 5',
            'option-11',
          ]),
          isNot(contains('Group 3')),
          isNot(contains('option-7')),
          isNot(contains('Group 4')),
          isNot(contains('option-8')),
          isNot(contains('option-9')),
          isNot(contains('option-10')),
        ]),
      );
      expect(howManyMatches('Group 1', usage), equals(1));
      expect(howManyMatches('Group 2', usage), equals(1));
      expect(howManyMatches('Group 5', usage), equals(1));
    },
  );
}
