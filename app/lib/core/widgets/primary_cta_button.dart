import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Botão primário de ação ancorado na zona do polegar (Seção 4.4 da SPEC_MVP.md).
/// Usa #FDAC2F para chamar atenção como ação principal selecionada e #081B40 no texto.
class PrimaryCtaButton extends StatelessWidget {
  const PrimaryCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: isLoading ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.surface.withValues(alpha: 0.35),
              foregroundColor: AppColors.textPrimary,
              disabledForegroundColor: AppColors.onBackgroundMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.textPrimary,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 22),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(label, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
          ),
        ),
        if (secondaryLabel != null) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: isLoading ? null : onSecondaryPressed,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.onBackground,
              minimumSize: const Size.fromHeight(44),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(secondaryLabel!),
          ),
        ],
      ],
    );
  }
}
