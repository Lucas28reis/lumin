import 'package:material_ui/material_ui.dart';

import '../domain/periodic_care.dart';

Future<PeriodicCare?> editPeriodicCare(
  BuildContext context,
  String label,
  PeriodicCare? current,
  DateTime today,
) async {
  var date = current == null
      ? DateTime(today.year, today.month, today.day)
      : DateTime.parse(current.date);
  final parts = current?.time.split(':');
  var time = parts == null || parts.length != 2
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  int? days = current?.days;
  final form = GlobalKey<FormState>();
  return showDialog<PeriodicCare>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(label),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Próxima data'),
                  subtitle: Text(
                    MaterialLocalizations.of(context).formatMediumDate(date),
                  ),
                  onTap: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2200),
                    );
                    if (value != null && context.mounted)
                      update(() => date = value);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Horário'),
                  subtitle: Text(time.format(context)),
                  onTap: () async {
                    final value = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (value != null && context.mounted)
                      update(() => time = value);
                  },
                ),
                TextFormField(
                  initialValue: days?.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Repetir a cada',
                    suffixText: 'dias',
                  ),
                  onChanged: (value) => days = int.tryParse(value),
                  validator: (_) => days == null || days! < 1 || days! > 365
                      ? 'Informe de 1 a 365 dias.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              String pad(int n) => n.toString().padLeft(2, '0');
              Navigator.pop(
                context,
                PeriodicCare(
                  date.toIso8601String().split('T').first,
                  '${pad(time.hour)}:${pad(time.minute)}',
                  days!,
                ),
              );
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    ),
  );
}
