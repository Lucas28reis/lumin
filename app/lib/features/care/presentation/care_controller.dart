import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/core_providers.dart';
import '../../avatar/domain/avatar_dna.dart';
import '../../avatar/domain/avatar_mood.dart';
import '../../avatar/domain/mood_resolver.dart';
import '../../onboarding/domain/onboarding_draft.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../domain/care_slot.dart';

class CareHomeState {
  const CareHomeState({
    required this.petName,
    this.petGender = PetGender.male,
    required this.tutorName,
    required this.inviteCode,
    required this.avatarDna,
    required this.slots,
    required this.streakDays,
    required this.freezesAvailable,
    required this.householdMemberCount,
    this.lastCareLoggedAt,
    this.lastCompletedLogId,
    this.bannerMessage,
    this.hasShownAccountLinkPrompt = false,
    this.isAccountLinked = false,
  });

  final String petName;
  final PetGender petGender;
  final String tutorName;
  final String inviteCode;
  final AvatarDna avatarDna;
  final List<CareSlotItem> slots;
  final int streakDays;
  final int freezesAvailable;
  final int householdMemberCount;
  final DateTime? lastCareLoggedAt;
  final String? lastCompletedLogId;
  final String? bannerMessage;
  final bool hasShownAccountLinkPrompt;
  final bool isAccountLinked;

  CareSlotItem? get nextPendingSlot => NextSlotResolver.resolveNextPending(slots);

  bool get isDayComplete =>
      slots.where((s) => s.kind != CareSlotKind.interval).isNotEmpty &&
      slots.where((s) => s.kind != CareSlotKind.interval).every((s) => s.isDone);

  AvatarMood resolveMood(DateTime now) {
    final feedSlots = slots
        .where((s) => s.kind == CareSlotKind.dailyFeed)
        .map((s) => (
              hour: s.scheduledHour ?? 8,
              minute: s.scheduledMinute ?? 0,
              isDone: s.isDone,
            ))
        .toList();

    final walkSlots = slots
        .where((s) => s.kind == CareSlotKind.dailyWalk)
        .map((s) => (
              hour: s.scheduledHour ?? 18,
              minute: s.scheduledMinute ?? 0,
              isDone: s.isDone,
            ))
        .toList();

    final hasOverdueInterval = slots.any(
      (s) => s.kind == CareSlotKind.interval && !s.isDone,
    );

    return MoodResolver.resolve(
      now: now,
      lastCareLoggedAt: lastCareLoggedAt,
      todayFeedSlots: feedSlots,
      todayWalkSlots: walkSlots,
      hasOverdueIntervalTask: hasOverdueInterval,
    );
  }

  CareHomeState copyWith({
    String? petName,
    PetGender? petGender,
    String? tutorName,
    String? inviteCode,
    AvatarDna? avatarDna,
    List<CareSlotItem>? slots,
    int? streakDays,
    int? freezesAvailable,
    int? householdMemberCount,
    DateTime? lastCareLoggedAt,
    String? lastCompletedLogId,
    String? bannerMessage,
    bool clearBanner = false,
    bool? hasShownAccountLinkPrompt,
    bool? isAccountLinked,
  }) {
    return CareHomeState(
      petName: petName ?? this.petName,
      petGender: petGender ?? this.petGender,
      tutorName: tutorName ?? this.tutorName,
      inviteCode: inviteCode ?? this.inviteCode,
      avatarDna: avatarDna ?? this.avatarDna,
      slots: slots ?? this.slots,
      streakDays: streakDays ?? this.streakDays,
      freezesAvailable: freezesAvailable ?? this.freezesAvailable,
      householdMemberCount: householdMemberCount ?? this.householdMemberCount,
      lastCareLoggedAt: lastCareLoggedAt ?? this.lastCareLoggedAt,
      lastCompletedLogId: lastCompletedLogId ?? this.lastCompletedLogId,
      bannerMessage: clearBanner ? null : (bannerMessage ?? this.bannerMessage),
      hasShownAccountLinkPrompt:
          hasShownAccountLinkPrompt ?? this.hasShownAccountLinkPrompt,
      isAccountLinked: isAccountLinked ?? this.isAccountLinked,
    );
  }
}

class CareController extends Notifier<CareHomeState> {
  static const Uuid _uuid = Uuid();

  @override
  CareHomeState build() {
    final onboarding = ref.watch(onboardingControllerProvider);
    final draft = onboarding.draft;
    final petName =
        draft.petName.trim().isEmpty ? 'Paçoca' : draft.petName.trim();
    final tutorName = draft.tutorDisplayName.trim().isEmpty
        ? 'Tutor'
        : draft.tutorDisplayName.trim();

    final slots = _buildSlotsFromDraft(draft, petName);

    return CareHomeState(
      petName: petName,
      petGender: draft.gender,
      tutorName: tutorName,
      inviteCode: onboarding.inviteCode ?? 'LUMIN2',
      avatarDna: draft.avatarDna,
      slots: slots,
      streakDays: 0,
      freezesAvailable: 1,
      householdMemberCount: onboarding.mode == OnboardingFlowMode.guest ? 2 : 1,
    );
  }

