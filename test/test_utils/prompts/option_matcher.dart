import 'package:cli_tools/src/prompts/prompts.dart';

import 'package:test/test.dart';

Matcher equalsOption(Option expected) => _EqualsOptionMatcher(expected);
Matcher containsAllOptions(List<Option> expected) =>
    _EqualsAllOptionsMatcher(expected);

class _EqualsAllOptionsMatcher extends Matcher {
  final List<Option> _expected;

  _EqualsAllOptionsMatcher(this._expected);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! List<Option>) {
      return false;
    }

    if (item.length != _expected.length) {
      return false;
    }

    for (var i = 0; i < item.length; i++) {
      if (item[i].name != _expected[i].name) {
        return false;
      }
    }

    return true;
  }

  @override
  Description describe(Description description) {
    return description.add('List of Options');
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! List<Option>) {
      return mismatchDescription.add('is not a List of Options');
    }

    if (item.length != _expected.length) {
      return mismatchDescription.add('has length ${item.length}');
    }

    for (var i = 0; i < item.length; i++) {
      if (item[i].name != _expected[i].name) {
        return mismatchDescription.add(
          'Option at index $i has name "${item[i].name}"',
        );
      }
    }

    return mismatchDescription;
  }
}

class _EqualsOptionMatcher extends Matcher {
  final Option _expected;

  _EqualsOptionMatcher(this._expected);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! Option) {
      return false;
    }

    return item.name == _expected.name;
  }

  @override
  Description describe(Description description) {
    return description.add('Option with name "${_expected.name}"');
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (item is! Option) {
      return mismatchDescription.add('is not an Option');
    }

    return mismatchDescription.add('has name "${item.name}"');
  }
}
