import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Barra de progresso com indicador claro das etapas (1..6) e aviso do próximo passo.
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.onBack,
  });

  /// Passo atual (1-based: 1..totalSteps).
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onBack;

  static const List<String> _stepTitles = [
    'Identidade',
    'Aparência',
    'Rotina',
    'Saúde',
    'Família',
    'Avisos',
  ];

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep / totalSteps).clamp(0.0, 1.0);
    final idx = (currentStep - 1).clamp(0, _stepTitles.length - 1);
    final currentTitle = _stepTitles[idx];
    final nextTitle =
        currentStep < _stepTitles.length ? _stepTitles[currentStep] : 'Concluir';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: onBack != null
                        ? IconButton(
                            onPressed: onBack,
                            tooltip: 'Voltar',
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: AppColors.onBackground,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Etapa $currentStep de $totalSteps: $currentTitle',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              currentStep < totalSteps
                                  ? 'Próximo: $nextTitle →'
                                  : 'Última etapa! 🎉',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onBackgroundMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 10,
                            child: ColoredBox(
                              color: AppColors.surface.withValues(alpha: 0.22),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: progress),
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, _) {
                                  return FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: value,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Pílulas numeradas das 6 etapas centralizadas
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: List.generate(_stepTitles.length, (i) {
                  final stepNum = i + 1;
                  final isCurrent = stepNum == currentStep;
                  final isDone = stepNum < currentStep;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.primary
                          : isDone
                              ? AppColors.surface
                              : AppColors.surface.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isDone
                          ? '✓ ${_stepTitles[i]}'
                          : '$stepNum. ${_stepTitles[i]}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: (isCurrent || isDone)
                            ? AppColors.textPrimary
                            : AppColors.onBackgroundMuted,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
