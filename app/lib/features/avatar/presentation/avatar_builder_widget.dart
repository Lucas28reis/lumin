import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/avatar_dna.dart';
import 'avatar_view.dart';

/// Montador manual do Avatar de corpo inteiro com todas as características
/// editáveis em tempo real + botão "🎲 Aleatório" e botões 100% centralizados.
class AvatarBuilderWidget extends StatefulWidget {
  const AvatarBuilderWidget({
    super.key,
    required this.dna,
    required this.onChanged,
    required this.onRandomize,
    this.avatarPreviewKey,
  });

  final AvatarDna dna;
  final ValueChanged<AvatarDna> onChanged;
  final VoidCallback onRandomize;
  final Key? avatarPreviewKey;

  @override
  State<AvatarBuilderWidget> createState() => _AvatarBuilderWidgetState();
}

class _AvatarBuilderWidgetState extends State<AvatarBuilderWidget> {
  int _selectedTraitTab = 0;

  static const List<String> _traitTabs = [
    'Pelagem',
    'Padrão',
    'Cor 2',
    'Orelhas',
    'Focinho',
    'Olhos',
    'Acessório',
  ];

  static const List<({String? code, String label})> _accessoryOptions = [
    (code: 'collar', label: 'Coleira + Cristal'),
    (code: 'bandana', label: 'Bandana Coral'),
    (code: 'none', label: 'Sem acessório'),
  ];

  @override
  Widget build(BuildContext context) {
    final dna = widget.dna;

    final tabs = dna.species == PetSpecies.dog
        ? [0, 2]
        : List.generate(_traitTabs.length, (i) => i);
    final selectedTab = tabs.contains(_selectedTraitTab)
        ? _selectedTraitTab
        : 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: RepaintBoundary(
                  key: widget.avatarPreviewKey,
                  child: AvatarView(dna: dna, size: 250, showBackdrop: false),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.onRandomize,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.primary, width: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                icon: const Text('🎲', style: TextStyle(fontSize: 16)),
                label: const Text(
                  'Aleatório',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Abas de categorias 100% centralizadas
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: tabs.map((index) {
              final selected = index == selectedTab;
              return ChoiceChip(
                label: Text(_traitTabs[index]),
                selected: selected,
                showCheckmark: false,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 2 : 1.5,
                ),
                labelStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                onSelected: (_) => setState(() => _selectedTraitTab = index),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Quadro organizado e centralizado para as opções da aba selecionada
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.surface.withValues(alpha: 0.22),
              width: 1.5,
            ),
          ),
          child: Center(child: _buildTraitOptions(dna, selectedTab)),
        ),
      ],
    );
  }

  Widget _buildTraitOptions(AvatarDna dna, int tab) {
    return switch (tab) {
      0 => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: AvatarDna.basePalette.map((item) {
          final selected = dna.baseColor == item.hex;
          return _ColorOptionChip(
            label: item.label,
            hex: item.hex,
            selected: selected,
            onTap: () => widget.onChanged(dna.copyWith(baseColor: item.hex)),
          );
        }).toList(),
      ),
      1 => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: FurPattern.values.map((pattern) {
          final selected = dna.pattern == pattern;
          return _TextOptionChip(
            label: pattern.label,
            selected: selected,
            onTap: () => widget.onChanged(dna.copyWith(pattern: pattern)),
          );
        }).toList(),
      ),
      2 => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: AvatarDna.patternPalette.map((item) {
          final selected = dna.patternColor == item.hex;
          return _ColorOptionChip(
            label: item.label,
            hex: item.hex,
            selected: selected,
            onTap: () => widget.onChanged(dna.copyWith(patternColor: item.hex)),
          );
        }).toList(),
      ),
      3 => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: EarStyle.values.map((ears) {
          final selected = dna.ears == ears;
          return _TextOptionChip(
            label: ears.label,
            selected: selected,
            onTap: () => widget.onChanged(dna.copyWith(ears: ears)),
          );
        }).toList(),
      ),
      4 => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: SnoutStyle.values.map((snout) {
          final selected = dna.snout == snout;
          return _TextOptionChip(
            label: snout.label,
            selected: selected,
            onTap: () => widget.onChanged(dna.copyWith(snout: snout)),
          );
        }).toList(),
      ),
      5 => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: EyeStyle.values.map((eyes) {
          final selected = dna.eyes == eyes;
          return _TextOptionChip(
            label: eyes.label,
            selected: selected,
            onTap: () => widget.onChanged(dna.copyWith(eyes: eyes)),
          );
        }).toList(),
      ),
      _ => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: _accessoryOptions.map((item) {
          final current = dna.accessory ?? 'none';
          final selected = current == item.code;
          return _TextOptionChip(
            label: item.label,
            selected: selected,
            onTap: () => widget.onChanged(dna.copyWith(accessory: item.code)),
          );
        }).toList(),
      ),
    };
  }
}

class _ColorOptionChip extends StatelessWidget {
  const _ColorOptionChip({
    required this.label,
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  Color _parseHex(String hexColor) {
    final clean = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _parseHex(hex),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textPrimary, width: 1.5),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextOptionChip extends StatelessWidget {
  const _TextOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
