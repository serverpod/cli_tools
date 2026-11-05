import 'package:serverpod_logging/serverpod_logging.dart';
import 'package:test/test.dart';

/// A writer that records every scope label it is ever asked to render,
/// regardless of which lifecycle hook delivered it.
///
/// This is deliberately a *generic* sink (think: a JSON line writer, a DB
/// writer, an OTEL exporter) - it does not animate spinners or care about
/// terminals. It exists to pin a framework-level contract:
///
///   `Log.progress(label, runner)` describes ONE operation called [label].
///   The runner's *return value* is data, not a new name for the operation.
///
class _LabelRecordingWriter extends LogWriter {
  final List<String> observedLabels = [];

  @override
  Future<void> log(LogEntry entry) async {}

  @override
  Future<void> openScope(LogScope scope) async =>
      observedLabels.add(scope.label);

  @override
  Future<void> closeScope(
    LogScope scope, {
    required bool success,
    required Duration duration,
    Object? error,
    StackTrace? stackTrace,
  }) async => observedLabels.add(scope.label);
}

void main() {
  group('Given Log.progress with a plain (non-stream) runner', () {
    late _LabelRecordingWriter writer;
    late Log log;

    setUp(() {
      writer = _LabelRecordingWriter();
      log = Log(writer);
    });

    test('when the runner returns a value, '
        'then no scope event is labelled with that value', () async {
      await log.progress<String>('op', () async => 'sentinel-result');
      await log.flush();

      expect(
        writer.observedLabels,
        everyElement('op'),
        reason:
            'progress must not relabel the scope with the runner result; '
            'the operation is called "op" from start to finish',
      );
      expect(
        writer.observedLabels,
        isNot(contains('sentinel-result')),
        reason: 'the runner return value must never surface as a scope label',
      );
    });

    test('when the runner returns true, '
        'then the scope label stays "op" (not "true")', () async {
      await log.progress<bool>('op', () async => true);
      await log.flush();

      expect(writer.observedLabels, everyElement('op'));
      expect(writer.observedLabels, isNot(contains('true')));
    });
  });
}
