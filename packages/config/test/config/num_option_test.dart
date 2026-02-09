import 'package:config/config.dart' show NumOption, Configuration;
import 'package:test/test.dart';

void main() {
  group('Given a NumOption<double>', () {
    const numOpt = NumOption<double>(argName: 'num', mandatory: true);
    group('when a fractional number is passed', () {
      final config = Configuration.resolveNoExcept(
        options: [numOpt],
        args: ['--num', '123.45'],
      );
      test('then it is parsed successfully', () {
        expect(config.errors, isEmpty);
        expect(
          config.value(numOpt),
          equals(123.45),
        );
      });
      test('then the runtime type is double', () {
        expect(
          config.value(numOpt).runtimeType,
          equals(double),
        );
      });
    });
    group('when an integer number is passed', () {
      final config = Configuration.resolveNoExcept(
        options: [numOpt],
        args: ['--num', '12345'],
      );
      test('then it is parsed successfully', () {
        expect(config.errors, isEmpty);
        expect(
          config.value(numOpt),
          equals(12345),
        );
      });
      test('then the runtime type is double', () {
        expect(
          config.value(numOpt).runtimeType,
          equals(double),
        );
      });
    });
    group('when a non-{double,int} value is passed', () {
      final config = Configuration.resolveNoExcept(
        options: [numOpt],
        args: ['--num', '12i+345j'],
      );
      test('then it is not parsed successfully', () {
        expect(config.errors, isNotEmpty);
      });
    });
  });
  group('Given a NumOption<int>', () {
    const numOpt = NumOption<int>(argName: 'num', mandatory: true);
    group('when an integer number is passed', () {
      final config = Configuration.resolveNoExcept(
        options: [numOpt],
        args: ['--num', '12345'],
      );
      test('then it is parsed successfully', () {
        expect(config.errors, isEmpty);
        expect(
          config.value(numOpt),
          equals(12345),
        );
      });
      test('then the runtime type is int', () {
        expect(
          config.value(numOpt).runtimeType,
          equals(int),
        );
      });
    });
    group('when a fractional number is passed', () {
      final config = Configuration.resolveNoExcept(
        options: [numOpt],
        args: ['--num', '123.45'],
      );
      test('then it is not parsed successfully', () {
        expect(config.errors, isNotEmpty);
      });
    });
    group('when a non-{double,int} value is passed', () {
      final config = Configuration.resolveNoExcept(
        options: [numOpt],
        args: ['--num', '12i+345j'],
      );
      test('then it is not parsed successfully', () {
        expect(config.errors, isNotEmpty);
      });
    });
  });
  group('Given a NumOption<num>', () {
    const numOpt = NumOption<num>(argName: 'num', mandatory: true);
    group('when a fractional number is passed', () {
      final config = Configuration.resolveNoExcept(
        options: [numOpt],
        args: ['--num', '123.45'],
      );
      test('then it is parsed successfully', () {
        expect(config.errors, isEmpty);
        expect(
          config.value(numOpt),
          equals(123.45),
        );
      });
      test('then the runtime type is double', () {
        expect(
          config.value(numOpt).runtimeType,
          equals(double),
        );
      });
    });
    group('when an integer number is passed', () {
      final config = Configuration.resolveNoExcept(
        options: [numOpt],
        args: ['--num', '12345'],
      );
      test('then it is parsed successfully', () {
        expect(config.errors, isEmpty);
        expect(
          config.value(numOpt),
          equals(12345),
        );
      });
      test('then the runtime type is int', () {
        expect(
          config.value(numOpt).runtimeType,
          equals(int),
        );
      });
    });
    group('when a non-{double,int} value is passed', () {
      final config = Configuration.resolveNoExcept(
        options: [numOpt],
        args: ['--num', '12i+345j'],
      );
      test('then it is not parsed successfully', () {
        expect(config.errors, isNotEmpty);
      });
    });
  });
  group('Given a NumOption<Never>', () {
    const numOpt = NumOption<Never>(argName: 'num', mandatory: true);
    group('when any value is passed', () {
      test('then it reports an UnsupportedError', () {
        for (final val in ['123.45', '12345', '12i+345j']) {
          expect(
            () => Configuration.resolveNoExcept(
              options: [numOpt],
              args: ['--num', val],
            ),
            throwsUnsupportedError,
          );
        }
      });
    });
  });
}
