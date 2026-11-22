import 'package:material_ui/material_ui.dart';

class RoutineTimeEditor extends StatelessWidget {
  const RoutineTimeEditor({
    super.key,
    required this.times,
    required this.onChanged,
    this.walk = false,
  });
  final bool walk;
  final List<String> times;
  final ValueChanged<List<String>> onChanged;

  Future<void> pick(BuildContext context, [int? index]) async {
    final parts = (index == null ? '12:00' : times[index]).split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts.first),
        minute: int.parse(parts.last),
      ),
    );
    if (time == null || !context.mounted) return;
    final value =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final updated = [...times];
    if (index != null) updated.removeAt(index);
    if (updated.contains(value)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esse horário já foi adicionado.')),
      );
      return;
    }
    onChanged([...updated, value]..sort());
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          for (var i = 0; i < times.length; i++)
            InputChip(
              label: Text(times[i]),
              onPressed: () => pick(context, i),
              onDeleted: times.length > (walk ? 0 : 1)
                  ? () => onChanged([...times]..removeAt(i))
                  : null,
            ),
        ],
      ),
      if (times.length < 6)
        TextButton.icon(
          onPressed: () => pick(context),
          icon: const Icon(Icons.add),
          label: Text(walk ? 'Adicionar passeio' : 'Adicionar refeição'),
        ),
    ],
  );
}
