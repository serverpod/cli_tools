/// Base class for analytics services.
abstract class Analytics {
  final _pendingTracks = <Future<void>>{};

  /// Clean up resources.
  void cleanUp() {}

  /// Flush pending analytics events.
  Future<void> flush() async {
    while (_pendingTracks.isNotEmpty) {
      await Future.wait([
        for (final pendingTrack in _pendingTracks)
          pendingTrack.catchError((final _) {}),
      ]);
    }
  }

  /// Track an event.
  void track({
    required final String event,
    final Map<String, dynamic> properties = const {},
  }) {
    late final Future<void> pendingTrack;
    pendingTrack = sendEvent(event: event, properties: properties)
        .catchError((final _) {})
        .whenComplete(() => _pendingTracks.remove(pendingTrack));
    _pendingTracks.add(pendingTrack);
  }

  /// Send an event to the analytics service.
  Future<void> sendEvent({
    required final String event,
    final Map<String, dynamic> properties = const {},
  });
}

class CompoundAnalytics extends Analytics {
  final List<Analytics> providers;

  CompoundAnalytics(this.providers);

  @override
  void cleanUp() {
    for (final provider in providers) {
      provider.cleanUp();
    }
  }

  @override
  Future<void> flush() async {
    await Future.wait([
      for (final provider in providers)
        Future.sync(provider.flush).catchError((final _) {}),
    ]);
  }

  @override
  Future<void> sendEvent({
    required final String event,
    final Map<String, dynamic> properties = const {},
  }) async {
    for (final provider in providers) {
      provider.track(
        event: event,
        properties: properties,
      );
    }
  }
}
