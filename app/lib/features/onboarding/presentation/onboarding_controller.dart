import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/providers/core_providers.dart';
import '../../avatar/domain/avatar_dna.dart';
import '../domain/onboarding_draft.dart';
import '../onboarding_di.dart';

enum OnboardingFlowMode { creator, guest }

class OnboardingState {
  const OnboardingState({
    required this.currentStep,
    required this.mode,
    required this.draft,
    this.petId,
    this.inviteCode,
    this.guestCodeInput = '',
    this.isSubmitting = false,
    this.errorMessage,
    this.isFinished = false,
  });

  /// Passos no modo `creator`:
  /// 0: Boas-vindas
  /// 1: Espécie + Nome
  /// 2: Montar Avatar
  /// 3: Rotina diária
  /// 4: Cuidados esquecíveis (salva o pet no fim via RPC)
  /// 5: Quem mais cuida? + convite WhatsApp
  /// 6: Permissão de notificações -> Home
  final int currentStep;
  final OnboardingFlowMode mode;
  final OnboardingDraft draft;
  final String? petId;
  final String? inviteCode;
  final String guestCodeInput;
  final bool isSubmitting;
  final String? errorMessage;
  final bool isFinished;

  bool get canGoBack =>
      !isSubmitting &&
      ((mode == OnboardingFlowMode.creator && currentStep > 0) ||
          (mode == OnboardingFlowMode.guest && currentStep > 0));

