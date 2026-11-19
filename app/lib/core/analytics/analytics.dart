import 'package:flutter/foundation.dart';

/// Contrato de Analytics (Seção 9 da SPEC_MVP.md).
abstract interface class Analytics {
  void track(String event, [Map<String, Object?> properties = const {}]);
}

final class DebugAnalytics implements Analytics {
  final List<({String event, Map<String, Object?> properties})> events = [];

  @override
  void track(String event, [Map<String, Object?> properties = const {}]) {
    events.add((event: event, properties: properties));
    if (kDebugMode) {
      debugPrint('[Analytics] $event ${properties.isEmpty ? "" : properties}');
    }
  }
}
