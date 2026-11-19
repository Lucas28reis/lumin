import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_cta_button.dart';
import '../../../core/widgets/step_progress_bar.dart';
import '../../avatar/domain/avatar_dna.dart';
import '../../avatar/domain/avatar_mood.dart';
import '../../avatar/presentation/avatar_builder_widget.dart';
import '../../avatar/presentation/avatar_view.dart';
import '../domain/onboarding_draft.dart';
import 'onboarding_controller.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialStep = ref.read(onboardingControllerProvider).currentStep;
    _pageController = PageController(initialPage: initialStep);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(onboardingControllerProvider.select((s) => s.currentStep), (
      previous,
      next,
    ) {
      if (!_pageController.hasClients) return;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });

    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    if (state.mode == OnboardingFlowMode.guest) {
      return _GuestOnboardingScaffold(state: state, controller: controller);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (state.currentStep > 0)
              StepProgressBar(
                currentStep: state.currentStep,
                totalSteps: 6,
                onBack: state.canGoBack ? controller.goBack : null,
              )
            else
              const SizedBox(height: 12),
            if (state.errorMessage != null)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _CenteredStepShell(
                    child: _Step0WelcomeView(
                      state: state,
                      onStartCreator: controller.startCreatorFlow,
                      onStartGuest: controller.startGuestFlow,
                    ),
                  ),
                  _CenteredStepShell(
                    child: _Step1PetIdentityView(
                      state: state,
                      onSpeciesSelected: controller.selectSpecies,
                      onGenderSelected: controller.selectGender,
                      onNameChanged: controller.updatePetName,
                      onNext: controller.submitStep1PetInfo,
                    ),
                  ),
                  _CenteredStepShell(
                    child: _Step2AvatarBuilderView(
                      state: state,
                      onDnaChanged: controller.updateAvatarDna,
                      onRandomize: controller.randomizeAvatar,
                      onNext: controller.submitStep2Avatar,
                    ),
                  ),
                  _CenteredStepShell(
                    child: _Step3DailyRoutineView(
                      state: state,
                      onFeedPresetSelected: controller.selectFeedPreset,
                      onWalkPresetSelected: controller.selectWalkPreset,
                      onNext: controller.submitStep3Routine,
                    ),
                  ),
                  _CenteredStepShell(
                    child: _Step4ForgettableCareView(
                      state: state,
                      onToggleCare: controller.toggleForgettableCare,
                      onRecencyChanged: controller.setForgettableCareRecency,
                      onNext: () => controller.submitStep4ForgettableCare(
                        skipped: false,
                      ),
                      onSkip: () => controller.submitStep4ForgettableCare(
                        skipped: true,
                      ),
                    ),
                  ),
                  _CenteredStepShell(
                    child: _Step5HouseholdInviteView(
                      state: state,
                      onTutorNameChanged: controller.updateTutorDisplayName,
                      onSharedInvite: () =>
                          controller.submitStep5Household(sharedInvite: true),
                      onSoloContinue: () =>
                          controller.submitStep5Household(sharedInvite: false),
                    ),
                  ),
                  _CenteredStepShell(
                    child: _Step6NotificationPromptView(
                      state: state,
                      onEnableNotifications: () =>
                          controller.finishOnboarding(grantedPush: true),
                      onSkipNotifications: () =>
                          controller.finishOnboarding(grantedPush: false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredStepShell extends StatelessWidget {
  const _CenteredStepShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: child,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PASSO 0: Boas-vindas
// -----------------------------------------------------------------------------
class _Step0WelcomeView extends StatelessWidget {
  const _Step0WelcomeView({
    required this.state,
    required this.onStartCreator,
    required this.onStartGuest,
  });

  final OnboardingState state;
  final VoidCallback onStartCreator;
  final VoidCallback onStartGuest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AvatarView(
                      dna: state.draft.avatarDna,
                      mood: AvatarMood.celebrating,
                      size: 210,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Todo pet merece uma família organizada 🐾',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sincronize refeições, passeios e antipulgas em tempo real com quem divide o cuidado com você.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: AppColors.onBackgroundMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryCtaButton(
            label: 'Começar agora',
            isLoading: state.isSubmitting,
            onPressed: onStartCreator,
            secondaryLabel: 'Tenho um código de convite',
            onSecondaryPressed: onStartGuest,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PASSO 1: Espécie + Sexo (Macho/Fêmea) + Nome do Pet
// -----------------------------------------------------------------------------
class _Step1PetIdentityView extends StatefulWidget {
  const _Step1PetIdentityView({
    required this.state,
    required this.onSpeciesSelected,
    required this.onGenderSelected,
    required this.onNameChanged,
    required this.onNext,
  });

  final OnboardingState state;
  final ValueChanged<PetSpecies> onSpeciesSelected;
  final ValueChanged<PetGender> onGenderSelected;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onNext;

  @override
  State<_Step1PetIdentityView> createState() => _Step1PetIdentityViewState();
}

class _Step1PetIdentityViewState extends State<_Step1PetIdentityView> {
  late final TextEditingController _nameController;
  final FocusNode _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.state.draft.petName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.state.draft;
    final canContinue = draft.petName.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Quem é o dono do seu coração?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Escolha a espécie, o sexo e diga como vocês chamam ele(a).',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),

                  // 1. Seletor de Espécie (Cachorro / Gato)
                  Row(
                    children: PetSpecies.values.map((species) {
                      final selected = draft.species == species;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: species == PetSpecies.dog ? 8 : 0,
                            left: species == PetSpecies.cat ? 8 : 0,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => widget.onSpeciesSelected(species),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: selected ? 2.5 : 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    species.emoji,
                                    style: const TextStyle(fontSize: 36),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    species.label,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // 2. Seletor de Sexo (Macho ♂️ / Fêmea ♀️)
                  Row(
                    children: PetGender.values.map((gender) {
                      final selected = draft.gender == gender;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: gender == PetGender.male ? 8 : 0,
                            left: gender == PetGender.female ? 8 : 0,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => widget.onGenderSelected(gender),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: selected ? 2.5 : 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    gender.symbol,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    gender.label,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // 3. Rótulo Fixo Claro + TextField com Texto Escuro (#081B40) de Alto Contraste
                  const Text(
                    'Nome do pet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onBackground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 30,
                    cursorColor: AppColors.textPrimary,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                    onChanged: widget.onNameChanged,
                    onSubmitted: (_) {
                      if (canContinue) widget.onNext();
                    },
                    decoration: const InputDecoration(
                      hintText: 'Ex: Paçoca, Luma, Mel, Thor...',
                      counterText: '',
                      prefixIcon: Icon(
                        Icons.pets_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryCtaButton(
            label: 'Continuar',
            onPressed: canContinue ? widget.onNext : null,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PASSO 2: Montador Manual do Avatar
// -----------------------------------------------------------------------------
class _Step2AvatarBuilderView extends StatelessWidget {
  const _Step2AvatarBuilderView({
    required this.state,
    required this.onDnaChanged,
    required this.onRandomize,
    required this.onNext,
  });

  final OnboardingState state;
  final ValueChanged<AvatarDna> onDnaChanged;
  final VoidCallback onRandomize;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final petName = state.draft.petName.trim().isEmpty
        ? 'seu pet'
        : state.draft.petName.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Vamos desenhar o $petName!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Combine os traços abaixo ou toque no dado para surpreender.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: AvatarBuilderWidget(
                dna: state.draft.avatarDna,
                onChanged: onDnaChanged,
                onRandomize: onRandomize,
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryCtaButton(label: 'É o $petName!', onPressed: onNext),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PASSO 3: Rotina Diária (Distribuída em Cards Visuais + Prévia Sequencial)
// -----------------------------------------------------------------------------
class _Step3DailyRoutineView extends StatelessWidget {
  const _Step3DailyRoutineView({
    required this.state,
    required this.onFeedPresetSelected,
    required this.onWalkPresetSelected,
    required this.onNext,
  });

  final OnboardingState state;
  final ValueChanged<FeedPreset> onFeedPresetSelected;
  final ValueChanged<WalkPreset> onWalkPresetSelected;
  final VoidCallback onNext;

  List<({String time, String label, String emoji})> _buildPreviewTimeline(
    OnboardingDraft draft,
  ) {
    final items = <({int minutes, String time, String label, String emoji})>[];
    for (final t in draft.activeFeedTimes) {
      final p = t.split(':');
      final m = (int.tryParse(p[0]) ?? 8) * 60 + (int.tryParse(p[1]) ?? 0);
      items.add((minutes: m, time: t, label: 'Comida', emoji: '🍖'));
    }
    for (final t in draft.activeWalkTimes) {
      final p = t.split(':');
      final m = (int.tryParse(p[0]) ?? 18) * 60 + (int.tryParse(p[1]) ?? 0);
      items.add((minutes: m, time: t, label: 'Passeio', emoji: '🦮'));
    }
    items.sort((a, b) => a.minutes.compareTo(b.minutes));
    return items
        .map((e) => (time: e.time, label: e.label, emoji: e.emoji))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final draft = state.draft;
    final petName = draft.petName.trim().isEmpty
        ? 'seu pet'
        : draft.petName.trim();
    final timeline = _buildPreviewTimeline(draft);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Qual a rotina do $petName?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Isso mantém a família sincronizada e a ofensiva acesa.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Card 1: Refeições por dia
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.surface.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '🍖 Refeições por dia',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.onBackground),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: FeedPreset.values.map((preset) {
                            final selected = draft.feedPreset == preset;
                            return ChoiceChip(
                              label: Text(preset.label),
                              selected: selected,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surface,
                              checkmarkColor: AppColors.textPrimary,
                              labelStyle: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                              onSelected: (_) => onFeedPresetSelected(preset),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Card 2: Passeios por dia
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.surface.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '🦮 Passeios por dia',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.onBackground),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: WalkPreset.values.map((preset) {
                            final selected = draft.walkPreset == preset;
                            return ChoiceChip(
                              label: Text(preset.label),
                              selected: selected,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surface,
                              checkmarkColor: AppColors.textPrimary,
                              labelStyle: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                              onSelected: (_) => onWalkPresetSelected(preset),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Card 3: Prévia da Ordem Sequencial de Horários
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '⏰ Ordem Sequencial do Dia',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: timeline.map((item) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.emoji,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${item.time} • ${item.label}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryCtaButton(label: 'Continuar', onPressed: onNext),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PASSO 4: Cuidados Esquecíveis (Antipulgas, Vermífugo, Remédio)
// -----------------------------------------------------------------------------
class _Step4ForgettableCareView extends StatelessWidget {
  const _Step4ForgettableCareView({
    required this.state,
    required this.onToggleCare,
    required this.onRecencyChanged,
    required this.onNext,
    required this.onSkip,
  });

  final OnboardingState state;
  final ValueChanged<ForgettableCareType> onToggleCare;
  final void Function(ForgettableCareType, LastDoneRecency) onRecencyChanged;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final careMap = state.draft.forgettableCare;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Os cuidados que todo mundo esquece 😅',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Selecione o que você quer que o Lumin lembre na data certa.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: ForgettableCareType.values.map((type) {
                final selected = careMap.containsKey(type);
                final currentRecency = careMap[type];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 2.5 : 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => onToggleCare(type),
                        child: Row(
                          children: [
                            Text(
                              type.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                type.label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Checkbox(
                              value: selected,
                              activeColor: AppColors.primary,
                              checkColor: AppColors.textPrimary,
                              onChanged: (_) => onToggleCare(type),
                            ),
                          ],
                        ),
                      ),
                      if (selected) ...[
                        const Divider(height: 16),
                        const Text(
                          'Quando foi a última vez?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: LastDoneRecency.values.map((rec) {
                            final isRecSelected = currentRecency == rec;
                            return ChoiceChip(
                              label: Text(rec.label),
                              selected: isRecSelected,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surfaceAlt,
                              checkmarkColor: AppColors.textPrimary,
                              labelStyle: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                              onSelected: (_) => onRecencyChanged(type, rec),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          PrimaryCtaButton(
            label: 'Salvar e continuar',
            isLoading: state.isSubmitting,
            onPressed: onNext,
            secondaryLabel: 'Pular por enquanto',
            onSecondaryPressed: onSkip,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PASSO 5: Convite do Co-tutor + Nome do Tutor
// -----------------------------------------------------------------------------
class _Step5HouseholdInviteView extends StatefulWidget {
  const _Step5HouseholdInviteView({
    required this.state,
    required this.onTutorNameChanged,
    required this.onSharedInvite,
    required this.onSoloContinue,
  });

  final OnboardingState state;
  final ValueChanged<String> onTutorNameChanged;
  final VoidCallback onSharedInvite;
  final VoidCallback onSoloContinue;

  @override
  State<_Step5HouseholdInviteView> createState() =>
      _Step5HouseholdInviteViewState();
}

class _Step5HouseholdInviteViewState extends State<_Step5HouseholdInviteView> {
  late final TextEditingController _tutorController;

  @override
  void initState() {
    super.initState();
    _tutorController = TextEditingController(
      text: widget.state.draft.tutorDisplayName,
    );
  }

  @override
  void dispose() {
    _tutorController.dispose();
    super.dispose();
  }

  Future<void> _shareInvite() async {
    final petName = widget.state.draft.petName.trim().isEmpty
        ? 'nosso pet'
        : widget.state.draft.petName.trim();
    final code = widget.state.inviteCode ?? 'LUMIN2';
    final message =
        'Agora a gente cuida do $petName junto pelo Lumin 🐾 '
        'Baixa o app e usa o código $code para sincronizar as tarefas!';
    await SharePlus.instance.share(ShareParams(text: message));
    widget.onSharedInvite();
  }

  @override
  Widget build(BuildContext context) {
    final petName = widget.state.draft.petName.trim().isEmpty
        ? 'seu pet'
        : widget.state.draft.petName.trim();
    final inviteCode = widget.state.inviteCode ?? 'LUMIN2';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Quem mais cuida do $petName?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quando alguém der comida ou passear, todo mundo na casa fica sabendo na hora.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Como o $petName te chama?',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onBackground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tutorController,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 30,
                    cursorColor: AppColors.textPrimary,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                    onChanged: widget.onTutorNameChanged,
                    decoration: const InputDecoration(
                      hintText: 'Ex: Mãe, Pai, Ana, Lucas...',
                      counterText: '',
                      prefixIcon: Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'CÓDIGO DA FAMÍLIA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          inviteCode,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Válido por 7 dias para até 5 pessoas da casa',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryCtaButton(
            label: 'Convidar pelo WhatsApp',
            icon: Icons.share_rounded,
            onPressed: _shareInvite,
            secondaryLabel: 'Cuido sozinho(a) por enquanto',
            onSecondaryPressed: widget.onSoloContinue,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PASSO 6: Pre-prompt de Notificações
// -----------------------------------------------------------------------------
class _Step6NotificationPromptView extends StatelessWidget {
  const _Step6NotificationPromptView({
    required this.state,
    required this.onEnableNotifications,
    required this.onSkipNotifications,
  });

  final OnboardingState state;
  final VoidCallback onEnableNotifications;
  final VoidCallback onSkipNotifications;

  @override
  Widget build(BuildContext context) {
    final petName = state.draft.petName.trim().isEmpty
        ? 'seu pet'
        : state.draft.petName.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
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
                      child: Text(
                        '"Me avisa quando for hora do meu papá? 🥺"',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AvatarView(
                      dna: state.draft.avatarDna,
                      mood: AvatarMood.hungry,
                      size: 180,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Quer que eu te avise se o $petName ficar com fome?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Só mandamos lembrete se ninguém da família tiver marcado a tarefa ainda.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryCtaButton(
            label: 'Sim, me avise!',
            icon: Icons.notifications_active_rounded,
            onPressed: onEnableNotifications,
            secondaryLabel: 'Agora não',
            onSecondaryPressed: onSkipNotifications,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FLUXO DO CONVIDADO (Seção 4.3 da SPEC_MVP.md)
// -----------------------------------------------------------------------------
class _GuestOnboardingScaffold extends StatefulWidget {
  const _GuestOnboardingScaffold({
    required this.state,
    required this.controller,
  });

  final OnboardingState state;
  final OnboardingController controller;

  @override
  State<_GuestOnboardingScaffold> createState() =>
      _GuestOnboardingScaffoldState();
}

class _GuestOnboardingScaffoldState extends State<_GuestOnboardingScaffold> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(
    text: 'Co-tutor',
  );

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: controller.goBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Entrar na família'),
      ),
      body: SafeArea(
        child: _CenteredStepShell(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: state.currentStep == 1
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Digite o código de 6 caracteres',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Quem já cadastrou o pet recebeu esse código no passo de convite.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Código de convite',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onBackground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        cursorColor: AppColors.textPrimary,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                        onChanged: controller.updateGuestCodeInput,
                        decoration: const InputDecoration(
                          hintText: 'Ex: K7M9P2',
                          counterText: '',
                          prefixIcon: Icon(Icons.key_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Como o pet te chama?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onBackground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 30,
                        cursorColor: AppColors.textPrimary,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                        onChanged: controller.updateTutorDisplayName,
                        decoration: const InputDecoration(
                          hintText: 'Ex: Pai, Mãe, João...',
                          counterText: '',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.errorMessage!,
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const Spacer(),
                      PrimaryCtaButton(
                        label: 'Entrar na família',
                        isLoading: state.isSubmitting,
                        onPressed: state.guestCodeInput.trim().length == 6
                            ? controller.submitGuestJoin
                            : null,
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const Spacer(),
                      AvatarView(
                        dna: state.draft.avatarDna,
                        mood: AvatarMood.celebrating,
                        size: 210,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Você agora cuida do ${state.draft.petName.isEmpty ? "Paçoca" : state.draft.petName} em família! 🎉',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ative os avisos para saber na hora quando alguém alimentar ou passear.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      PrimaryCtaButton(
                        label: 'Ativar avisos e ir para a Home',
                        icon: Icons.notifications_active_rounded,
                        onPressed: () =>
                            controller.finishOnboarding(grantedPush: true),
                        secondaryLabel: 'Entrar sem avisos',
                        onSecondaryPressed: () =>
                            controller.finishOnboarding(grantedPush: false),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
