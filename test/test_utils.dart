/// Test helper to flush the event queue.
/// Useful for waiting for async events to complete before continuing the test.
Future<void> flushEventQueue() {
  return Future.delayed(Duration.zero);
}
