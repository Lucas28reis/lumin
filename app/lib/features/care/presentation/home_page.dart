import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_cta_button.dart';
import '../../avatar/presentation/avatar_view.dart';
import '../domain/care_slot.dart';
import 'care_controller.dart';
import 'pet_edit_page.dart';
import '../../avatar/domain/avatar_mood.dart';
import '../../life/presentation/life_page.dart';
import '../../life/presentation/life_controller.dart';
import '../../notifications/local_reminders.dart';
import '../../notifications/reminders_dialog.dart';
import '../../onboarding/presentation/onboarding_controller.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  String? _selectedSlotId;
  Timer? _clock;
  Timer? _notificationDebounce;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleReminders();
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs.getBool('lumin.reminders.requested') == true &&
          ref.read(localRemindersProvider).supported) {
        prefs.setBool('lumin.reminders.requested', false);
        showDialog<void>(
          context: context,
          builder: (_) => const RemindersDialog(),
        );
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _notificationDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(careControllerProvider.notifier).refresh();
      _scheduleReminders();
    }
  }

  void _scheduleReminders() {
    _notificationDebounce?.cancel();
    _notificationDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await ref
            .read(localRemindersProvider)
            .reschedule(
              ref.read(clockProvider).now(),
              ref.read(careControllerProvider),
              ref.read(lifeControllerProvider),
              ref.read(onboardingControllerProvider).draft.timezone,
            );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível atualizar os lembretes. Abra as configurações de avisos para tentar novamente.',
              ),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(careControllerProvider);
    final controller = ref.read(careControllerProvider.notifier);
    final now = controller.petNow();
    final life = ref.watch(lifeControllerProvider);
    ref.listen(careControllerProvider, (_, _) => _scheduleReminders());
    ref.listen(lifeControllerProvider, (_, _) => _scheduleReminders());
    final baseMood = state.resolveMood(now);
    final mood =
        baseMood == AvatarMood.happy && life.records.any((r) => r.due(now))
        ? AvatarMood.worried
        : baseMood;
    final nextSlot = state.nextPendingSlot;

    final activeSlot =
        state.slots.where((s) => s.id == _selectedSlotId).firstOrNull ??
        nextSlot;

    final feedSlots = state.slots
        .where((s) => s.kind == CareSlotKind.dailyFeed)
        .toList();
    final walkSlots = state.slots
        .where((s) => s.kind == CareSlotKind.dailyWalk)
        .toList();
    final doneFeeds = feedSlots.where((s) => s.isDone).length;
    final doneWalks = walkSlots.where((s) => s.isDone).length;
    final totalDone = state.slots.where((s) => s.isDone).length;
    final totalSlots = state.slots.isEmpty ? 1 : state.slots.length;
    final dayPercent = ((totalDone / totalSlots) * 100).round();

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              for (final item in [
                (Icons.schedule, 'Rotina', const PetEditPage(routine: true)),
                (
                  Icons.medical_services_outlined,
                  'Prontuário',
                  const LifePage(section: LifeSection.health),
                ),
                (
                  Icons.restaurant,
                  'Ração',
                  const LifePage(section: LifeSection.food),
                ),
                (
                  Icons.palette_outlined,
                  'Estilo',
                  const PetEditPage(routine: false),
                ),
              ])
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => item.$3)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.$1),
                        Text(item.$2, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Lembretes',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const RemindersDialog(),
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        toolbarHeight: 68,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Row(
              children: [
                _StreakBadge(days: state.streakDays),
                const SizedBox(width: 10),
                _FreezeBadge(freezes: state.freezesAvailable),
                const Spacer(),
                IconButton(
                  onPressed: controller.refresh,
                  tooltip: 'Atualizar cuidados',
                  icon: const Icon(Icons.refresh),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _shareFamilyInvite(state),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.group_add_rounded, size: 18),
                  label: Text(
                    state.householdMemberCount == 1
                        ? 'Família (1)'
                        : '${state.householdMemberCount} tutores',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              children: [
                if (state.bannerMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sync_rounded,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              state.bannerMessage!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // =====================================================
                        // LADO ESQUERDO: Opções sequenciais por horário
                        // (07:30 -> 08:00 -> 18:30 -> 19:00) somente com figura
                        // =====================================================
                        SizedBox(
                          width: 86,
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: state.slots.map((slot) {
                                  final isSelected = activeSlot?.id == slot.id;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: _LeftCareFigureButton(
                                      slot: slot,
                                      isSelected: isSelected,
                                      onTap: () {
                                        setState(
                                          () => _selectedSlotId = slot.id,
                                        );
                                        if (slot.isDone && slot.logId != null) {
                                          ScaffoldMessenger.of(context)
                                              .clearSnackBars();
                                          controller.undoLastCare(slot.logId!);
                                        } else if (!slot.isDone) {
                                          _handleLogCare(
                                            context,
                                            controller,
                                            slot,
                                            state.petName,
                                          );
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // =====================================================
                        // PALCO CENTRAL RICO: O Avatar Gigante + Status do Pet
                        // =====================================================
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Balão de fala do Pet
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.border,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      mood.speechBubble(state.petName),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Avatar Principal Grande
                                  Flexible(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final maxDim =
                                            constraints.maxHeight.isFinite
                                            ? constraints.maxHeight.clamp(
                                                210.0,
                                                340.0,
                                              )
                                            : 300.0;
                                        return AvatarView(
                                          dna: state.avatarDna,
                                          mood: mood,
                                          size: maxDim,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Identidade rica do Pet (Nome + Sexo + Humor)
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: Text(
                                          '${state.petName} ${state.petGender.symbol} • ${mood.badgeLabel}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          '$dayPercent% do dia concluído',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Painel de Status Rico do Pet (Refeições, Passeios e Rotina)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppColors.border,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _PetStatMiniColumn(
                                          label: 'Comida',
                                          value:
                                              '$doneFeeds/${feedSlots.length}',
                                          isComplete:
                                              feedSlots.isNotEmpty &&
                                              doneFeeds == feedSlots.length,
                                        ),
                                        Container(
                                          width: 1.5,
                                          height: 28,
                                          color: AppColors.border,
                                        ),
                                        _PetStatMiniColumn(
                                          label: 'Passeios',
                                          value:
                                              '$doneWalks/${walkSlots.length}',
                                          isComplete:
                                              walkSlots.isEmpty ||
                                              doneWalks == walkSlots.length,
                                        ),
                                        Container(
                                          width: 1.5,
                                          height: 28,
                                          color: AppColors.border,
                                        ),
                                        _PetStatMiniColumn(
                                          label: 'Próximo',
                                          value:
                                              nextSlot?.timeLabel ?? '100% ✓',
                                          isComplete: nextSlot == null,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Botão de ação principal
                                  if (nextSlot != null)
                                    PrimaryCtaButton(
                                      label:
                                          '${nextSlot.emoji} ${nextSlot.timeLabel} • ${nextSlot.kind == CareSlotKind.dailyWalk
                                              ? "Passear"
                                              : nextSlot.kind == CareSlotKind.dailyFeed
                                              ? "Alimentar"
                                              : nextSlot.title}',
                                      onPressed: () => _handleLogCare(
                                        context,
                                        controller,
                                        nextSlot,
                                        state.petName,
                                      ),
                                    )
                                  else
                                    PrimaryCtaButton(
                                      label: '🎉 Dia completo! Compartilhar',
                                      onPressed: () =>
                                          _shareStreakMilestone(state),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogCare(
    BuildContext context,
    CareController controller,
    CareSlotItem slot,
    String petName,
  ) async {
    final result = await controller.logCareSlot(slot.id);
    final logId = result.logId;

    if (logId != null && context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${slot.emoji} ${slot.timeLabel} registrado!'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () => controller.undoLastCare(logId),
          ),
        ),
      );
    }

    if (result.shouldPromptAccountLink && context.mounted) {
      _showAccountLinkBottomSheet(context, controller, petName);
    }
  }

  Future<void> _shareFamilyInvite(CareHomeState state) async {
    if (ref.read(supabaseClientProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Convites ficam disponíveis quando a conexão da família estiver configurada.',
          ),
        ),
      );
      return;
    }
    final text =
        'Agora a gente cuida do ${state.petName} junto pelo Lumin 🐾 '
        'Usa o código ${state.inviteCode} para entrar na família!';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _shareStreakMilestone(CareHomeState state) async {
    final text =
        '🔥 ${state.petName}: ${state.streakDays} dia(s) sem faltar nenhum cuidado no Lumin! 🐾';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  void _showAccountLinkBottomSheet(
    BuildContext context,
    CareController controller,
    String petName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Primeira vitória do $petName! 🎉',
                style: Theme.of(sheetContext).textTheme.titleLarge
                    ?.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Os cuidados locais estão salvos neste aparelho. A vinculação de conta depende da conexão online; o histórico de saúde pode ser compartilhado em relatório.',
                style: Theme.of(sheetContext).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              PrimaryCtaButton(
                label: 'Continuar com Google',
                icon: Icons.g_mobiledata_rounded,
                onPressed: () {
                  controller.markAccountLinked('Google');
                  Navigator.of(sheetContext).pop();
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  controller.markAccountLinked('Apple');
                  Navigator.of(sheetContext).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.apple_rounded),
                label: const Text(
                  'Continuar com Apple',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('Lembrar depois'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PetStatMiniColumn extends StatelessWidget {
  const _PetStatMiniColumn({
    required this.label,
    required this.value,
    required this.isComplete,
  });

  final String label;
  final String value;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isComplete ? AppColors.primary : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Botão lateral compacto: exibe apenas a figura/imagem (que o usuário pode
/// substituir via `slot.iconAsset`) e o horário sequencial (`07:30`, `08:00`, etc.).
/// Usa #FBE8CF como quadro base e #FDAC2F quando selecionado/ativo!
class _LeftCareFigureButton extends StatelessWidget {
  const _LeftCareFigureButton({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  final CareSlotItem slot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = isSelected || slot.isDone;

    return Tooltip(
      message: slot.title,
      child: Material(
        color: isSelected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: highlighted ? AppColors.primary : AppColors.border,
                width: highlighted ? 2.5 : 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (slot.iconAsset != null)
                      Image.asset(
                        slot.iconAsset!,
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      )
                    else
                      Text(slot.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 4),
                    Text(
                      slot.timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        decoration: slot.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (slot.isDone)
                  Positioned(
                    top: -4,
                    right: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget de Ofensiva redesenhado com ícone vetorial customizado (_FlameVectorPainter)
/// e visual de jogo nos tons #FBE8CF / #FDAC2F / #081B40.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final isActive = days > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: CustomPaint(
                size: Size(18, 20),
                painter: _FlameVectorPainter(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$days ${days == 1 ? "dia" : "dias"}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'Ofensiva',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget de Escudo de Gelo redesenhado com cristal vetorial customizado (_IceCrystalVectorPainter).
class _FreezeBadge extends StatelessWidget {
  const _FreezeBadge({required this.freezes});
  final int freezes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.freezeBlue, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: CustomPaint(
                size: Size(18, 20),
                painter: _IceCrystalVectorPainter(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$freezes ${freezes == 1 ? "escudo" : "escudos"}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'Proteção',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlameVectorPainter extends CustomPainter {
  const _FlameVectorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final outerFlame = Path()
      ..moveTo(w * 0.52, 0)
      ..cubicTo(w * 0.88, h * 0.25, w * 1.0, h * 0.55, w * 0.84, h * 0.82)
      ..cubicTo(w * 0.72, h * 0.98, w * 0.28, h * 0.98, w * 0.16, h * 0.82)
      ..cubicTo(0, h * 0.58, w * 0.18, h * 0.30, w * 0.36, h * 0.18)
      ..cubicTo(w * 0.34, h * 0.32, w * 0.44, h * 0.36, w * 0.52, 0)
      ..close();

    canvas.drawPath(
      outerFlame,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.fill,
    );

    final innerCore = Path()
      ..moveTo(w * 0.50, h * 0.38)
      ..cubicTo(w * 0.72, h * 0.54, w * 0.74, h * 0.76, w * 0.62, h * 0.90)
      ..cubicTo(w * 0.54, h * 0.96, w * 0.42, h * 0.96, w * 0.36, h * 0.88)
      ..cubicTo(w * 0.26, h * 0.74, w * 0.32, h * 0.54, w * 0.50, h * 0.38)
      ..close();

    canvas.drawPath(
      innerCore,
      Paint()
        ..color = AppColors.surface
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IceCrystalVectorPainter extends CustomPainter {
  const _IceCrystalVectorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shield = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.94, h * 0.24)
      ..lineTo(w * 0.84, h * 0.74)
      ..lineTo(w * 0.5, h)
      ..lineTo(w * 0.16, h * 0.74)
      ..lineTo(w * 0.06, h * 0.24)
      ..close();

    canvas.drawPath(
      shield,
      Paint()
        ..color = AppColors.freezeBlue
        ..style = PaintingStyle.fill,
    );

    final highlight = Path()
      ..moveTo(w * 0.5, h * 0.16)
      ..lineTo(w * 0.76, h * 0.32)
      ..lineTo(w * 0.5, h * 0.82)
      ..lineTo(w * 0.24, h * 0.32)
      ..close();

    canvas.drawPath(
      highlight,
      Paint()
        ..color = AppColors.surface.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
