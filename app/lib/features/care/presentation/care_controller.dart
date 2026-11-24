import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../../core/providers/core_providers.dart';
import '../../avatar/domain/avatar_dna.dart';
import '../../avatar/domain/avatar_mood.dart';
import '../../avatar/domain/mood_resolver.dart';
import '../../notifications/notification_care_action.dart';
import '../../onboarding/domain/onboarding_draft.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../domain/care_slot.dart';
import '../domain/periodic_care.dart';

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

  CareSlotItem? get nextPendingSlot =>
      NextSlotResolver.resolveNextPending(slots);

  bool get isDayComplete =>
      slots.where((s) => s.kind != CareSlotKind.interval).isNotEmpty &&
      slots
          .where((s) => s.kind != CareSlotKind.interval)
          .every((s) => s.isDone);

  AvatarMood resolveMood(DateTime now) {
    final feedSlots = slots
        .where((s) => s.kind == CareSlotKind.dailyFeed)
        .map(
          (s) => (
            hour: s.scheduledHour ?? 8,
            minute: s.scheduledMinute ?? 0,
            isDone: s.isDone,
          ),
        )
        .toList();

    final walkSlots = slots
        .where((s) => s.kind == CareSlotKind.dailyWalk)
        .map(
          (s) => (
            hour: s.scheduledHour ?? 18,
            minute: s.scheduledMinute ?? 0,
            isDone: s.isDone,
          ),
        )
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
  String _key = '';
  String _day = '';
  bool _busy = false;
  bool _refreshing = false;
  bool _remoteReady = false;
  DateTime? _localFleaDue;
  final _periodic = <String, PeriodicCare?>{};
  final _previousDates = <String, String>{};
  Map<String, PeriodicCare?> get periodic => Map.unmodifiable(_periodic);
  final Map<String, dynamic> _history = {};
  final _bonusDates = <String, String>{};
  final Set<String> _completeDays = {};
  DateTime petNow() {
    final now = ref.read(clockProvider).now();
    try {
      return tz.TZDateTime.from(
        now,
        tz.getLocation(ref.read(onboardingControllerProvider).draft.timezone),
      );
    } catch (_) {
      return now;
    }
  }

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  CareHomeState build() {
    ref.watch(onboardingControllerProvider.select((s) => s.petId));
    final onboarding = ref.read(onboardingControllerProvider);
    final draft = onboarding.draft;
    final petName = draft.petName.trim().isEmpty
        ? 'Paçoca'
        : draft.petName.trim();
    final tutorName = draft.tutorDisplayName.trim().isEmpty
        ? 'Tutor'
        : draft.tutorDisplayName.trim();

    _periodic.clear();
    _previousDates.clear();
    final now = petNow();
    for (final entry in draft.forgettableCare.entries) {
      if (!PeriodicCare.labels.containsKey(entry.key.code)) continue;
      _periodic[entry.key.code] = PeriodicCare(
        _date(draft.dueFor(entry.key, now)),
        '',
        draft.intervalFor(entry.key),
      );
    }
    _localFleaDue = null;
    final slots = _buildSlotsFromDraft(draft, petName);

    var initial = CareHomeState(
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
    _key = 'lumin.care.v1.${onboarding.petId ?? 'draft'}';
    _remoteReady = false;
    _day = _date(petNow());
    _bonusDates.clear();
    _completeDays.clear();
    _history.clear();
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in (j['periodic'] as Map? ?? {}).entries) {
          _periodic[e.key] = e.value == null
              ? null
              : PeriodicCare.fromJson(e.value);
        }
        _bonusDates.addAll(Map<String, String>.from(j['bonus_dates'] ?? {}));
        _previousDates.addAll(
          Map<String, String>.from(j['previous_dates'] ?? {}),
        );
        _history.addAll((j['history'] as Map?)?.cast<String, dynamic>() ?? {});
        if (j['day'] is String && j['slots'] is List) {
          _history[j['day']] = _summary(
            (j['slots'] as List).map((s) => CareSlotItem.fromJson(s)),
          );
        }
        _localFleaDue = DateTime.tryParse(j['flea_next_due'] as String? ?? '');
        _completeDays.addAll((j['days'] as List).cast<String>());
        initial = initial.copyWith(
          streakDays: _localStreak(),
          slots: j['day'] == _day
              ? (j['slots'] as List)
                    .map((s) => CareSlotItem.fromJson(s))
                    .toList()
              : _buildSlotsFromDraft(draft, petName),
          hasShownAccountLinkPrompt: j['prompted'] == true,
        );
      } catch (_) {
        initial = initial.copyWith(
          bannerMessage: 'Não foi possível recuperar os cuidados salvos.',
        );
      }
    }
    final timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    ref.onDispose(timer.cancel);
    final client = ref.read(supabaseClientProvider);
    if (client != null && onboarding.petId != null) {
      final channel = client.channel('care-${onboarding.petId}');
      for (final table in ['care_logs', 'care_tasks', 'pet_days']) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) => refresh(),
        );
      }
      channel.subscribe();
      ref.onDispose(() {
        client.removeChannel(channel);
      });
    }
    Future.microtask(refresh);
    return initial;
  }

  static const dailyXp = 20;

  DateTime? nextBonusDate(String mission, int interval) {
    final last = DateTime.tryParse(_bonusDates[mission] ?? '');
    return last == null
        ? null
        : DateTime(last.year, last.month, last.day + interval);
  }

  Future<void> completeBonus(String mission, int interval) async {
    if (_busy) return;
    final today = _date(petNow());
    final due = nextBonusDate(mission, interval);
    if (due != null && _date(due).compareTo(today) > 0) return;
    _busy = true;
    final previous = _bonusDates[mission];
    try {
      _bonusDates[mission] = today;
      await _persist(state);
      if (ref.mounted) state = state.copyWith();
    } catch (_) {
      if (previous == null) {
        _bonusDates.remove(mission);
      } else {
        _bonusDates[mission] = previous;
      }
      rethrow;
    } finally {
      _busy = false;
    }
  }

  int get missionXp {
    final past = _history.entries
        .where((entry) => entry.key != _day && entry.value['all_done'] == true)
        .length;
    final today = state.slots.isNotEmpty && state.slots.every((s) => s.isDone);
    return (past + (today ? 1 : 0)) * dailyXp;
  }

  String? registrationTime(CareSlotItem slot) {
    final at = slot.doneAt;
    if (!slot.isDone || at == null) return null;
    final now = petNow();
    final local = now is tz.TZDateTime
        ? tz.TZDateTime.from(at, now.location)
        : at.toLocal();
    final clock =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (slot.scheduledHour == null) return 'Registrado às $clock';
    final difference = local.hour * 60 + local.minute - slot.sortMinutes;
    final timing = difference == 0
        ? 'no horário'
        : '${difference.abs()} min ${difference > 0 ? "depois" : "antes"}';
    return 'Registrado às $clock · $timing';
  }

  int _localStreak() {
    var day = DateTime.parse(_day);
    if (!_completeDays.contains(_date(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var total = 0;
    while (_completeDays.contains(_date(day))) {
      total++;
      day = day.subtract(const Duration(days: 1));
    }
    return total;
  }

  Map<String, dynamic> _summary(Iterable<CareSlotItem> slots) {
    final food = slots.where((s) => s.kind == CareSlotKind.dailyFeed);
    final walks = slots.where((s) => s.kind == CareSlotKind.dailyWalk);
    return {
      'all_done': slots.isNotEmpty && slots.every((s) => s.isDone),
      'periodic': {
        for (final s in slots.where((s) => s.kind == CareSlotKind.interval))
          if (PeriodicCare.labels.containsKey(
            s.careType ?? s.id.replaceFirst('interval-', ''),
          ))
            (s.careType ?? s.id.replaceFirst('interval-', '')): s.isDone,
      },
      'food': food.where((s) => s.isDone).length,
      'meals': food.length,
      'walks': walks.where((s) => s.isDone).length,
      'outings': walks.length,
    };
  }

  Future<Map<String, dynamic>> monthHistory(DateTime month) async {
    final start = _date(DateTime(month.year, month.month));
    final end = _date(DateTime(month.year, month.month + 1));
    final result = <String, dynamic>{};
    for (final e in _history.entries) {
      if (e.key.compareTo(start) >= 0 && e.key.compareTo(end) < 0)
        result[e.key] = {...e.value as Map};
    }
    for (final day in _completeDays) {
      if (day.compareTo(start) >= 0 && day.compareTo(end) < 0)
        (result[day] ??= {})['complete'] = true;
    }
    final client = ref.read(supabaseClientProvider);
    final pet = ref.read(onboardingControllerProvider).petId;
    if (client != null && pet != null) {
      final logs = await client
          .from('care_logs')
          .select('slot_date,care_tasks(type)')
          .eq('pet_id', pet)
          .gte('slot_date', start)
          .lt('slot_date', end);
      final totals = <String, Map<String, int>>{};
      final completedCare = <String, Map<String, bool>>{};
      for (final log in logs) {
        final item = totals.putIfAbsent(
          log['slot_date'],
          () => {'food': 0, 'walks': 0},
        );
        final type = log['care_tasks']?['type'];
        if (PeriodicCare.labels.containsKey(type)) {
          (completedCare[log['slot_date']] ??= {})[type] = true;
        }
        if (type == 'feed') item['food'] = item['food']! + 1;
        if (type == 'walk') item['walks'] = item['walks']! + 1;
      }
      final days = await client
          .from('pet_days')
          .select('local_date,status')
          .eq('pet_id', pet)
          .gte('local_date', start)
          .lt('local_date', end);
      for (final key in {...result.keys, ...totals.keys}) {
        result[key] = {
          ...?result[key] as Map?,
          'complete': false,
          ...?totals[key],
          'periodic': {
            for (final k in (result[key]?['periodic'] as Map? ?? {}).keys)
              k: false,
            ...?completedCare[key],
          },
        };
        result[key]['food'] = totals[key]?['food'] ?? 0;
        result[key]['walks'] = totals[key]?['walks'] ?? 0;
      }
      for (final row in days) {
        (result[row['local_date']] ??= {})[row['status'] == 'complete'
                ? 'complete'
                : 'frozen'] =
            true;
      }
    }
    if (_day.compareTo(start) >= 0 && _day.compareTo(end) < 0)
      result[_day] = {
        ..._summary(state.slots),
        'complete': state.isDayComplete,
      };
    return result;
  }

  Future<void> _persist(CareHomeState next) async {
    final ok = await ref
        .read(sharedPreferencesProvider)
        .setString(
          _key,
          jsonEncode({
            'day': _day,
            'bonus_dates': _bonusDates,
            'days': _completeDays.toList(),
            'history': {..._history, _day: _summary(next.slots)},
            'periodic': _periodic.map((k, v) => MapEntry(k, v?.toJson())),
            'previous_dates': _previousDates,
            'flea_next_due': _localFleaDue?.toIso8601String(),
            'slots': next.slots.map((s) => s.toJson()).toList(),
            'prompted': next.hasShownAccountLinkPrompt,
          }),
        );
    if (!ok) throw StateError('Falha ao salvar cuidados');
    _history[_day] = _summary(next.slots);
  }

  Future<void> _applyNotificationActions(String petId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.reload();
    if (!ref.mounted) return;
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(CareNotificationAction.prefix(petId)))
        .toList();
    if (keys.isEmpty) return;
    final slots = [...state.slots];
    final historical = <String, Set<String>>{};
    final requiredByDay = <String, Set<String>>{};
    var lastCare = state.lastCareLoggedAt;
    for (final key in keys) {
      final record = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
      final day = record['day'] as String;
      if (day != _day) {
        historical.putIfAbsent(day, () => {}).addAll([
          ...List<String>.from(record['done']),
          record['slot'] as String,
        ]);
        requiredByDay[day] = Set<String>.from(record['required']);
        continue;
      }
      for (var i = 0; i < slots.length; i++) {
        final slot = slots[i];
        if (slot.kind == CareSlotKind.interval || slot.isDone) continue;
        final type = slot.kind == CareSlotKind.dailyFeed ? 'feed' : 'walk';
        if ('$type/${slot.timeLabel}' != record['slot']) continue;
        final at = DateTime.parse(record['at']);
        slots[i] = slot.copyWith(
          isDone: true,
          doneAt: at,
          doneByName: state.tutorName,
          logId: record['log'],
        );
        if (lastCare == null || at.isAfter(lastCare)) lastCare = at;
      }
    }
    for (final day in historical.keys) {
      if (historical[day]!.containsAll(requiredByDay[day]!)) {
        _completeDays.add(day);
      }
    }
    var next = state.copyWith(slots: slots, lastCareLoggedAt: lastCare);
    if (next.isDayComplete) _completeDays.add(_day);
    next = next.copyWith(streakDays: _localStreak());
    await _persist(next);
    if (!ref.mounted) return;
    state = next;
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<void> refresh() async {
    if (!ref.mounted || _busy || _refreshing) return;
    _refreshing = true;
    try {
      final today = _date(petNow());
      if (_day != today) {
        _day = today;
        _remoteReady = false;
        state = state.copyWith(
          slots: _buildSlotsFromDraft(
            ref.read(onboardingControllerProvider).draft,
            state.petName,
          ),
          streakDays: _localStreak(),
        );
      }
      final client = ref.read(supabaseClientProvider);
      final petId = ref.read(onboardingControllerProvider).petId;
      if (petId == null) return;
      if (client == null) {
        await _applyNotificationActions(petId);
        return;
      }
      final pet = await client.from('pets').select().eq('id', petId).single();
      final tasks = await client
          .from('care_tasks')
          .select()
          .eq('pet_id', petId)
          .eq('active', true);
      final logs = await client
          .from('care_logs')
          .select()
          .eq('pet_id', petId)
          .eq('slot_date', _day);
      final members = await client
          .from('household_members')
          .select()
          .eq('household_id', pet['household_id']);
      final streak = await client.rpc<int>(
        'pet_streak',
        params: {'p_pet': petId},
      );
      final slots = <CareSlotItem>[];
      final schedules = <String, PeriodicCare?>{};
      for (final task in tasks) {
        if (PeriodicCare.labels.containsKey(task['type'])) {
          schedules[task['type']] = PeriodicCare(
            task['next_due_date'],
            (task['scheduled_time'] as String?)?.substring(0, 5) ?? '',
            task['interval_days'],
          );
        }
        final interval = task['kind'] == 'interval';
        if (interval &&
            (task['next_due_date'] as String).compareTo(_day) > 0 &&
            !logs.any((l) => l['task_id'] == task['id'])) {
          continue;
        }
        final times = interval
            ? <String>[task['scheduled_time'] ?? '']
            : (task['daily_times'] as List).cast<String>();
        for (var i = 0; i < times.length; i++) {
          final log = logs
              .where((l) => l['task_id'] == task['id'] && l['slot_index'] == i)
              .firstOrNull;
          final actor = members
              .where((m) => m['user_id'] == log?['done_by'])
              .firstOrNull;
          final parts = times[i].split(':');
          slots.add(
            CareSlotItem(
              id: '${task['id']}-$i',
              taskId: task['id'],
              slotIndex: i,
              kind: interval
                  ? CareSlotKind.interval
                  : task['type'] == 'feed'
                  ? CareSlotKind.dailyFeed
                  : CareSlotKind.dailyWalk,
              title: task['label'],
              careType: task['type'],
              subtitle: interval
                  ? 'Cuidado periódico'
                  : times[i].substring(0, 5),
              emoji: interval
                  ? '💊'
                  : task['type'] == 'feed'
                  ? '🍖'
                  : '🦮',
              scheduledHour: int.tryParse(parts[0]),
              scheduledMinute: parts.length > 1 ? int.tryParse(parts[1]) : null,
              isDone: log != null,
              logId: log?['id'],
              doneByName: actor?['display_name'],
              doneAt: log == null ? null : DateTime.parse(log['occurred_at']),
            ),
          );
        }
      }
      if (!ref.mounted) return;
      slots.sort((a, b) => a.sortMinutes.compareTo(b.sortMinutes));
      _periodic
        ..clear()
        ..addAll(schedules);
      _remoteReady = true;
      final next = state.copyWith(
        petName: pet['name'],
        avatarDna: AvatarDna.fromJson(pet['avatar_dna']),
        petGender: pet['avatar_dna']['gender'] == null
            ? state.petGender
            : PetGender.fromCode(pet['avatar_dna']['gender']),
        slots: slots,
        streakDays: streak,
        householdMemberCount: members.length,
        isAccountLinked: client.auth.currentUser?.isAnonymous == false,
        clearBanner: true,
      );
      await _persist(next);
      if (ref.mounted) state = next;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          bannerMessage:
              'Não foi possível atualizar a família. Verifique a conexão.',
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  /// Registra um cuidado em 1 toque (otimista + idempotente).
  /// Retorna se deve exibir o bottom sheet de salvar conta e o `logId` criado.
  Future<({bool shouldPromptAccountLink, String? logId})> logCareSlot(
    String slotId, {
    String? customActorName,
  }) async {
    if (_busy || _refreshing) {
      return (shouldPromptAccountLink: false, logId: null);
    }
    final now = petNow();
    if (_date(now) != _day) {
      await refresh();
      return (shouldPromptAccountLink: false, logId: null);
    }
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

    final client = ref.read(supabaseClientProvider);
    if (client != null) {
      if (!_remoteReady) {
        await refresh();
        return (shouldPromptAccountLink: false, logId: null);
      }
      _busy = true;
      try {
        final result = await client.rpc(
          'log_care',
          params: {
            'p_log_id': logId,
            'p_task_id': target.taskId,
            'p_slot_index': target.slotIndex,
            'p_occurred_at': now.toUtc().toIso8601String(),
          },
        );
        if (!ref.mounted) return (shouldPromptAccountLink: false, logId: null);
        state = state.copyWith(lastCareLoggedAt: now);
        _busy = false;
        await refresh();
        if (result['status'] == 'already_done') {
          state = state.copyWith(
            bannerMessage: 'Outro tutor já registrou este cuidado 💛',
          );
          return (shouldPromptAccountLink: false, logId: null);
        }
        return (
          shouldPromptAccountLink: false,
          logId: result['log_id'] as String,
        );
      } catch (_) {
        if (ref.mounted) {
          state = state.copyWith(
            bannerMessage: 'Registro não confirmado. Reconecte e atualize antes de tentar novamente.',
          );
        }
        return (shouldPromptAccountLink: false, logId: null);
      } finally {
        _busy = false;
      }
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

    analytics.track('care_logged', {'type': target.kind.name, 'source': 'tap'});

    if (!wasCompleteBefore && isCompleteNow) {
      analytics.track('day_completed', {'streak': updatedStreak});
    }

    final shouldPromptAccountLink =
        !state.hasShownAccountLinkPrompt && !state.isAccountLinked;

    final saved = nextState.copyWith(
      streakDays: updatedStreak,
      hasShownAccountLinkPrompt:
          state.hasShownAccountLinkPrompt || shouldPromptAccountLink,
    );

    _busy = true;
    final previousDue = _localFleaDue;
    final code = target.id.replaceFirst('interval-', '');
    final prior = _periodic[code];
    if (prior != null) {
      _previousDates[code] = prior.date;
      final d = petNow();
      _periodic[code] = PeriodicCare(
        _date(DateTime(d.year, d.month, d.day + prior.days)),
        prior.time,
        prior.days,
      );
    }
    if (target.id == 'interval-flea_tick') {
      final days = ref
          .read(onboardingControllerProvider)
          .draft
          .fleaIntervalDays;
      final today = petNow();
      _localFleaDue = DateTime(today.year, today.month, today.day + days);
    }
    if (isCompleteNow) _completeDays.add(_day);
    try {
      await _persist(saved);
      if (ref.mounted) state = saved;
    } catch (_) {
      _localFleaDue = previousDue;
      if (prior != null) _periodic[code] = prior;
      if (!wasCompleteBefore) _completeDays.remove(_day);
      if (ref.mounted) {
        state = state.copyWith(
          bannerMessage: 'Não foi possível salvar o cuidado neste aparelho.',
        );
      }
      return (shouldPromptAccountLink: false, logId: null);
    } finally {
      _busy = false;
    }

    return (shouldPromptAccountLink: shouldPromptAccountLink, logId: logId);
  }

  /// Desfaz o último cuidado registrado (janela de toque acidental).
  Future<void> undoLastCare(String logId) async {
    if (_busy || _refreshing) return;
    final client = ref.read(supabaseClientProvider);
    if (client != null) {
      _busy = true;
      try {
        await client.rpc('undo_care', params: {'p_log_id': logId});
      } catch (_) {
        if (ref.mounted) {
          state = state.copyWith(
            bannerMessage: 'Não foi possível desfazer. Confira se o registro de hoje foi feito por você.',
          );
        }
        return;
      } finally {
        _busy = false;
      }
      await refresh();
      return;
    }
    final index = state.slots.indexWhere((s) => s.logId == logId);
    if (index == -1) return;

    final wasCompleteBefore = state.isDayComplete;
    final updatedSlots = List<CareSlotItem>.from(state.slots);
    updatedSlots[index] = updatedSlots[index].copyWith(clearCompletion: true);

    final nextState = state.copyWith(slots: updatedSlots, clearBanner: true);

    final updatedStreak = (wasCompleteBefore && !nextState.isDayComplete)
        ? (state.streakDays > 0 ? state.streakDays - 1 : 0)
        : state.streakDays;

    ref.read(analyticsProvider).track('care_undone', {'log_id': logId});

    final saved = nextState.copyWith(streakDays: updatedStreak);
    _busy = true;
    final previousDue = _localFleaDue;
    final code = updatedSlots[index].id.replaceFirst('interval-', '');
    final prior = _periodic[code];
    if (prior != null && _previousDates.containsKey(code)) {
      _periodic[code] = PeriodicCare(
        _previousDates[code]!,
        prior.time,
        prior.days,
      );
    }
    if (updatedSlots[index].id == 'interval-flea_tick') _localFleaDue = null;
    final wasComplete = !nextState.isDayComplete && _completeDays.remove(_day);
    try {
      await _persist(saved);
      if (ref.mounted) state = saved;
    } catch (_) {
      _localFleaDue = previousDue;
      if (prior != null) _periodic[code] = prior;
      if (wasComplete) _completeDays.add(_day);
    } finally {
      _busy = false;
    }
  }

  Future<void> renameTutor(String name) async {
    final profile = ref.read(onboardingControllerProvider);
    final client = ref.read(supabaseClientProvider);
    if (client != null) {
      final pet = await client
          .from('pets')
          .select('household_id')
          .eq('id', profile.petId!)
          .single();
      await client
          .from('household_members')
          .update({'display_name': name})
          .eq('household_id', pet['household_id'])
          .eq('user_id', client.auth.currentUser!.id)
          .select('user_id')
          .single();
    }
    await ref
        .read(onboardingControllerProvider.notifier)
        .savePetEdits(profile.draft.copyWith(tutorDisplayName: name));
    if (ref.mounted) state = state.copyWith(tutorName: name);
  }

  Future<void> editPet({
    String? name,
    AvatarDna? dna,
    List<String>? meals,
    List<String>? walks,
    Map<String, PeriodicCare?> changes = const {},
  }) async {
    if (_busy || _refreshing) {
      throw StateError('Aguarde a atualização dos cuidados e tente novamente.');
    }
    final onboarding = ref.read(onboardingControllerProvider);
    final draft = onboarding.draft.copyWith(
      petName: name ?? state.petName,
      avatarDna: dna ?? state.avatarDna,
      gender: state.petGender,
      feedPreset: meals == null ? null : FeedPreset.custom,
      customFeedTimes: meals,
      customWalkTimes: walks,
    );
    final client = ref.read(supabaseClientProvider);
    final editRoutine = meals != null && walks != null;
    final priorSchedules = Map.of(_periodic);
    final oldComplete = _completeDays.contains(_day);
    _busy = true;
    try {
      if (client != null) {
        if (!_remoteReady || onboarding.petId == null) {
          throw StateError('Reconecte para editar o pet.');
        }
        if (editRoutine) {
          await client.rpc(
            changes.isEmpty ? 'edit_pet_routine' : 'edit_pet_care_schedule',
            params: {
              'p_pet': onboarding.petId,
              'p_meals': meals,
              'p_walks': walks,
              if (changes.isNotEmpty)
                'p_changes': changes.map((k, v) => MapEntry(k, v?.toJson())),
            },
          );
        } else {
          await client
              .from('pets')
              .update({'name': name, 'avatar_dna': draft.sharedAvatar})
              .eq('id', onboarding.petId!)
              .select('id')
              .single();
        }
      }
      var next = state.copyWith(
        petName: draft.petName,
        avatarDna: draft.avatarDna,
      );
      if (client == null) {
        _periodic.addAll(changes);
        final updated = _buildSlotsFromDraft(draft, draft.petName);
        final old = state.slots;
        for (final slot in old.where(
          (s) => s.kind == CareSlotKind.interval && s.isDone,
        )) {
          if (!updated.any((s) => s.id == slot.id)) updated.add(slot);
        }
        final slots = updated.map((slot) {
          final previous = old
              .where(
                (s) =>
                    s.kind == slot.kind &&
                    (slot.kind == CareSlotKind.interval
                        ? s.id == slot.id
                        : s.timeLabel == slot.timeLabel),
              )
              .firstOrNull;
          if (previous == null || !previous.isDone) return slot;
          return slot.copyWith(
            isDone: true,
            logId: previous.logId,
            doneAt: previous.doneAt,
            doneByName: previous.doneByName,
          );
        }).toList();
        next = next.copyWith(slots: slots);
        if (next.isDayComplete) {
          _completeDays.add(_day);
        } else {
          _completeDays.remove(_day);
        }
        next = next.copyWith(streakDays: _localStreak());
      }
      await _persist(next);
      await ref.read(onboardingControllerProvider.notifier).savePetEdits(draft);
      if (ref.mounted) state = next;
    } catch (_) {
      _periodic
        ..clear()
        ..addAll(priorSchedules);
      if (oldComplete) {
        _completeDays.add(_day);
      } else {
        _completeDays.remove(_day);
      }
      rethrow;
    } finally {
      _busy = false;
    }
    if (client != null) await refresh();
  }

  Future<void> markAccountLinked(String provider) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      state = state.copyWith(
        bannerMessage:
            'Conta online indisponível. Os registros continuam neste aparelho.',
      );
      return;
    }
    try {
      await client.auth.linkIdentity(
        provider == 'Google' ? OAuthProvider.google : OAuthProvider.apple,
      );
      if (ref.mounted) {
        state = state.copyWith(
          bannerMessage: 'Conclua a autenticação para vincular sua conta.',
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          bannerMessage: 'Não foi possível iniciar a vinculação da conta.',
        );
      }
    }
  }

  List<CareSlotItem> _buildSlotsFromDraft(
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
      if (PeriodicCare.labels.containsKey(entry.key.code)) continue;
      final now = petNow();
      final due = entry.key == ForgettableCareType.fleaTick
          ? !(_localFleaDue ?? draft.fleaDue(now)).isAfter(
              DateTime(now.year, now.month, now.day),
            )
          : entry.value != LastDoneRecency.thisMonth;
      if (due) {
        result.add(
          CareSlotItem(
            id: 'interval-${entry.key.code}',
            taskId: 'task-${entry.key.code}',
            slotIndex: 0,
            kind: CareSlotKind.interval,
            title: '${entry.key.label} d${draft.gender.article} $petName',
            subtitle: 'Cuidado periódico pendente hoje',
            emoji: entry.key.emoji,
          ),
        );
      }
    }

    for (final entry in _periodic.entries) {
      final plan = entry.value;
      if (plan == null || plan.date.compareTo(_date(petNow())) > 0) continue;
      final parts = plan.time.split(':');
      result.add(
        CareSlotItem(
          id: 'interval-${entry.key}',
          taskId: 'task-${entry.key}',
          slotIndex: 0,
          kind: CareSlotKind.interval,
          title: PeriodicCare.labels[entry.key]!,
          subtitle: 'A cada ${plan.days} dias',
          emoji: entry.key == 'bath' ? '🛁' : '💊',
          scheduledHour: int.tryParse(parts.first),
          scheduledMinute: int.tryParse(parts.last),
        ),
      );
    }
    result.sort((a, b) => a.sortMinutes.compareTo(b.sortMinutes));
    return result;
  }
}

final careControllerProvider = NotifierProvider<CareController, CareHomeState>(
  CareController.new,
);
