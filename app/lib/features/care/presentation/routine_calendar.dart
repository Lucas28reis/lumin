import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'care_controller.dart';
import '../domain/periodic_care.dart';

class RoutineCalendar extends ConsumerStatefulWidget {
  const RoutineCalendar({super.key, this.changes = const {}});
  final Map<String, PeriodicCare?> changes;
  @override
  ConsumerState<RoutineCalendar> createState() => _CalendarState();
}

class _CalendarState extends ConsumerState<RoutineCalendar> {
  late DateTime selected;
  late Future<Map<String, dynamic>> data;
  static const months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  DateTime get today => ref.read(careControllerProvider.notifier).petNow();
  @override
  void initState() {
    super.initState();
    selected = today;
    load();
  }

  void load() {
    data = ref.read(careControllerProvider.notifier).monthHistory(selected);
  }

  void move(int n) => setState(() {
    selected = DateTime(selected.year, selected.month + n);
    load();
  });
  String keyFor(int d) => DateTime(
    selected.year,
    selected.month,
    d,
  ).toIso8601String().split('T').first;
  @override
  Widget build(BuildContext context) {
    ref.listen(careControllerProvider, (_, _) => setState(load));
    final plans = {
      ...ref.read(careControllerProvider.notifier).periodic,
      ...widget.changes,
    };
    final now = today;
    final todayKey = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).toIso8601String().split('T').first;
    const icons = {
      'medication': Icons.medication_outlined,
      'bath': Icons.bathtub_outlined,
      'deworm': Icons.shield_outlined,
    };
    Map<String, String> events(int day, dynamic info) {
      final key = keyFor(day);
      final entries = <String, String>{};
      for (final type in PeriodicCare.labels.keys) {
        final recorded = info?['periodic']?[type];
        final plan = plans[type];
        final date = DateTime.utc(selected.year, selected.month, day);
        final elapsed = plan == null
            ? -1
            : date.difference(DateTime.parse('${plan.date}T00:00:00Z')).inDays;
        final forecast =
            plan != null &&
            elapsed >= 0 &&
            elapsed % plan.days == 0 &&
            (key.compareTo(todayKey) >= 0 || key == plan.date);
        if (recorded == true) {
          entries[type] = 'Realizado';
        } else if (forecast || recorded == false) {
          final time = forecast && plan.time.isNotEmpty
              ? ' · ${plan.time}'
              : '';
          entries[type] = key.compareTo(todayKey) > 0
              ? 'Previsto$time'
              : 'Sem registro de conclusão$time';
        }
      }
      return entries;
    }

    final first = DateTime(selected.year, selected.month);
    final count = DateTime(selected.year, selected.month + 1, 0).day;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${months[selected.month - 1]} ${selected.year}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: () => move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Próximo mês',
                  onPressed: () => move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: data,
              builder: (context, snap) {
                if (snap.hasError)
                  return TextButton(
                    onPressed: () => setState(load),
                    child: const Text('Tentar carregar o histórico novamente'),
                  );
                if (snap.connectionState != ConnectionState.done)
                  return const LinearProgressIndicator();
                final days = snap.data!;
                final info = days[keyFor(selected.day)];
                final cells = <Widget>[
                  for (final d in ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'])
                    Center(child: Text(d)),
                  for (var i = 1; i < first.weekday; i++) const SizedBox(),
                  for (var d = 1; d <= count; d++)
                    Builder(
                      builder: (context) {
                        final entry = days[keyFor(d)];
                        final complete = entry?['complete'] == true;
                        final partial =
                            (entry?['food'] ?? 0) > 0 ||
                            (entry?['walks'] ?? 0) > 0;
                        final marks = events(d, entry);
                        return Semantics(
                          selected: selected.day == d,
                          label:
                              'Dia $d${complete ? ", ofensiva" : ""} ${marks.keys.map((k) => PeriodicCare.labels[k]).join(", ")}',
                          child: TextButton(
                            onPressed: () => setState(
                              () => selected = DateTime(
                                first.year,
                                first.month,
                                d,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: complete
                                  ? const Color(0xffffc477)
                                  : partial
                                  ? const Color(0xffccede7)
                                  : null,
                              side: selected.day == d
                                  ? const BorderSide(
                                      color: Color(0xff136e6a),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$d'),
                                if (marks.isNotEmpty)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (final k in marks.keys)
                                          Icon(
                                            icons[k],
                                            size: 13,
                                            color: const Color(0xff126c69),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 7,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 3,
                      mainAxisExtent:
                          48 *
                          MediaQuery.textScalerOf(context).scale(1).clamp(1, 3),
                      children: cells,
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        for (final k in PeriodicCare.labels.keys)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icons[k],
                                size: 16,
                                color: const Color(0xff126c69),
                              ),
                              const SizedBox(width: 4),
                              Text(PeriodicCare.labels[k]!),
                            ],
                          ),
                      ],
                    ),
                    const Divider(),
                    Text(
                      'Dia ${selected.day} · ${info?["complete"] == true
                          ? "Ofensiva conquistada"
                          : info?["frozen"] == true
                          ? "Ofensiva protegida"
                          : info == null
                          ? (keyFor(selected.day).compareTo(todayKey) > 0 ? "Previsão" : "Sem histórico")
                          : "Cuidados do dia"}',
                    ),
                    for (final item in events(selected.day, info).entries)
                      Text('${PeriodicCare.labels[item.key]} · ${item.value}'),
                    if (info?['food'] != null)
                      Text(
                        'Refeições: ${info["food"]}${info["meals"] == null ? "" : " de ${info["meals"]}"}  ·  Passeios: ${info["walks"]}${info["outings"] == null ? "" : " de ${info["outings"]}"}',
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
