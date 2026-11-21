import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lumin_app/core/providers/core_providers.dart';
import 'package:lumin_app/core/clock/clock.dart';
import 'package:lumin_app/features/life/domain/pet_life.dart';
import 'package:lumin_app/features/life/presentation/life_controller.dart';
import 'package:lumin_app/features/care/presentation/care_controller.dart';
import 'package:lumin_app/features/notifications/local_reminders.dart';
import 'package:lumin_app/features/notifications/notification_care_action.dart';

void main() {
  test(
    'Ação Android registra uma refeição uma vez e ignora o aviso de ontem',
    () async {
      final now = DateTime(2026, 11, 21, 12);
      SharedPreferences.setMockInitialValues({
        'lumin.onboarding.pet_id': 'pet-test',
      });
      final prefs = await SharedPreferences.getInstance();
      const action = CareNotificationAction(
        petId: 'pet-test',
        task: 'task-feed',
        index: 0,
        feed: true,
        time: '08:00',
        day: '2026-11-21',
        zone: 'America/Sao_Paulo',
      );
      expect(action.button.showsUserInterface, isFalse);
      await action.recordLocal(prefs, now.add(const Duration(days: 1)));
      expect(
        prefs.getKeys().where(
          (k) => k.startsWith(CareNotificationAction.prefix('pet-test')),
        ),
        isEmpty,
      );
      await action.recordLocal(prefs, now);
      await CareNotificationAction.decode(action.encode())
          .recordLocal(prefs, now);
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(FixedClock(now)),
        ],
      );
      addTearDown(c.dispose);
      c.read(careControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final completed = c
          .read(careControllerProvider)
          .slots
          .where((s) => s.isDone);
      expect(completed.single.logId, action.logId);
      expect(completed.single.timeLabel, '08:00');
      await c.read(careControllerProvider.notifier).undoLastCare(action.logId);
      await c.read(careControllerProvider.notifier).refresh();
      expect(
        c.read(careControllerProvider).slots.any((s) => s.isDone),
        isFalse,
      );
    },
  );

  test('20kg, 200g duas vezes ao dia: após 35 dias restam 30 refeições', () {
    final opened = DateTime(2026, 10, 15);
    final food = FoodPlan(
      kilograms: 20,
      gramsPerMeal: 200,
      mealsPerDay: 2,
      openedOn: opened,
    );
    final now = DateTime(2026, 11, 19);
    expect(food.remainingGrams(now), 6000);
    expect(food.remainingMeals(now), 30);
    expect(food.remainingDays(now), 15);
    expect(food.reminderDay, DateTime.utc(2026, 11, 19));
    expect(food.remainingGrams(opened.add(const Duration(days: 60))), 0);
    expect(
      food.remainingGrams(opened.subtract(const Duration(days: 2))),
      20000,
    );
    expect(
      () => FoodPlan(
        kilograms: double.nan,
        gramsPerMeal: 200,
        mealsPerDay: 2,
        openedOn: opened,
      ),
      throwsArgumentError,
    );
    expect(
      () => FoodPlan(
        kilograms: 20,
        gramsPerMeal: 0,
        mealsPerDay: 2,
        openedOn: opened,
      ),
      throwsArgumentError,
    );
  });

  test('Histórico e estoque sobrevivem à recriação; retorno preserva o registro anterior', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer container() => ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    var c = container();
    final controller = c.read(lifeControllerProvider.notifier);
    final first = HealthRecord(
      id: '1',
      kind: HealthKind.vet,
      title: 'Consulta',
      date: DateTime(2026, 10, 1),
      notes: 'Vacina registrada pelo tutor',
      nextDate: DateTime(2026, 11, 19),
    );
    await controller.saveRecord(first);
    await controller.saveFood(
      FoodPlan(
        kilograms: 20,
        gramsPerMeal: 200,
        mealsPerDay: 2,
        openedOn: DateTime(2026, 10, 15),
      ),
    );
    c.dispose();
    c = container();
    expect(
      c
          .read(lifeControllerProvider)
          .food!
          .remainingMeals(DateTime(2026, 11, 19)),
      30,
    );
    expect(
      c.read(lifeControllerProvider).records.single.due(DateTime(2026, 11, 19)),
      true,
    );
    await c
        .read(lifeControllerProvider.notifier)
        .saveRecord(
          HealthRecord(
            id: '2',
            kind: HealthKind.vet,
            title: 'Retorno',
            date: DateTime(2026, 11, 19),
            notes: 'Reavaliação',
          ),
          closesId: '1',
        );
    final records = c.read(lifeControllerProvider).records;
    expect(records.length, 2);
    expect(records.first.followUpDone, true);
    expect(records.first.due(DateTime(2026, 11, 20)), false);
    expect(
      healthReport('Paçoca', records),
      contains('Vacina registrada pelo tutor'),
    );
    c.dispose();
  });

  test('Cuidados locais sobrevivem à reabertura e viram o dia sem repetir conclusões', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final clock = FixedClock(DateTime(2026, 11, 19, 12));
    ProviderContainer container() => ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(clock),
      ],
    );
    var c = container();
    c.read(careControllerProvider);
    await Future<void>.delayed(Duration.zero);
    final id = c.read(careControllerProvider).slots.first.id;
    final result = await c
        .read(careControllerProvider.notifier)
        .logCareSlot(id);
    expect(result.logId, isNotNull);
    c.dispose();
    c = container();
    expect(c.read(careControllerProvider).slots.first.isDone, true);
    await Future<void>.delayed(Duration.zero);
    final controller = c.read(careControllerProvider.notifier);
    final meal = c
        .read(careControllerProvider)
        .slots
        .firstWhere((s) => s.id.startsWith('feed'));
    final mealLog = await controller.logCareSlot(meal.id);
    await controller.editPet(
      meals: ['06:00', meal.timeLabel],
      walks: ['16:15'],
    );
    expect(
      c
          .read(careControllerProvider)
          .slots
          .singleWhere((s) => s.timeLabel == meal.timeLabel)
          .logId,
      mealLog.logId,
    );
    await controller.undoLastCare(mealLog.logId!);
    c.dispose();
    c = container();
    expect(
      c
          .read(careControllerProvider)
          .slots
          .singleWhere((s) => s.timeLabel == meal.timeLabel)
          .isDone,
      false,
    );
    expect(
      c.read(careControllerProvider).slots.any((s) => s.timeLabel == '16:15'),
      true,
    );
    await Future<void>.delayed(Duration.zero);
    clock.advance(const Duration(days: 1));
    await c.read(careControllerProvider.notifier).refresh();
    expect(c.read(careControllerProvider).slots.first.isDone, false);
    c.dispose();
  });

  test(
    'Lembretes respeitam silêncio, limite diário e cuidados já feitos',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      final care = c.read(careControllerProvider);
      final now = DateTime(2026, 11, 19, 6);
      final done = care.copyWith(
        slots: care.slots.map((s) => s.copyWith(isDone: true)).toList(),
      );
      final reminders = planReminders(now, done, const LifeState());
      expect(reminders.where((r) => r.when.day == now.day), isEmpty);
      final counts = <String, int>{};
      for (final r in reminders) {
        expect(r.when.hour, inInclusiveRange(7, 21));
        final day = shortDate(r.when);
        counts[day] = (counts[day] ?? 0) + 1;
      }
      expect(counts.values.every((n) => n <= 3), true);
      final food = FoodPlan(
        kilograms: 20,
        gramsPerMeal: 200,
        mealsPerDay: 2,
        openedOn: now,
      );
      final future = planReminders(now, done, LifeState(food: food));
      final expectedDay = now.add(const Duration(days: 35));
      expect(
        future.any(
          (r) =>
              shortDate(r.when) == shortDate(expectedDay) &&
              r.body.contains('30 refeições'),
        ),
        true,
      );
      c.dispose();
    },
  );
}
