import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_care_action.dart';
import '../onboarding/data/draft_local_store.dart';
import '../../core/providers/core_providers.dart';
import '../care/domain/care_slot.dart';
import '../care/domain/periodic_care.dart';
import '../care/presentation/care_controller.dart';
import '../life/domain/pet_life.dart';
import '../life/presentation/life_controller.dart';

class PetReminder {
  const PetReminder(this.when, this.body, [this.slot]);
  final CareSlotItem? slot;
  final DateTime when;
  final String body;
}

/// Planejamento puro: janela diurna, no máximo três avisos/dia e horizonte de 14 dias.
List<PetReminder> planReminders(
  DateTime now,
  CareHomeState care,
  LifeState life, {
  Map<String, PeriodicCare?> periodic = const {},
}) {
  final candidates = <PetReminder>[];
  DateTime dayAt(int offset, int hour, [int minute = 0]) {
    if (now is tz.TZDateTime) {
      return tz.TZDateTime(
        now.location,
        now.year,
        now.month,
        now.day + offset,
        hour,
        minute,
      );
    }
    return DateTime(now.year, now.month, now.day + offset, hour, minute);
  }

  for (final entry in periodic.entries) {
    final plan = entry.value;
    if (plan == null || plan.time.isEmpty) continue;
    final offset = calendarDay(DateTime.parse(plan.date))
        .difference(calendarDay(now))
        .inDays;
    final time = plan.time.split(':');
    candidates.add(
      PetReminder(
        dayAt(offset, int.parse(time.first), int.parse(time.last)),
        '${PeriodicCare.labels[entry.key]} de ${care.petName} às ${plan.time}.',
      ),
    );
  }

  for (var day = 0; day < 14; day++) {
    final morning = dayAt(day, 9);
    if (life.food != null &&
        !calendarDay(morning).isBefore(life.food!.reminderDay)) {
      candidates.add(
        PetReminder(
          morning,
          'A ração de ${care.petName} tem cerca de '
          '${life.food!.remainingMeals(morning)} refeições restantes. Planeje a reposição.',
        ),
      );
    }
    for (final r in life.records.where((r) => r.due(morning))) {
      candidates.add(
        PetReminder(
          morning,
          '${care.petName} precisa de sua atenção: '
          '${r.kind == HealthKind.vet ? 'retorno veterinário' : 'medicamento registrado'} • ${r.title}.',
        ),
      );
    }
    for (final slot in care.slots) {
      if (day == 0 && slot.isDone) continue;
      if (slot.kind == CareSlotKind.interval) {
        continue; // Datas explícitas ficam no histórico.
      }
      var when = dayAt(
        day,
        slot.scheduledHour ?? 8,
        (slot.scheduledMinute ?? 0) + 30,
      );
      if (when.day != dayAt(day, 0).day) continue;
      if (when.hour < 7) when = dayAt(day, 7);
      if (when.hour >= 22) continue;
      candidates.add(
        PetReminder(
          when,
          '${care.petName} precisa de sua atenção 🥺 '
          '${slot.kind == CareSlotKind.dailyFeed ? 'Refeição' : 'Passeio'} das ${slot.timeLabel}: já foi feito?',
          slot,
        ),
      );
    }
  }
  // Datas futuras explícitas são agendadas mesmo fora da janela da rotina.
  DateTime morningOn(DateTime d) => now is tz.TZDateTime
      ? tz.TZDateTime(now.location, d.year, d.month, d.day, 9)
      : DateTime(d.year, d.month, d.day, 9);
  final horizon = calendarDay(now).add(const Duration(days: 14));
  final food = life.food;
  if (food != null && !food.reminderDay.isBefore(horizon)) {
    final when = morningOn(food.reminderDay);
    candidates.add(
      PetReminder(
        when,
        'A ração de ${care.petName} tem cerca de '
        '${food.remainingMeals(when)} refeições restantes. Planeje a reposição.',
      ),
    );
  }
  for (final record in life.records) {
    if (!record.followUpDone &&
        record.nextDate != null &&
        !calendarDay(record.nextDate!).isBefore(horizon)) {
      candidates.add(
        PetReminder(
          morningOn(record.nextDate!),
          '${care.petName} precisa de sua atenção: ${record.title}. Confira a próxima data registrada.',
        ),
      );
    }
  }
  candidates.removeWhere((r) => !r.when.isAfter(now));
  candidates.sort((a, b) {
    final dayCompare = shortDate(a.when).compareTo(shortDate(b.when));
    if (dayCompare != 0) return dayCompare;
    final priorityA = a.slot == null ? 0 : 1;
    final priorityB = b.slot == null ? 0 : 1;
    if (priorityA != priorityB) return priorityA.compareTo(priorityB);
    return a.when.compareTo(b.when);
  });
  final counts = <String, int>{};
  final selected = candidates.where((r) {
    final key = shortDate(r.when);
    counts[key] = (counts[key] ?? 0) + 1;
    return counts[key]! <= 3;
  }).toList();
  selected.sort((a, b) => a.when.compareTo(b.when));
  return selected;
}

