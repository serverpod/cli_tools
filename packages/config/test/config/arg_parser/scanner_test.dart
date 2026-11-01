import 'package:config/src/config/arg_parser/arg_parser.dart';
import 'package:test/test.dart';

void main() {
  group('Given a single command line argument', () {
    test('when it is a long option then its spelling is awaiting a value', () {
      expect(optionAwaitingValue('--target'), '--target');
    });

    test('when it is a short option then its spelling is awaiting a value', () {
      expect(optionAwaitingValue('-t'), '-t');
    });

    test('when it is a cluster of short options '
        'then the last one is awaiting a value', () {
      expect(optionAwaitingValue('-vft'), '-t');
    });

    test('when the option has an attached value '
        'then no option is awaiting a value', () {
      expect(optionAwaitingValue('--target=x'), isNull);
      expect(optionAwaitingValue('-t=x'), isNull);
      expect(optionAwaitingValue('--target='), isNull);
    });

    test('when it is a word or a dash argument '
        'then no option is awaiting a value', () {
      expect(optionAwaitingValue('build'), isNull);
      expect(optionAwaitingValue(''), isNull);
      expect(optionAwaitingValue('--'), isNull);
      expect(optionAwaitingValue('-'), isNull);
    });
  });
}
