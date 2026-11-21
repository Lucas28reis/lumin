import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/routine_time_editor.dart';
import '../../avatar/domain/avatar_dna.dart';
import '../../avatar/presentation/avatar_builder_widget.dart';
import '../domain/care_slot.dart';
import 'care_controller.dart';

class PetEditPage extends ConsumerStatefulWidget {
  const PetEditPage({super.key, required this.routine});
  final bool routine;

  @override
  ConsumerState<PetEditPage> createState() => _PetEditPageState();
}

class _PetEditPageState extends ConsumerState<PetEditPage> {
  late AvatarDna dna;
  late String name;
  late List<String> meals, walks;
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
        await controller.editPet(meals: meals, walks: walks);
      } else {
        await controller.editPet(name: name.trim(), dna: dna);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          saving = false;
          error = e is StateError ? e.message : 'Não foi possível salvar a alteração. Verifique a conexão e tente novamente.';
        });
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
                const Text('Horários das refeições'),
                RoutineTimeEditor(
                  times: meals,
                  onChanged: (v) => setState(() => meals = v),
                ),
                const SizedBox(height: 24),
                const Text('Horários dos passeios'),
                RoutineTimeEditor(
                  walk: true,
                  times: walks,
                  onChanged: (v) => setState(() => walks = v),
                ),
              ] else ...[
                TextFormField(
                  initialValue: name,
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: 'Nome do pet'),
                  onChanged: (v) => setState(() => name = v),
                ),
                AvatarBuilderWidget(
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