class LocalReminders {
  LocalReminders(this.prefs);
  final SharedPreferences prefs;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void> _pending = Future.value();
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get enabled => prefs.getBool('lumin.reminders.enabled') ?? false;
  Future<void> initialize() async {
    if (!supported || _initialized) return;
    await _plugin.initialize(
      onDidReceiveBackgroundNotificationResponse: onCareNotificationAction,
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
    _initialized = true;
  }

  Future<bool> enable(Uint8List avatar) async {
    if (!supported) return false;
    await initialize();
    final granted =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()!
            .requestNotificationsPermission() ??
        false;
    if (!granted) return false;
    await prefs.setString('lumin.reminders.avatar', base64Encode(avatar));
    await prefs.setBool('lumin.reminders.enabled', true);
    await prefs.remove('lumin.reminders.plan');
    return true;
  }

  Future<void> updateAvatar(Uint8List avatar) async {
    if (!supported || !enabled) return;
    await prefs.setString('lumin.reminders.avatar', base64Encode(avatar));
    await prefs.remove('lumin.reminders.plan');
  }

  Future<void> disable() async {
    await prefs.setBool('lumin.reminders.enabled', false);
    await prefs.remove('lumin.reminders.plan');
    await _pending;
    if (supported) {
      await initialize();
      await _plugin.cancelAll();
    }
  }

  Future<void> reschedule(
    DateTime now,
    CareHomeState care,
    LifeState life,
    String timezone, {
    Map<String, PeriodicCare?> periodic = const {},
  }) {
    final operation = _pending.then((_) async {
      if (!supported || !enabled) return;
      await initialize();
      final raw = prefs.getString('lumin.reminders.avatar');
      final bitmap = raw == null
          ? null
          : ByteArrayAndroidBitmap(base64Decode(raw));
      final location = tz.getLocation(timezone);
      final localNow = tz.TZDateTime.from(now, location);
      final petId = DraftLocalStore(prefs).loadCompletedPetId();
      final signature = jsonEncode({
        'actionVersion': 1,
        'periodic': periodic.map((k, v) => MapEntry(k, v?.toJson())),
        'petId': petId,
        'day': shortDate(localNow),
        'zone': timezone,
        'pet': care.petName,
        'slots': care.slots.map((s) => s.toJson()).toList(),
        'food': life.food?.toJson(),
        'health': life.records.map((r) => r.toJson()).toList(),
      });
      if (prefs.getString('lumin.reminders.plan') == signature) return;
      final reminders = planReminders(
        tz.TZDateTime.from(now, location),
        care,
        life,
        periodic: periodic,
      );
      await _plugin.cancelAll();
      await prefs.remove('lumin.reminders.plan');
      for (var i = 0; i < reminders.length; i++) {
        final r = reminders[i];
        final slot = r.slot;
        final action = slot == null || petId == null
            ? null
            : CareNotificationAction(
                petId: petId,
                task: slot.taskId,
                index: slot.slotIndex,
                feed: slot.kind == CareSlotKind.dailyFeed,
                time: slot.timeLabel,
                day: careDate(r.when),
                zone: timezone,
              );
        await _plugin.zonedSchedule(
          id: action == null
              ? 1000 + i
              : 10000 + (int.parse(action.logId.substring(0, 7), radix: 16)),
          title: '${care.petName} precisa de sua atenção',
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.when, location),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'pet_care',
              'Cuidados do pet',
              channelDescription: 'Rotina, ração e saúde do seu pet',
              actions: action == null ? null : [action.button],
              largeIcon: bitmap,
              styleInformation: bitmap == null
                  ? null
                  : BigPictureStyleInformation(
                      bitmap,
                      contentTitle: '${care.petName} precisa de sua atenção',
                      summaryText: r.body,
                    ),
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: action?.encode() ?? 'pet-life',
        );
      }
      await prefs.setString('lumin.reminders.plan', signature);
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }
}

final localRemindersProvider = Provider<LocalReminders>(
  (ref) => LocalReminders(ref.watch(sharedPreferencesProvider)),
);
