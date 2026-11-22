import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';

import 'package:audioplayers/audioplayers.dart';

import 'home_glass.dart';
import 'family_settings.dart';
import '../../../core/widgets/primary_cta_button.dart';
import '../../avatar/presentation/avatar_view.dart';
import '../domain/care_slot.dart';
import 'care_controller.dart';
import 'pet_edit_page.dart';
import '../../community/scene_shop.dart';
import '../../community/streak_ranking.dart';
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _burst;
  AudioPlayer? _chime;
  bool celebrating = false;
  String? pressedMenu;
  Timer? _happyTimer;

  Timer? _clock;
  Timer? _notificationDebounce;
  @override
  void initState() {
    super.initState();
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
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
    _burst.dispose();
    _happyTimer?.cancel();
    _chime?.dispose();
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
              periodic: ref.read(careControllerProvider.notifier).periodic,
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
    final scene = ref.watch(sceneProvider);
    final state = ref.watch(careControllerProvider);
    final controller = ref.read(careControllerProvider.notifier);
    final now = controller.petNow();
    final life = ref.watch(lifeControllerProvider);
    ref.listen(careControllerProvider, (_, _) => _scheduleReminders());
    ref.listen(lifeControllerProvider, (_, _) => _scheduleReminders());
    final baseMood = state.resolveMood(now);
    final mood = celebrating
        ? AvatarMood.celebrating
        : baseMood == AvatarMood.happy && life.records.any((r) => r.due(now))
        ? AvatarMood.worried
        : baseMood;
    final nextSlot = state.nextPendingSlot;

    final done = state.slots.where((s) => s.isDone).length;
    String label(CareSlotItem s) => switch (s.kind) {
      CareSlotKind.dailyFeed => 'Alimentar',
      CareSlotKind.dailyWalk => 'Passear',
      CareSlotKind.interval => s.title,
    };
    Future<void> openMenu(String name, Widget page) async {
      if (pressedMenu != null) return;
      setState(() => pressedMenu = name);
      if (!MediaQuery.disableAnimationsOf(context)) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      if (!mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => page));
      if (mounted) setState(() => pressedMenu = null);
    }

    final walk = nextSlot?.kind == CareSlotKind.dailyWalk;
    final due =
        nextSlot != null && nextSlot.sortMinutes <= now.hour * 60 + now.minute;
    Widget count(CareSlotKind kind, String title, IconData icon) {
      final slots = state.slots.where((s) => s.kind == kind);
      return Expanded(
        child: GlassPanel(
          child: Row(
            children: [
              Icon(icon, color: lagoon, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
              Text(
                '${slots.where((s) => s.isDone).length}/${slots.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      bottomNavigationBar: SafeArea(
        top: false,
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            children: [
              for (final entry in [
                ('Rotina', Icons.schedule, const PetEditPage(routine: true)),
                (
                  'Prontuário',
                  Icons.medical_services_outlined,
                  const LifePage(section: LifeSection.health),
                ),
                (
                  'Ração',
                  Icons.restaurant,
                  const LifePage(section: LifeSection.food),
                ),
                (
                  'Estilo',
                  Icons.palette_outlined,
                  const PetEditPage(routine: false),
                ),
                ('Loja', Icons.storefront_outlined, const SceneShop()),
                ('Missões', Icons.emoji_events_outlined, const _MissionsPage()),
              ])
                Expanded(
                  child: Material(
                    color: pressedMenu == entry.$1
                        ? const Color(0xffc8ebe8)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      highlightColor: const Color(0xffb4e0dd),
                      onTap: () => openMenu(entry.$1, entry.$3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(entry.$2, color: lagoon, size: 22),
                            FittedBox(
                              child: Text(
                                entry.$1,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xfff5f8fa), Colors.white, Color(0xffeaf2f4)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 6,
                          children: [
                            Wrap(
                              spacing: 6,
                              children: [
                                _Achievement(
                                  icon: Icons.local_fire_department,
                                  color: const Color(0xffc55717),
                                  value: state.streakDays,
                                  label: 'Ofensiva',
                                ),
                                _Achievement(
                                  icon: Icons.shield_outlined,
                                  color: lagoon,
                                  value: state.freezesAvailable,
                                  label: 'Escudo',
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _profile(state),
                                  icon: const Icon(Icons.people_alt_outlined),
                                  label: const Text('Família'),
                                ),
                                IconButton(
                                  tooltip: 'Lembretes',
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (_) => const RemindersDialog(),
                                  ),
                                  icon: const Icon(
                                    Icons.notifications_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (state.bannerMessage != null)
                          Text(state.bannerMessage!),
                        const SizedBox(height: 8),
                        DayProgress(done: done, total: state.slots.length),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: CustomPaint(
                            painter: ScenePainter(scene),
                            child: Column(
                              children: [
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: GlassPanel(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      mood.speechBubble(
                                        state.petName,
                                        article: state.petGender.article,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                AvatarView(
                                  dna: state.avatarDna,
                                  mood: mood,
                                  size:
                                      (MediaQuery.sizeOf(context).height * .37)
                                          .clamp(220.0, 360.0),
                                ),
                                GlassPanel(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 5,
                                  ),
                                  child: Text(
                                    '${state.petName} ${state.petGender.symbol} · ${mood.badgeLabel}',
                                    style: const TextStyle(
                                      color: ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            count(
                              CareSlotKind.dailyFeed,
                              'Comida',
                              Icons.restaurant,
                            ),
                            const SizedBox(width: 8),
                            count(
                              CareSlotKind.dailyWalk,
                              'Passeios',
                              Icons.directions_walk,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (nextSlot != null)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                colors: [Color(0xffffc883), Color(0xffffa368)],
                              ),
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 14,
                              runSpacing: 8,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      due && walk
                                          ? 'Hora do passeio!'
                                          : 'Próximo cuidado',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: ink,
                                      ),
                                    ),
                                    Text(
                                      '${nextSlot.timeLabel} • ${label(nextSlot)}',
                                      style: const TextStyle(color: ink),
                                    ),
                                  ],
                                ),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: lagoon,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _handleLogCare(
                                    context,
                                    controller,
                                    nextSlot,
                                    state.petName,
                                  ),
                                  icon: TweenAnimationBuilder<double>(
                                    key: ValueKey(nextSlot.id),
                                    tween: Tween(begin: 0.8, end: 1),
                                    duration:
                                        MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 500),
                                    curve: Curves.elasticOut,
                                    builder: (_, v, child) =>
                                        Transform.scale(scale: v, child: child),
                                    child: const Icon(Icons.pets),
                                  ),
                                  label: const Text('Concluir'),
                                ),
                              ],
                            ),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () => _shareStreakMilestone(state),
                            icon: const Icon(Icons.celebration),
                            label: const Text('Dia completo! Compartilhar'),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          'Rotina de hoje',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        _RoutineCarousel(
                          slots: state.slots,
                          card: (slot) => Semantics(
                            button: true,
                            selected: slot.isDone,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
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
                              child: Container(
                                width: 104,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: slot.isDone
                                      ? const Color(0xffd1efe1)
                                      : slot.id == nextSlot?.id
                                      ? const Color(0xffffddae)
                                      : Colors.white.withValues(alpha: .8),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(slot.emoji),
                                        if (slot.isDone)
                                          const Icon(
                                            Icons.check_circle,
                                            size: 15,
                                            color: lagoon,
                                          ),
                                      ],
                                    ),
                                    Text(
                                      slot.timeLabel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: ink,
                                      ),
                                    ),
                                    Text(
                                      label(slot),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: CelebrationPainter(_burst)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _profile(CareHomeState state) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const FamilySettings()));
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
      _happyTimer?.cancel();
      setState(() => celebrating = true);
      _happyTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => celebrating = false);
      });
      if (!MediaQuery.disableAnimationsOf(context)) {
        _burst.forward(from: 0);
        if (ref.read(careControllerProvider).slots.every((s) => s.isDone)) {
          (_chime ??= AudioPlayer())
              .play(AssetSource('sounds/day-complete.wav'))
              .catchError((Object _) {});
        }
      }
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
                'Primeira vitória d${ref.read(careControllerProvider).petGender.article} $petName! 🎉',
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

class _Achievement extends StatelessWidget {
  const _Achievement({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey(value),
          tween: Tween(begin: .88, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 400),
          builder: (_, v, c) => Transform.scale(scale: v, child: c),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          '$value · $label',
          style: const TextStyle(
            color: ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _MissionsPage extends ConsumerWidget {
  const _MissionsPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final care = ref.watch(careControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Missões')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DayProgress(
            done: care.slots.where((s) => s.isDone).length,
            total: care.slots.length,
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Missões de hoje',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final slot in care.slots)
                  ListTile(
                    leading: Icon(
                      slot.isDone
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: lagoon,
                    ),
                    title: Text(slot.title),
                    trailing: Text(slot.timeLabel),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StreakRanking()),
            ),
            icon: const Icon(Icons.emoji_events),
            label: const Text('Ranking de ofensivas'),
          ),
        ],
      ),
    );
  }
}

class _RoutineCarousel extends StatefulWidget {
  const _RoutineCarousel({required this.slots, required this.card});
  final List<CareSlotItem> slots;
  final Widget Function(CareSlotItem) card;
  @override
  State<_RoutineCarousel> createState() => _RoutineCarouselState();
}

class _RoutineCarouselState extends State<_RoutineCarousel> {
  final controller = PageController();
  int page = 0;
  @override
  void didUpdateWidget(_RoutineCarousel old) {
    super.didUpdateWidget(old);
    final before = old.slots.where((s) => !s.isDone).map((s) => s.id).join(',');
    final after = widget.slots
        .where((s) => !s.isDone)
        .map((s) => s.id)
        .join(',');
    if (before != after && controller.hasClients) controller.jumpToPage(0);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [
      ...widget.slots.where((s) => !s.isDone),
      ...widget.slots.where((s) => s.isDone),
    ];
    final pages = (ordered.length / 3).ceil();
    if (pages == 0) return const SizedBox.shrink();
    void move(int index) => controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 230),
      curve: Curves.easeOut,
    );
    return Column(
      children: [
        SizedBox(
          height: 45 + MediaQuery.textScalerOf(context).scale(17) * 3,
          child: PageView.builder(
            controller: controller,
            itemCount: pages,
            onPageChanged: (index) => setState(() => page = index),
            itemBuilder: (_, index) => Row(
              children: [
                for (final slot in ordered.skip(index * 3).take(3))
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: widget.card(slot),
                    ),
                  ),
                for (var i = ordered.length - index * 3; i < 3; i++)
                  const Spacer(),
              ],
            ),
          ),
        ),
        if (pages > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Cuidados anteriores',
                onPressed: page > 0 ? () => move(page - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${page + 1} de $pages'),
              IconButton(
                tooltip: 'Próximos cuidados',
                onPressed: page + 1 < pages ? () => move(page + 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }
}
