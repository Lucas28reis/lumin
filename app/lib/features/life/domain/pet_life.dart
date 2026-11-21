import 'dart:math' as math;

DateTime calendarDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

/// Projeção de consumo, não uma medição do peso real do estoque.
class FoodPlan {
  FoodPlan({
    required this.kilograms,
    required this.gramsPerMeal,
    required this.mealsPerDay,
    required this.openedOn,
    this.alertDays = 15,
  }) {
    if (!kilograms.isFinite ||
        kilograms <= 0 ||
        !gramsPerMeal.isFinite ||
        gramsPerMeal <= 0 ||
        mealsPerDay < 1 ||
        mealsPerDay > 12 ||
        alertDays < 0) {
      throw ArgumentError('Informe quantidade, porção e frequência válidas.');
    }
  }
  final double kilograms;
  final double gramsPerMeal;
  final int mealsPerDay;
  final DateTime openedOn;
  final int alertDays;
  double get dailyGrams => gramsPerMeal * mealsPerDay;
  double remainingGrams(DateTime now) {
    final days = math.max(
      0,
      calendarDay(now).difference(calendarDay(openedOn)).inDays,
    );
    return math.max(0, kilograms * 1000 - days * dailyGrams);
  }

  int remainingMeals(DateTime now) =>
      (remainingGrams(now) / gramsPerMeal).floor();
  double remainingDays(DateTime now) => remainingGrams(now) / dailyGrams;
  DateTime get reminderDay => calendarDay(openedOn).add(
    Duration(
      days: math.max(0, (kilograms * 1000 / dailyGrams - alertDays).ceil()),
    ),
  );
  Map<String, dynamic> toJson() => {
    'kg': kilograms,
    'grams': gramsPerMeal,
    'meals': mealsPerDay,
    'opened': openedOn.toIso8601String(),
    'alert_days': alertDays,
  };
  factory FoodPlan.fromJson(Map<String, dynamic> j) => FoodPlan(
    kilograms: (j['kg'] as num).toDouble(),
    gramsPerMeal: (j['grams'] as num).toDouble(),
    mealsPerDay: j['meals'] as int,
    openedOn: DateTime.parse(j['opened'] as String),
    alertDays: j['alert_days'] as int? ?? 15,
  );
}

enum HealthKind { vet, medication }

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.date,
    required this.notes,
    this.nextDate,
    this.followUpDone = false,
  });
  final String id;
  final HealthKind kind;
  final String title;
  final DateTime date;
  final String notes;
  final DateTime? nextDate;
  final bool followUpDone;
  bool due(DateTime now) =>
      !followUpDone &&
      nextDate != null &&
      !calendarDay(nextDate!).isAfter(calendarDay(now));
  HealthRecord closeFollowUp() => HealthRecord(
    id: id,
    kind: kind,
    title: title,
    date: date,
    notes: notes,
    nextDate: nextDate,
    followUpDone: true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'date': date.toIso8601String(),
    'notes': notes,
    'next_date': nextDate?.toIso8601String(),
    'follow_up_done': followUpDone,
  };
  factory HealthRecord.fromJson(Map<String, dynamic> j) => HealthRecord(
    id: j['id'] as String,
    kind: HealthKind.values.byName(j['kind'] as String),
    title: j['title'] as String,
    date: DateTime.parse(j['date'] as String),
    notes: j['notes'] as String,
    nextDate: j['next_date'] == null
        ? null
        : DateTime.parse(j['next_date'] as String),
    followUpDone: j['follow_up_done'] == true,
  );
}

String shortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

String healthReport(String petName, List<HealthRecord> records) {
  final sorted = [...records]..sort((a, b) => b.date.compareTo(a.date));
  return 'Lumin • Histórico de $petName\nInformações registradas pelo tutor.\n\n'
      '${sorted.map((r) => '${shortDate(r.date)} • ${r.kind == HealthKind.vet ? 'Consulta' : 'Medicamento'}: ${r.title}\n'
          '${r.notes}\n${r.nextDate == null ? 'Sem retorno informado' : 'Próxima data: ${shortDate(r.nextDate!)}${r.followUpDone ? ' (realizado)' : ''}'}').join('\n\n')}';
}
