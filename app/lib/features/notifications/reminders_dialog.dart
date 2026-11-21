import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../avatar/domain/avatar_mood.dart';
import '../avatar/presentation/avatar_view.dart';
import '../care/presentation/care_controller.dart';
import '../life/presentation/life_controller.dart';
import '../onboarding/presentation/onboarding_controller.dart';
import '../../core/providers/core_providers.dart';
import 'local_reminders.dart';

class RemindersDialog extends ConsumerStatefulWidget {
  const RemindersDialog({super.key});
  @override
  ConsumerState<RemindersDialog> createState() => _RemindersDialogState();
}

class _RemindersDialogState extends ConsumerState<RemindersDialog> {
  final _preview = GlobalKey();
  bool _saving = false;
  bool _avatarReady = false;
  String? _message;
  @override
  Widget build(BuildContext context) {
    final care = ref.watch(careControllerProvider);
    final reminders = ref.watch(localRemindersProvider);
    return AlertDialog(
      contentTextStyle: const TextStyle(
        color: Color(0xFF081B40),
        fontSize: 14,
        height: 1.4,
      ),
      titleTextStyle: const TextStyle(
        color: Color(0xFF081B40),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      title: const Text('Lembretes do seu pet'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _preview,
                child: ColoredBox(
                  color: const Color(0xFFFBE8CF),
                  child: AvatarView(
                    dna: care.avatarDna,
                    mood: AvatarMood.worried,
                    size: 180,
                    interactive: false,
                    onReady: () {
                      if (mounted && !_avatarReady) {
                        setState(() => _avatarReady = true);
                      }
                    },
                  ),
                ),
              ),
              Text('${care.petName} precisa de sua atenção 🥺'),
              const SizedBox(height: 12),
              const Text(
                'Ração, rotina e próximas datas. Até 3 avisos por dia, entre 7h e 22h.',
              ),
              const Text(
                'A rotina dos próximos 14 dias é renovada ao abrir o app; ração e saúde também usam as datas futuras cadastradas. Sem push, alterações de outro tutor só cancelam avisos após sincronizar este aparelho.',
              ),
              if (!reminders.supported)
                const Text(
                  'Notificações do sistema disponíveis nesta versão apenas no Android.',
                ),
              if (_message != null) Text(_message!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        if (reminders.enabled)
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    await reminders.disable();
                    if (mounted) {
                      setState(() => _message = 'Lembretes desativados.');
                    }
                  },
            child: const Text('Desativar'),
          ),
        FilledButton(
          onPressed: _saving || !reminders.supported || !_avatarReady
              ? null
              : _enable,
          child: const Text('Ativar lembretes'),
        ),
      ],
    );
  }

  Future<void> _enable() async {
    setState(() => _saving = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _preview.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (!mounted) return;
      final reminders = ref.read(localRemindersProvider);
      final granted = await reminders.enable(data!.buffer.asUint8List());
      if (!mounted) return;
      if (granted) {
        await reminders.reschedule(
          ref.read(clockProvider).now(),
          ref.read(careControllerProvider),
          ref.read(lifeControllerProvider),
          ref.read(onboardingControllerProvider).draft.timezone,
        );
      }
      if (mounted) {
        setState(
          () => _message = granted ? 'Lembretes ativados neste aparelho.' : 'Permissão não concedida. Você pode ativá-la nas configurações do Android.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Não foi possível ativar os lembretes. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
