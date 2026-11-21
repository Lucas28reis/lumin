import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../domain/pet_life.dart';

class LifeState {
  const LifeState({this.food, this.records = const [], this.error});
  final FoodPlan? food;
  final List<HealthRecord> records;
  final String? error;
}

class LifeController extends Notifier<LifeState> {
  late String _key;
  Future<void> _writes = Future.value();
  @override
  LifeState build() {
    final pet = ref.watch(onboardingControllerProvider.select((s) => s.petId));
    _key = 'lumin.life.v1.${pet ?? 'draft'}';
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const LifeState();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return LifeState(
        food: j['food'] == null ? null : FoodPlan.fromJson(j['food']),
        records: (j['records'] as List)
            .map((r) => HealthRecord.fromJson(r))
            .toList(),
      );
    } catch (_) {
      return const LifeState(
        error: 'Não foi possível ler o histórico salvo. Os dados foram preservados.',
      );
    }
  }

  Future<void> _save(LifeState Function(LifeState) change) {
    final prefs = ref.read(sharedPreferencesProvider);
    final key = _key;
    final operation = _writes.then((_) async {
      if (state.error != null) throw StateError(state.error!);
      final next = change(state);
      final ok = await prefs.setString(
        key,
        jsonEncode({
          'food': next.food?.toJson(),
          'records': next.records.map((r) => r.toJson()).toList(),
        }),
      );
      if (!ok) throw StateError('Não foi possível salvar neste aparelho.');
      state = next;
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> saveFood(FoodPlan food) =>
      _save((s) => LifeState(food: food, records: s.records));
  Future<void> saveRecord(HealthRecord record, {String? closesId}) => _save(
    (s) => LifeState(
      food: s.food,
      records: [
        ...s.records
            .where((r) => r.id != record.id)
            .map((r) => r.id == closesId ? r.closeFollowUp() : r),
        record,
      ],
    ),
  );
  Future<void> deleteRecord(String id) => _save(
    (s) => LifeState(
      food: s.food,
      records: s.records.where((r) => r.id != id).toList(),
    ),
  );
}

final lifeControllerProvider = NotifierProvider<LifeController, LifeState>(
  LifeController.new,
);