  /// Registra um cuidado em 1 toque (otimista + idempotente).
  /// Retorna se deve exibir o bottom sheet de salvar conta e o `logId` criado.
  ({bool shouldPromptAccountLink, String? logId}) logCareSlot(
    String slotId, {
    String? customActorName,
  }) {
    final now = ref.read(clockProvider).now();
    final analytics = ref.read(analyticsProvider);
    final actor = customActorName ?? state.tutorName;
    final logId = _uuid.v4();

    final index = state.slots.indexWhere((s) => s.id == slotId);
    if (index == -1) {
      return (shouldPromptAccountLink: false, logId: null);
    }

    final target = state.slots[index];
    if (target.isDone) {
      analytics.track('care_already_done', {'slot_id': slotId});
      state = state.copyWith(
        bannerMessage:
            '${target.doneByName ?? "Outro tutor"} já tinha marcado "${target.title}" 💛',
      );
      return (shouldPromptAccountLink: false, logId: null);
    }

    final wasCompleteBefore = state.isDayComplete;
    final updatedSlots = List<CareSlotItem>.from(state.slots);
    updatedSlots[index] = target.copyWith(
      isDone: true,
      doneByName: actor,
      doneAt: now,
      logId: logId,
    );

    final nextState = state.copyWith(
      slots: updatedSlots,
      lastCareLoggedAt: now,
      lastCompletedLogId: logId,
      clearBanner: true,
    );

    final isCompleteNow = nextState.isDayComplete;
    final updatedStreak = (!wasCompleteBefore && isCompleteNow)
        ? state.streakDays + 1
        : state.streakDays;

    analytics.track('care_logged', {
      'type': target.kind.name,
      'source': 'tap',
    });

    if (!wasCompleteBefore && isCompleteNow) {
      analytics.track('day_completed', {'streak': updatedStreak});
    }

    final shouldPromptAccountLink =
        !state.hasShownAccountLinkPrompt && !state.isAccountLinked;

    state = nextState.copyWith(
      streakDays: updatedStreak,
      hasShownAccountLinkPrompt:
          state.hasShownAccountLinkPrompt || shouldPromptAccountLink,
    );

    return (shouldPromptAccountLink: shouldPromptAccountLink, logId: logId);
  }

  /// Desfaz o último cuidado registrado (janela de toque acidental).
  void undoLastCare(String logId) {
    final index = state.slots.indexWhere((s) => s.logId == logId);
    if (index == -1) return;

    final wasCompleteBefore = state.isDayComplete;
    final updatedSlots = List<CareSlotItem>.from(state.slots);
    updatedSlots[index] = updatedSlots[index].copyWith(clearCompletion: true);

    final nextState = state.copyWith(
      slots: updatedSlots,
      clearBanner: true,
    );

    final updatedStreak = (wasCompleteBefore && !nextState.isDayComplete)
        ? (state.streakDays > 0 ? state.streakDays - 1 : 0)
        : state.streakDays;

    ref.read(analyticsProvider).track('care_undone', {'log_id': logId});

    state = nextState.copyWith(streakDays: updatedStreak);
  }

  /// Simula um co-tutor registrando uma tarefa em tempo real (para validação
  /// imediata do diferencial de sincronização familiar).
  void simulateCoTutorAction() {
    final nextSlot = state.nextPendingSlot;
    if (nextSlot == null) return;
    logCareSlot(nextSlot.id, customActorName: 'Parceiro(a)');
    state = state.copyWith(
      householdMemberCount: 2,
      bannerMessage:
          '🍖 Parceiro(a) acabou de marcar "${nextSlot.title}" em tempo real!',
    );
  }

  void markAccountLinked(String provider) {
    ref.read(analyticsProvider).track('account_linked', {'provider': provider});
    state = state.copyWith(
      isAccountLinked: true,
      bannerMessage: 'Conta vinculada com $provider! Progresso protegido 🔒',
    );
  }

  static List<CareSlotItem> _buildSlotsFromDraft(
    OnboardingDraft draft,
    String petName,
  ) {
    final dailySlots = <CareSlotItem>[];

    final feedTimes = draft.activeFeedTimes;
    for (var i = 0; i < feedTimes.length; i++) {
      final parts = feedTimes[i].split(':');
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      dailySlots.add(
        CareSlotItem(
          id: 'feed-$i',
          taskId: 'task-feed',
          slotIndex: i,
          kind: CareSlotKind.dailyFeed,
          title: 'Alimentar $petName (${feedTimes[i]})',
          subtitle: 'Refeição ${i + 1} de ${feedTimes.length}',
          emoji: '🍖',
          scheduledHour: hour,
          scheduledMinute: minute,
        ),
      );
    }

    final walkTimes = draft.activeWalkTimes;
    for (var i = 0; i < walkTimes.length; i++) {
      final parts = walkTimes[i].split(':');
      final hour = int.tryParse(parts[0]) ?? 18;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      dailySlots.add(
        CareSlotItem(
          id: 'walk-$i',
          taskId: 'task-walk',
          slotIndex: i,
          kind: CareSlotKind.dailyWalk,
          title: 'Passeio com $petName (${walkTimes[i]})',
          subtitle: 'Passeio ${i + 1} de ${walkTimes.length}',
          emoji: '🦮',
          scheduledHour: hour,
          scheduledMinute: minute,
        ),
      );
    }

    // Ordena cronologicamente: 07:30 (Passeio) -> 08:00 (Comida) -> 18:30 (Passeio) -> 19:00 (Comida)
    dailySlots.sort((a, b) => a.sortMinutes.compareTo(b.sortMinutes));

    final result = <CareSlotItem>[...dailySlots];

    for (final entry in draft.forgettableCare.entries) {
      if (entry.value != LastDoneRecency.thisMonth) {
        result.add(
          CareSlotItem(
            id: 'interval-${entry.key.code}',
            taskId: 'task-${entry.key.code}',
            slotIndex: 0,
            kind: CareSlotKind.interval,
            title: '${entry.key.label} do $petName',
            subtitle: 'Cuidado periódico pendente hoje',
            emoji: entry.key.emoji,
          ),
        );
      }
    }

    return result;
  }
}

final careControllerProvider =
    NotifierProvider<CareController, CareHomeState>(CareController.new);
