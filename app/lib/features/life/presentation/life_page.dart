import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../care/presentation/care_controller.dart';
import '../domain/pet_life.dart';
import 'life_controller.dart';

enum LifeSection { food, health }

class LifePage extends ConsumerWidget {
  const LifePage({super.key, this.section});
  final LifeSection? section;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final life = ref.watch(lifeControllerProvider);
    final pet = ref.watch(careControllerProvider).petName;
    final now = ref.read(careControllerProvider.notifier).petNow();
    final food = life.food;
    final records = [...life.records]..sort((a, b) => b.date.compareTo(a.date));
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
      ),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              section == LifeSection.food
                  ? 'Ração de $pet'
                  : section == LifeSection.health
                  ? 'Prontuário de $pet'
                  : 'Vida de $pet',
            ),
            actions: [
              if (section != LifeSection.food)
                IconButton(
                  tooltip: 'Compartilhar relatório',
                  icon: const Icon(Icons.share),
                  onPressed: records.isEmpty
                      ? null
                      : () => SharePlus.instance.share(
                          ShareParams(text: healthReport(pet, records)),
                        ),
                ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (section == null)
                    Text(
                      'Alimentação, saúde e memórias',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppColors.onBackground),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Este histórico fica salvo neste aparelho. Use o relatório para compartilhar os registros.',
                    style: TextStyle(color: AppColors.onBackgroundMuted),
                  ),
                  if (life.error != null)
                    Text(
                      life.error!,
                      style: const TextStyle(color: AppColors.onBackground),
                    ),
                  const SizedBox(height: 20),
                  if (section != LifeSection.health)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estoque de ração',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            if (food == null)
                              const Text(
                                'Informe o saco, a porção e a data de abertura para prever a reposição.',
                              )
                            else ...[
                              Text(
                                '${(food.remainingGrams(now) / 1000).toStringAsFixed(1)} kg estimados',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              Text(
                                '${food.remainingMeals(now)} refeições • ${food.remainingDays(now).toStringAsFixed(1)} dias',
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value:
                                    (food.remainingGrams(now) /
                                            (food.kilograms * 1000))
                                        .clamp(0, 1),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${food.gramsPerMeal.toStringAsFixed(0)} g por refeição • ${food.mealsPerDay}x ao dia\n'
                                'Saco aberto em ${shortDate(food.openedOn)}',
                              ),
                              Text(
                                'Previsão de término do saco: ${shortDate(food.lastFeedingDay)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Text(
                                'Previsão pelo consumo diário informado. Ajuste o saldo se houver sobras ou desperdício.',
                              ),
                              if (food.remainingDays(now) <= food.alertDays)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Hora de planejar a próxima compra 🛒',
                                  ),
                                ),
                            ],
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              icon: const Icon(Icons.restaurant),
                              label: Text(
                                food == null
                                    ? 'Configurar ração'
                                    : 'Atualizar estoque / novo saco',
                              ),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => _FoodDialog(food: food),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Compras pelo Lumin: lojas parceiras ainda não disponíveis.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (section != LifeSection.food) ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.local_hospital),
                          label: const Text('Registrar consulta'),
                          onPressed: () => _openHealth(context, HealthKind.vet),
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.medication),
                          label: const Text('Registrar medicamento'),
                          onPressed: () =>
                              _openHealth(context, HealthKind.medication),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Histórico de saúde',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: AppColors.onBackground),
                    ),
                    if (records.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'As consultas e os medicamentos registrados aparecerão aqui.',
                          style: TextStyle(color: AppColors.onBackgroundMuted),
                        ),
                      ),
                    ...records.map(
                      (r) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    r.kind == HealthKind.vet
                                        ? Icons.local_hospital
                                        : Icons.medication,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      r.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Editar registro',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _openHealth(context, r.kind, record: r),
                                  ),
                                ],
                              ),
                              Text(shortDate(r.date)),
                              if (r.notes.isNotEmpty) Text(r.notes),
                              if (r.nextDate != null)
                                Text(
                                  '${r.followUpDone ? 'Acompanhamento realizado' : 'Próxima data'}: ${shortDate(r.nextDate!)}',
                                ),
                              if (r.due(now))
                                const Text('Seu pet precisa de sua atenção 🥺'),
                              if (r.nextDate != null && !r.followUpDone)
                                TextButton(
                                  onPressed: () =>
                                      _openHealth(context, r.kind, followUp: r),
                                  child: const Text(
                                    'Registrar retorno / nova administração',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openHealth(
    BuildContext context,
    HealthKind kind, {
    HealthRecord? record,
    HealthRecord? followUp,
  }) => showDialog<void>(
    context: context,
    builder: (_) =>
        _HealthDialog(kind: kind, record: record, followUp: followUp),
  );
}

class _FoodDialog extends ConsumerStatefulWidget {
  const _FoodDialog({this.food});
  final FoodPlan? food;
  @override
  ConsumerState<_FoodDialog> createState() => _FoodDialogState();
}

class _FoodDialogState extends ConsumerState<_FoodDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _kg, _grams, _meals, _alert;
  late DateTime _opened;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final food = widget.food;
    _kg = TextEditingController(text: food?.kilograms.toString() ?? '20');
    _grams = TextEditingController(
      text: food?.gramsPerMeal.toString() ?? '200',
    );
    _meals = TextEditingController(text: food?.mealsPerDay.toString() ?? '2');
    _alert = TextEditingController(text: food?.alertDays.toString() ?? '15');
    _opened = food?.openedOn ?? ref.read(clockProvider).now();
  }

  @override
  void dispose() {
    for (final c in [_kg, _grams, _meals, _alert]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Estoque e consumo'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= 340 &&
                      MediaQuery.textScalerOf(context).scale(16) <= 21;
                  final width = wide
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children:
                        [
                              _number(_kg, 'Ração em estoque', 'kg', max: 1000),
                              _number(
                                _grams,
                                'Porção por refeição',
                                'g',
                                max: 100000,
                              ),
                              _number(
                                _meals,
                                'Refeições por dia',
                                '',
                                integer: true,
                                max: 12,
                              ),
                              _number(
                                _alert,
                                'Avisar quando restarem',
                                'dias',
                                integer: true,
                                min: 0,
                                max: 365,
                              ),
                            ]
                            .map(
                              (field) => SizedBox(width: width, child: field),
                            )
                            .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                ),
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                onPressed: _saving
                    ? null
                    : () async {
                        final now = ref.read(clockProvider).now();
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _opened,
                          firstDate: DateTime(2000),
                          lastDate: now,
                        );
                        if (date != null && mounted) {
                          setState(() => _opened = date);
                        }
                      },
                label: Text('Data do estoque · ${shortDate(_opened)}'),
              ),
              const Text(
                'Escolha o dia em que havia essa quantidade de ração. O consumo é contado a partir dele.',
              ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Salvar'),
      ),
    ],
  );
  Widget _number(
    TextEditingController c,
    String label,
    String unit, {
    bool integer = false,
    double min = 0.001,
    required double max,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      Semantics(
        label: label,
        child: TextFormField(
          controller: c,
          decoration: InputDecoration(
            suffixText: unit.isEmpty ? null : unit,
            suffixStyle: const TextStyle(color: AppColors.textPrimary),
            errorMaxLines: 2,
            isDense: true,
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: !integer),
          validator: (v) {
            final n = double.tryParse((v ?? '').replaceAll(',', '.'));
            return n == null ||
                    !n.isFinite ||
                    n < min ||
                    n > max ||
                    (integer && n != n.roundToDouble())
                ? 'Informe um valor válido entre $min e $max.'
                : null;
          },
        ),
      ),
    ],
  );
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    double value(TextEditingController c) =>
        double.parse(c.text.replaceAll(',', '.'));
    try {
      await ref
          .read(lifeControllerProvider.notifier)
          .saveFood(
            FoodPlan(
              kilograms: value(_kg),
              gramsPerMeal: value(_grams),
              mealsPerDay: value(_meals).toInt(),
              openedOn: _opened,
              alertDays: value(_alert).toInt(),
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar. Tente novamente.';
        });
      }
    }
  }
}

