import 'onboarding_draft.dart';

/// Resultado da criação/entrada na família durante o Onboarding.
class OnboardingResult {
  const OnboardingResult({
    required this.petId,
    required this.householdId,
    required this.inviteCode,
  });

  final String petId;
  final String householdId;
  final String inviteCode;
}

/// Contrato abstrato do repositório de Onboarding (Camada Domain — Dart puro).
abstract interface class OnboardingRepository {
  /// Inicia sessão anônima silenciosa no Supabase (Passo 0).
  Future<void> signInAnonymouslyIfNeeded();

  /// Executa a RPC `complete_onboarding` no fim do Passo 4 e gera o código
  /// de convite para o Passo 5.
  Future<OnboardingResult> completeOnboarding({
    required OnboardingDraft draft,
    required DateTime now,
  });

  /// Atualiza o nome de exibição do tutor no Passo 5.
  Future<void> updateTutorDisplayName(String displayName);

  /// Fluxo do convidado: entra em uma família existente usando código de 6 chars.
  Future<OnboardingResult> joinHousehold({
    required String code,
    required String displayName,
  });
}