  OnboardingState copyWith({
    int? currentStep,
    OnboardingFlowMode? mode,
    OnboardingDraft? draft,
    String? petId,
    String? inviteCode,
    String? guestCodeInput,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    bool? isFinished,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      mode: mode ?? this.mode,
      draft: draft ?? this.draft,
      petId: petId ?? this.petId,
      inviteCode: inviteCode ?? this.inviteCode,
      guestCodeInput: guestCodeInput ?? this.guestCodeInput,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isFinished: isFinished ?? this.isFinished,
    );
  }
}

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final store = ref.watch(draftLocalStoreProvider);
    final step = store.loadStep();
    final draft = store.loadDraft();
    final petId = store.loadCompletedPetId();
    final inviteCode = store.loadInviteCode();
    final finished = store.isOnboardingFinished();

    return OnboardingState(
      currentStep: step.clamp(0, 6),
      mode: OnboardingFlowMode.creator,
      draft: draft,
      petId: petId,
      inviteCode: inviteCode,
      isFinished: finished,
    );
  }

  Future<void> startCreatorFlow() async {
    final analytics = ref.read(analyticsProvider);
    final repo = ref.read(onboardingRepositoryProvider);

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await repo.signInAnonymouslyIfNeeded();
      analytics.track('onboarding_step_completed', {'step': 0, 'mode': 'creator'});
      await _goToStep(1, mode: OnboardingFlowMode.creator);
    } catch (_) {
      // Mesmo se falhar rede no login anônimo, permite avançar com rascunho local
      await _goToStep(1, mode: OnboardingFlowMode.creator);
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  void startGuestFlow() {
    ref.read(analyticsProvider).track(
      'onboarding_step_viewed',
      {'step': 1, 'mode': 'guest'},
    );
    state = state.copyWith(
      mode: OnboardingFlowMode.guest,
      currentStep: 1,
      clearError: true,
    );
  }

  Future<void> goBack() async {
    if (!state.canGoBack) return;
    if (state.mode == OnboardingFlowMode.guest && state.currentStep == 1) {
      state = state.copyWith(
        mode: OnboardingFlowMode.creator,
        currentStep: 0,
        clearError: true,
      );
      return;
    }
    await _goToStep(state.currentStep - 1);
  }

  void selectSpecies(PetSpecies species) {
    if (state.draft.species == species) return;
    // Ajusta preset de passeio padrão conforme espécie (Seção 4.2: cão=2x, gato=nenhum)
    final defaultWalk =
        species == PetSpecies.dog ? WalkPreset.twice : WalkPreset.none;
    final updated = state.draft.copyWith(
      species: species,
      walkPreset: defaultWalk,
      avatarDna: AvatarDna.initial(species: species),
    );
    _updateDraft(updated);
  }

  void selectGender(PetGender gender) {
    if (state.draft.gender == gender) return;
    _updateDraft(state.draft.copyWith(gender: gender));
  }

  void updatePetName(String name) {
    _updateDraft(state.draft.copyWith(petName: name));
  }

  Future<void> submitStep1PetInfo() async {
    if (state.draft.petName.trim().isEmpty) return;
    ref.read(analyticsProvider).track('onboarding_step_completed', {
      'step': 1,
      'species': state.draft.species.code,
    });
    await _goToStep(2);
  }

  void updateAvatarDna(AvatarDna dna) {
    _updateDraft(state.draft.copyWith(avatarDna: dna));
  }

  void randomizeAvatar() {
    ref.read(analyticsProvider).track('avatar_randomized', {
      'species': state.draft.species.code,
    });
    _updateDraft(
      state.draft.copyWith(
        avatarDna: AvatarDna.random(species: state.draft.species),
      ),
    );
  }

  Future<void> submitStep2Avatar() async {
    ref.read(analyticsProvider).track('onboarding_step_completed', {'step': 2});
    await _goToStep(3);
  }

  void selectFeedPreset(FeedPreset preset) {
    _updateDraft(state.draft.copyWith(feedPreset: preset));
  }

  void selectWalkPreset(WalkPreset preset) {
    _updateDraft(state.draft.copyWith(walkPreset: preset));
  }

  Future<void> submitStep3Routine() async {
    ref.read(analyticsProvider).track('onboarding_step_completed', {
      'step': 3,
      'feed_preset': state.draft.feedPreset.code,
      'walk_preset': state.draft.walkPreset.code,
    });
    await _goToStep(4);
  }

  void toggleForgettableCare(ForgettableCareType type) {
    final map = Map<ForgettableCareType, LastDoneRecency>.from(
      state.draft.forgettableCare,
    );
    if (map.containsKey(type)) {
      map.remove(type);
    } else {
      map[type] = LastDoneRecency.dontRemember;
    }
    _updateDraft(state.draft.copyWith(forgettableCare: map));
  }

  void setForgettableCareRecency(
    ForgettableCareType type,
    LastDoneRecency recency,
  ) {
    final map = Map<ForgettableCareType, LastDoneRecency>.from(
      state.draft.forgettableCare,
    );
    map[type] = recency;
    _updateDraft(state.draft.copyWith(forgettableCare: map));
  }

  /// Passo 4 -> Passo 5: Salva o pet atomicamente via `complete_onboarding`.
  Future<void> submitStep4ForgettableCare({bool skipped = false}) async {
    if (skipped) {
      _updateDraft(state.draft.copyWith(forgettableCare: const {}));
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final now = ref.read(clockProvider).now();
      final result = await ref
          .read(onboardingRepositoryProvider)
          .completeOnboarding(draft: state.draft, now: now);

      ref.read(analyticsProvider).track('onboarding_step_completed', {
        'step': 4,
        'skipped': skipped,
        'care_count': state.draft.forgettableCare.length,
      });

      state = state.copyWith(
        petId: result.petId,
        inviteCode: result.inviteCode,
        isSubmitting: false,
      );
      await _goToStep(5);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e is Failure
            ? e.message
            : 'Não foi possível salvar agora. Tente novamente.',
      );
    }
  }

  void updateTutorDisplayName(String name) {
    _updateDraft(state.draft.copyWith(tutorDisplayName: name));
  }

  Future<void> submitStep5Household({required bool sharedInvite}) async {
    final analytics = ref.read(analyticsProvider);
    if (sharedInvite) {
      analytics.track('invite_shared', {'channel': 'share_sheet'});
    }
    await ref
        .read(onboardingRepositoryProvider)
        .updateTutorDisplayName(state.draft.tutorDisplayName);
    analytics.track('onboarding_step_completed', {
      'step': 5,
      'shared_invite': sharedInvite,
    });
    await _goToStep(6);
  }

  Future<void> finishOnboarding({required bool grantedPush}) async {
    final analytics = ref.read(analyticsProvider);
    final store = ref.read(draftLocalStoreProvider);
    analytics.track('push_permission', {'granted': grantedPush});
    analytics.track('onboarding_completed', {
      'mode': state.mode.name,
      'species': state.draft.species.code,
    });
    await store.markOnboardingFinished();
    state = state.copyWith(isFinished: true);
  }

  // --- Fluxo do Convidado (Seção 4.3) ---

  void updateGuestCodeInput(String value) {
    state = state.copyWith(
      guestCodeInput: value.toUpperCase(),
      clearError: true,
    );
  }

  Future<void> submitGuestJoin() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final result = await ref.read(onboardingRepositoryProvider).joinHousehold(
            code: state.guestCodeInput,
            displayName: state.draft.tutorDisplayName,
          );
      ref.read(analyticsProvider).track('invite_joined', {
        'code': result.inviteCode,
      });
      state = state.copyWith(
        petId: result.petId,
        inviteCode: result.inviteCode,
        isSubmitting: false,
        currentStep: 2, // Revelação + Notificações do convidado
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e is Failure
            ? e.message
            : 'Código inválido ou expirado. Confira com quem te convidou.',
      );
    }
  }

  void _updateDraft(OnboardingDraft updated) {
    state = state.copyWith(draft: updated, clearError: true);
    ref.read(draftLocalStoreProvider).saveDraft(updated);
  }

  Future<void> _goToStep(int step, {OnboardingFlowMode? mode}) async {
    final targetMode = mode ?? state.mode;
    await ref.read(draftLocalStoreProvider).saveStep(step);
    ref.read(analyticsProvider).track('onboarding_step_viewed', {
      'step': step,
      'mode': targetMode.name,
    });
    state = state.copyWith(
      currentStep: step,
      mode: targetMode,
      clearError: true,
    );
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
