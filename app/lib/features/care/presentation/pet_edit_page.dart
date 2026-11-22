import 'routine_calendar.dart';
import 'home_glass.dart';
import 'periodic_care_editor.dart';
import '../domain/periodic_care.dart';

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/routine_time_editor.dart';
import '../../avatar/domain/avatar_dna.dart';
import '../../avatar/presentation/avatar_builder_widget.dart';
import '../../notifications/local_reminders.dart';
import '../domain/care_slot.dart';
import 'care_controller.dart';

class PetEditPage extends ConsumerStatefulWidget {
  const PetEditPage({super.key, required this.routine});
  final bool routine;

  @override
  ConsumerState<PetEditPage> createState() => _PetEditPageState();
}

class _PetEditPageState extends ConsumerState<PetEditPage> {
  final _avatarPreviewKey = GlobalKey();
  late AvatarDna dna;
  late String name;
  late List<String> meals, walks;
  final changes = <String, PeriodicCare?>{};
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final pet = ref.read(careControllerProvider);
    dna = pet.avatarDna;
    name = pet.petName;
    List<String> times(CareSlotKind kind) =>
        pet.slots.where((s) => s.kind == kind).map((s) => s.timeLabel).toList();
    meals = times(CareSlotKind.dailyFeed);
    walks = times(CareSlotKind.dailyWalk);
  }

  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final controller = ref.read(careControllerProvider.notifier);
      if (widget.routine) {
        await controller.editPet(meals: meals, walks: walks, changes: changes);
      } else {
        await controller.editPet(name: name.trim(), dna: dna);
        final reminders = ref.read(localRemindersProvider);
        final boundary =
            _avatarPreviewKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
        if (reminders.supported && reminders.enabled && boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          if (data != null) {
            await reminders.updateAvatar(data.buffer.asUint8List());
          }
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e is StateError ? e.message : 'Não foi possível salvar a alteração. Verifique a conexão e tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.routine ? 'Editar rotina' : 'Editar pet'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (widget.routine) ...[
                RoutineCalendar(changes: changes),
                const SizedBox(height: 16),
                _RoutineSection(
                  title: 'Horários das refeições',
                  children: [
                    RoutineTimeEditor(
                      times: meals,
                      onChanged: (v) => setState(() => meals = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _RoutineSection(
                  title: 'Horários dos passeios',
                  children: [
                    RoutineTimeEditor(
                      walk: true,
                      times: walks,
                      onChanged: (v) => setState(() => walks = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _RoutineSection(
                  title: 'Cuidados periódicos',
                  children: [
                    for (final item in PeriodicCare.labels.entries)
                      Builder(
                        builder: (context) {
                          final controller = ref.watch(
                            careControllerProvider.notifier,
                          );
                          final plan = changes.containsKey(item.key)
                              ? changes[item.key]
                              : controller.periodic[item.key];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.value),
                            subtitle: Text(
                              plan == null
                                  ? 'Adicionar data e horário'
                                  : '${plan.date.split('-').reversed.join('/')} · ${plan.time.isEmpty ? "Sem horário" : plan.time} · A cada ${plan.days} dias',
                            ),
                            onTap: () async {
                              final result = await editPeriodicCare(
                                context,
                                item.value,
                                plan,
                                controller.petNow(),
                              );
                              if (result != null && mounted)
                                setState(() => changes[item.key] = result);
                            },
                            trailing: plan == null
                                ? const Icon(Icons.add)
                                : IconButton(
                                    tooltip:
                                        'Remover agendamento de ${item.value}',
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setState(
                                      () => changes[item.key] = null,
                                    ),
                                  ),
                          );
                        },
                      ),
                  ],
                ),
              ] else ...[
                TextFormField(
                  initialValue: name,
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: 'Nome do pet'),
                  onChanged: (v) => setState(() => name = v),
                ),
                AvatarBuilderWidget(
                  avatarPreviewKey: _avatarPreviewKey,
                  dna: dna,
                  onChanged: (v) => setState(() => dna = v),
                  onRandomize: () => setState(
                    () => dna = AvatarDna.random(species: dna.species),
                  ),
                ),
              ],
              if (error != null) Text(error!),
              const SizedBox(height: 18),
              FilledButton(
                onPressed:
                    saving ||
                        (widget.routine ? meals.isEmpty : name.trim().isEmpty)
                    ? null
                    : save,
                child: Text(saving ? 'Salvando…' : 'Salvar alterações'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RoutineSection extends StatelessWidget {
  const _RoutineSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => GlassPanel(
    tint: const Color(0xfffbfeff),
    borderColor: const Color(0xffcbdbe1),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
}
