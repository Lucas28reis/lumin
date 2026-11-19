import 'avatar_mood.dart';

/// Função pura de domínio que resolve o humor do Avatar (Seção 3.2 da SPEC_MVP.md).
/// Ordem estrita de prioridade:
/// 1. `celebrating`: registro feito nos últimos 5 segundos
/// 2. `hungry`: horário de alimentação atrasado > 30 min
/// 3. `worried`: tarefa de intervalo vencida (hoje ou antes)
/// 4. `bored`: passeio atrasado > 60 min
/// 5. `sleepy`: entre 22h e 06h no fuso do pet, sem pendências
/// 6. `happy`: padrão
abstract final class MoodResolver {
  static AvatarMood resolve({
    required DateTime now,
    DateTime? lastCareLoggedAt,
    required List<({int hour, int minute, bool isDone})> todayFeedSlots,
    required List<({int hour, int minute, bool isDone})> todayWalkSlots,
    required bool hasOverdueIntervalTask,
  }) {
    if (lastCareLoggedAt != null) {
      final elapsed = now.difference(lastCareLoggedAt);
      if (!elapsed.isNegative && elapsed < const Duration(seconds: 5)) {
        return AvatarMood.celebrating;
      }
    }

    for (final slot in todayFeedSlots) {
      if (slot.isDone) continue;
      final scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        slot.hour,
        slot.minute,
      );
      if (now.difference(scheduled) > const Duration(minutes: 30)) {
        return AvatarMood.hungry;
      }
    }

    if (hasOverdueIntervalTask) {
      return AvatarMood.worried;
    }

    for (final slot in todayWalkSlots) {
      if (slot.isDone) continue;
      final scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        slot.hour,
        slot.minute,
      );
      if (now.difference(scheduled) > const Duration(minutes: 60)) {
        return AvatarMood.bored;
      }
    }

    if (now.hour >= 22 || now.hour < 6) {
      return AvatarMood.sleepy;
    }

    return AvatarMood.happy;
  }
}
