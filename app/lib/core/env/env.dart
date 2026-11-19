/// Variáveis de ambiente injetadas via `--dart-define`.
/// Quando não configuradas, o app opera em modo offline/local para desenvolvimento
/// e validação imediata do fluxo de UI e domínio.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
