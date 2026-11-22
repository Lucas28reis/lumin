import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../core/env/env.dart';
import '../onboarding/data/draft_local_store.dart';

String careDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class CareNotificationAction {
  const CareNotificationAction({
    required this.petId,
    required this.task,
    required this.index,
    required this.feed,
    required this.time,
    required this.day,
    required this.zone,
  });
  final String petId, task, time, day, zone;
  final int index;
  final bool feed;

  AndroidNotificationAction get button => AndroidNotificationAction(
    'complete-care',
    feed ? 'Já alimentei' : 'Já passeamos',
    showsUserInterface: false,
    cancelNotification: false,
  );

  String encode() => jsonEncode({
    'pet': petId,
    'task': task,
    'index': index,
    'feed': feed,
    'time': time,
    'day': day,
    'zone': zone,
  });
  factory CareNotificationAction.decode(String payload) {
    final j = jsonDecode(payload);
    return CareNotificationAction(
      petId: j['pet'],
      task: j['task'],
      index: j['index'],
      feed: j['feed'],
      time: j['time'],
      day: j['day'],
      zone: j['zone'],
    );
  }

  String get logId => const Uuid().v5(Namespace.url.value, encode());
  static String prefix(String pet) => 'lumin.notification.done.$pet.';

  Future<void> recordLocal(SharedPreferences prefs, DateTime now) async {
    final store = DraftLocalStore(prefs);
    final draft = store.loadDraft();
    final times = feed ? draft.activeFeedTimes : draft.activeWalkTimes;
    if (store.loadCompletedPetId() != petId ||
        careDate(now) != day ||
        index < 0 ||
        index >= times.length ||
        times[index] != time ||
        task != (feed ? 'task-feed' : 'task-walk')) {
      return;
    }
    final requiredSlots = [
      for (final t in draft.activeFeedTimes) 'feed/$t',
      for (final t in draft.activeWalkTimes) 'walk/$t',
    ];
    final saved = prefs.getString('lumin.care.v1.$petId');
    final snapshot = saved == null ? null : jsonDecode(saved);
    final completed = <String>{};
    if (snapshot?['day'] == day) {
      for (final s in snapshot['slots']) {
        if (s['done'] != true || s['hour'] == null) continue;
        final kind = s['kind'] == 'dailyFeed' ? 'feed' : 'walk';
        final hour = s['hour'].toString().padLeft(2, '0');
        final minute = s['minute'].toString().padLeft(2, '0');
        completed.add('$kind/$hour:$minute');
      }
    }
    final key = '${prefix(petId)}$logId';
    if (prefs.containsKey(key)) return;
    final ok = await prefs.setString(
      key,
      jsonEncode({
        'day': day,
        'slot': "${feed ? 'feed' : 'walk'}/$time",
        'at': now.toUtc().toIso8601String(),
        'log': logId,
        'required': requiredSlots,
        'done': completed.toList(),
      }),
    );
    if (!ok) throw StateError('Falha ao registrar cuidado');
  }
}

Future<Supabase>? _backgroundClient;

@pragma('vm:entry-point')
void onCareNotificationAction(NotificationResponse response) async {
  if (response.actionId != 'complete-care' || response.payload == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  final plugin = FlutterLocalNotificationsPlugin();
  final action = CareNotificationAction.decode(response.payload!);
  try {
    tzdata.initializeTimeZones();
    final now = tz.TZDateTime.now(tz.getLocation(action.zone));
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (careDate(now) == action.day &&
        DraftLocalStore(prefs).loadCompletedPetId() == action.petId &&
        prefs.getBool('lumin.reminders.enabled') == true) {
      if (Env.hasSupabase) {
        final instance = await (_backgroundClient ??= Supabase.initialize(
          url: Env.supabaseUrl,
          publishableKey: Env.supabaseAnonKey,
        ));
        final client = instance.client;
        final task = await client
            .from('care_tasks')
            .select('daily_times')
            .eq('pet_id', action.petId)
            .eq('id', action.task)
            .eq('active', true)
            .maybeSingle();
        final times = task?['daily_times'] as List?;
        if (times != null &&
            action.index >= 0 &&
            action.index < times.length &&
            times[action.index].toString().startsWith(action.time)) {
          await client.rpc(
            'log_care',
            params: {
              'p_log_id': action.logId,
              'p_task_id': action.task,
              'p_slot_index': action.index,
              'p_occurred_at': now.toUtc().toIso8601String(),
            },
          );
        }
      } else {
        await action.recordLocal(prefs, now);
      }
    }
    if (response.id != null) await plugin.cancel(id: response.id!);
  } catch (_) {
    if (response.id == null) return;
    await plugin.show(
      id: response.id!,
      title: 'Registro não confirmado',
      body: 'Toque para tentar novamente.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'pet_care',
          'Cuidados do pet',
          icon: 'ic_notification',
          onlyAlertOnce: true,
          actions: [action.button],
        ),
      ),
      payload: response.payload,
    );
  }
}
