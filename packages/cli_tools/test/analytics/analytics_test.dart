import 'dart:async';

import 'package:cli_tools/analytics.dart';
import 'package:test/test.dart';

import '../test_utils/test_utils.dart' show flushEventQueue;

void main() {
  test(
    'Given analytics with a pending event, '
    'when flushing before the event send completes, '
    'then flush waits until the event send completes.',
    () async {
      final analytics = PendingAnalytics();
      analytics.track(event: 'test');

      var isFlushed = false;
      final flush = analytics.flush().then((final _) {
        isFlushed = true;
      });

      await flushEventQueue();
      expect(isFlushed, isFalse);

      analytics.completers.single.complete();
      await flush;
      expect(isFlushed, isTrue);
    },
  );

  test(
    'Given analytics with a pending event, '
    'when the event send fails while flushing, '
    'then flush waits for the event and ignores the send failure.',
    () async {
      final analytics = PendingAnalytics();

      analytics.track(event: 'test');

      final flush = expectLater(analytics.flush(), completes);
      await flushEventQueue();

      analytics.completers.single.completeError(
        StateError('Failed to send event.'),
      );

      await expectLater(flush, completes);
    },
  );

  test(
    'Given compound analytics with a provider that fails to flush, '
    'when flushing the compound analytics, '
    'then all providers are flushed and the failure is ignored.',
    () async {
      final failingProvider = FailingFlushAnalytics();
      final recordingProvider = RecordingFlushAnalytics();
      final analytics = CompoundAnalytics([failingProvider, recordingProvider]);

      await expectLater(analytics.flush(), completes);

      expect(failingProvider.didFlush, isTrue);
      expect(recordingProvider.didFlush, isTrue);
    },
  );
}

class PendingAnalytics extends Analytics {
  final completers = <Completer<void>>[];

  @override
  Future<void> sendEvent({
    required final String event,
    final Map<String, dynamic> properties = const {},
  }) {
    final completer = Completer<void>();
    completers.add(completer);
    return completer.future;
  }
}

class FailingFlushAnalytics extends Analytics {
  var didFlush = false;

  @override
  Future<void> flush() {
    didFlush = true;
    throw StateError('Failed to flush events.');
  }

  @override
  Future<void> sendEvent({
    required final String event,
    final Map<String, dynamic> properties = const {},
  }) async {}
}

class RecordingFlushAnalytics extends Analytics {
  var didFlush = false;

  @override
  Future<void> flush() async {
    didFlush = true;
  }

  @override
  Future<void> sendEvent({
    required final String event,
    final Map<String, dynamic> properties = const {},
  }) async {}
}
