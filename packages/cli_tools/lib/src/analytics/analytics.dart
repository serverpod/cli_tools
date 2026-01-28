/// Interface for analytics services.
abstract interface class Analytics {
  /// Clean up resources.
  void cleanUp();

  /// Track an event.
  void track({
    required final String event,
    final Map<String, dynamic> properties = const {},
  });
}

class CompoundAnalytics implements Analytics {
  final List<Analytics> providers;

  CompoundAnalytics(this.providers);

  @override
  void cleanUp() {
    for (final provider in providers) {
      provider.cleanUp();
    }
  }

  @override
  void track({
    required final String event,
    final Map<String, dynamic> properties = const {},
  }) {
    for (final provider in providers) {
      provider.track(
        event: event,
        properties: properties,
      );
    }
  }
}