class _HealthDialog extends ConsumerStatefulWidget {
  const _HealthDialog({required this.kind, this.record, this.followUp});
  final HealthKind kind;
  final HealthRecord? record, followUp;
  @override
  ConsumerState<_HealthDialog> createState() => _HealthDialogState();
}

class _HealthDialogState extends ConsumerState<_HealthDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _notes;
  late DateTime _date;
  DateTime? _next;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: (widget.record ?? widget.followUp)?.title ?? '',
    );
    _notes = TextEditingController(text: widget.record?.notes ?? '');
    _date = widget.record?.date ?? ref.read(clockProvider).now();
    _next = widget.record?.nextDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.kind == HealthKind.vet
          ? 'Consulta veterinária'
          : 'Medicamento administrado',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: widget.kind == HealthKind.vet
                      ? 'Clínica / veterinário / motivo'
                      : 'Nome do medicamento',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Preencha este campo.'
                    : null,
              ),
              TextFormField(
                controller: _notes,
                maxLines: 4,
                maxLength: 3000,
                decoration: const InputDecoration(
                  labelText: 'O que foi feito / administrado, dose prescrita e observações',
                ),
              ),
              TextButton(
                onPressed: _saving ? null : () => _pick(false),
                child: Text('Realizado em: ${shortDate(_date)}'),
              ),
              TextButton(
                onPressed: _saving ? null : () => _pick(true),
                child: Text(
                  _next == null
                      ? 'Adicionar retorno / próxima administração'
                      : 'Próxima data: ${shortDate(_next!)}',
                ),
              ),
              if (_next != null)
                TextButton(
                  onPressed: () => setState(() => _next = null),
                  child: const Text('Sem próxima data'),
                ),
              const Text(
                'Use a data e a dose orientadas pelo veterinário. Nenhum intervalo é prescrito automaticamente.',
              ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Salvar'),
      ),
    ],
  );
  Future<void> _pick(bool next) async {
    final now = ref.read(clockProvider).now();
    final date = await showDatePicker(
      context: context,
      initialDate: next ? (_next ?? _date) : _date,
      firstDate: next
          ? DateTime(_date.year, _date.month, _date.day)
          : DateTime(2000),
      lastDate: next ? DateTime(now.year + 20) : now,
    );
    if (date != null && mounted) {
      setState(() {
        if (next) {
          _next = date;
        } else {
          _date = date;
          if (_next?.isBefore(date) == true) _next = null;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(lifeControllerProvider.notifier)
          .saveRecord(
            HealthRecord(
              id: widget.record?.id ?? const Uuid().v4(),
              kind: widget.kind,
              title: _title.text.trim(),
              date: _date,
              notes: _notes.text.trim(),
              nextDate: _next,
              followUpDone: widget.record?.followUpDone ?? false,
            ),
            closesId: widget.followUp?.id,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível salvar. Tente novamente.';
        });
      }
    }
  }
}
