import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../analytics/analytics.dart';
import '../clock/clock.dart';
import '../env/env.dart';

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final analyticsProvider = Provider<Analytics>((ref) => DebugAnalytics());

/// Inicializado no `bootstrap.dart` e injetado via `ProviderScope.overrides`.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider deve ser sobrescrito');
});

/// Retorna o `SupabaseClient` se `SUPABASE_URL` e `SUPABASE_ANON_KEY` estiverem
/// definidos; caso contrário retorna `null` (modo local/offline).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!Env.hasSupabase) return null;
  return Supabase.instance.client;
});
