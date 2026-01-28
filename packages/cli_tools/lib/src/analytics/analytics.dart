/// Interface for analytics services.
abstract interface class Analytics {
  /// Clean up resources.
  void cleanUp();

  /// Track an event.
  void track({
    required final String event,
    final Map<String, dynamic> properties = const {},
  });

  /// Identifies a user with additional properties (e.g., email).
  void identify({
    final String? email,
    final Map<String, dynamic>? properties,
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

  @override
  void identify({
    final String? email,
    final Map<String, dynamic>? properties,
  }) {
    for (final provider in providers) {
      provider.identify(
        email: email,
        properties: properties,
      );
    }
  }
}
