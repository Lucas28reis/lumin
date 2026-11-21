import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rive/rive.dart' as rive;

import '../../../core/theme/app_theme.dart';
import '../domain/avatar_dna.dart';
import '../domain/avatar_mood.dart';

/// Avatar Vetorial Rive (`assets/pets/LuminProduction.riv`) com DataBind do ViewModel.
///
/// Sincroniza em tempo real as propriedades de `AvatarDna` (`baseColor`,
/// `patternColor`, `secondaryColor`, `accessoryColor`, `pattern`, `ears`,
/// `eyes`, `snout`, `accessory`) com o ViewModel `Fundo` nos artboards
/// `GoldenRoot` (cachorro) e `CatArtboard` (gato), além de:
/// - **Olhar (Eye-tracking):** Acompanha suavemente o cursor/dedo.
/// - **Toque (Tap):** Pulo elástico com *squash & stretch*, abano e `"AU AU! 🐾"`.
/// - **Carinho (Arrastar):** Corações flutuando ao acariciar.
class AvatarView extends StatefulWidget {
  const AvatarView({
    super.key,
    required this.dna,
    this.mood = AvatarMood.happy,
    this.size = 200,
    this.showBackdrop = true,
    this.interactive = true,
    this.onReady,
  });

  final AvatarDna dna;
  final AvatarMood mood;
  final double size;
  final bool showBackdrop;
  final bool interactive;
  final VoidCallback? onReady;

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView> with TickerProviderStateMixin {
  static rive.File? _cachedRiveFile;

  late final AnimationController _actionController;
  late final AnimationController _breathController;

  Offset _targetLook = Offset.zero;
  Offset _smoothedLook = Offset.zero;
  bool _isBeingPetted = false;
  int _barkCount = 0;

  rive.File? _riveFile;
  rive.RiveWidgetController? _riveController;
  rive.ViewModelInstance? _riveViewModel;

  @override
  void initState() {
    super.initState();
    _actionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addListener(_stepPointerSmoothing);

    final cached = _cachedRiveFile;
    if (cached != null) {
      _riveFile = cached;
      _bindRiveArtboardForSpecies(cached, notify: false);
    } else {
      _tryLoadCompiledRiv();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreathingLoop();
  }

  @override
  void didUpdateWidget(covariant AvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dna.species != widget.dna.species && _riveFile != null) {
      _bindRiveArtboardForSpecies(_riveFile!);
    } else if (oldWidget.dna != widget.dna || oldWidget.mood != widget.mood) {
      _syncRiveViewModel();
    }
    if (oldWidget.mood != widget.mood &&
        widget.mood == AvatarMood.celebrating) {
      _triggerBarkOrMeow();
    }
  }

  @override
  void dispose() {
    _actionController.dispose();
    _breathController.dispose();
    _riveViewModel?.dispose();
    _riveController?.dispose();
    super.dispose();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _syncBreathingLoop() {
    if (_reduceMotion) {
      _breathController.stop();
      _breathController.value = 0;
    } else if (!_breathController.isAnimating) {
      _breathController.repeat(reverse: true);
    }
  }

  void _stepPointerSmoothing() {
    final delta = _targetLook - _smoothedLook;
    if (delta.distanceSquared < 0.0001) return;
    const k = 0.16;
    setState(() {
      _smoothedLook = Offset(
        _smoothedLook.dx + delta.dx * k,
        _smoothedLook.dy + delta.dy * k,
      );
    });
  }

  Future<void> _tryLoadCompiledRiv() async {
    try {
      final data = await rootBundle.load('assets/pets/LuminProduction.riv');
      final file = await rive.File.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        riveFactory: rive.Factory.rive,
      );
      if (file == null) return;
      if (!mounted) {
        file.dispose();
        return;
      }
      final cached = _cachedRiveFile;
      if (cached != null) file.dispose();
      _riveFile = _cachedRiveFile = cached ?? file;
      _bindRiveArtboardForSpecies(_riveFile!);
    } catch (error) {
      debugPrint('Falha ao carregar o avatar LuminProduction: $error');
    }
  }

  void _bindRiveArtboardForSpecies(rive.File file, {bool notify = true}) {
    _riveViewModel?.dispose();
    _riveController?.dispose();

    final isCat = widget.dna.species == PetSpecies.cat;
    final controller = rive.RiveWidgetController(
      file,
      artboardSelector: rive.ArtboardSelector.byName(
        isCat ? 'CatArtboard' : 'GoldenRoot',
      ),
    );

    rive.ViewModelInstance? vmi;
    try {
      vmi = controller.dataBind(rive.DataBind.auto());
    } catch (_) {
      // O arquivo .riv pode usar as cores salvas direto no Artboard sem DataBind
    }

    if (!mounted) return;
    if (notify) {
      setState(() {
        _riveController = controller;
        _riveViewModel = vmi;
      });
    } else {
      _riveController = controller;
      _riveViewModel = vmi;
    }
    _syncRiveViewModel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady?.call();
    });
  }

  static Color _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  void _syncRiveViewModel() {
    final vmi = _riveViewModel;
    if (vmi == null) return;
    final dna = widget.dna;

    final baseCol = _parseHex(dna.baseColor);
    final patCol = _parseHex(
      dna.pattern == FurPattern.solid ? dna.baseColor : dna.patternColor,
    );
    final secCol = switch (dna.pattern) {
      FurPattern.solid => baseCol,
      _ => patCol,
    };
    final accCol = switch (dna.accessory) {
      'bandana' => const Color(0xFFE85D4A),
      _ => const Color(0xFF589686),
    };

    vmi.color('baseColor')?.value = baseCol;
    vmi.color('patternColor')?.value = dna.species == PetSpecies.dog
        ? _parseHex(dna.patternColor)
        : patCol;
    vmi.color('secondaryColor')?.value = secCol;
    vmi.color('accessoryColor')?.value = accCol;

    vmi.number('accessoryOpacity')?.value =
        (dna.accessory == null || dna.accessory == 'none') ? 0.0 : 1.0;
    vmi.number('patternOpacity')?.value = dna.pattern == FurPattern.solid
        ? 0.0
        : 1.0;

    // Focinho (Curto / Clássico / Bigodudo)
    final (snoutSX, snoutSY, dogWhiskers, catWhiskers) = switch (dna.snout) {
      SnoutStyle.short => (0.86, 0.92, 0.0, 0.35),
      SnoutStyle.medium => (1.10, 1.06, 0.0, 1.0),
      SnoutStyle.whiskers => (1.22, 1.12, 1.0, 1.0),
    };
    // Cat mouth paths use artboard coordinates. Scaling their parent about zero
    // moves the whole mouth away from the nose. Whisker opacity still varies.
    vmi.number('snoutScaleX')?.value = dna.species == PetSpecies.cat
        ? 1.0
        : snoutSX;
    vmi.number('snoutScaleY')?.value = snoutSY;
    vmi.number('dogWhiskersOpacity')?.value = dogWhiskers;
    vmi.number('catWhiskersOpacity')?.value = catWhiskers;

    // Orelhas (Caídas / Pontudas / Redondinhas)
    final (
      dogEarSX,
      dogEarSY,
      dogEarR,
      catEarSX,
      catEarSY,
      catEarR,
    ) = switch (dna.ears) {
      EarStyle.floppy => (1.10, 1.70, 0.0, 1.05, 0.78, -0.28),
      EarStyle.pointed => (0.88, 1.15, 0.42, 1.0, 1.05, 0.0),
      EarStyle.round => (1.32, 1.25, 0.12, 1.18, 0.76, 0.08),
    };
    vmi.number('dogEarScaleX')?.value = dogEarSX;
    vmi.number('dogEarScaleY')?.value = dogEarSY;
    final sad =
        widget.mood == AvatarMood.worried ||
        widget.mood == AvatarMood.hungry ||
        widget.mood == AvatarMood.bored;
    vmi.number('dogEarRot')?.value = dogEarR + (sad ? -0.18 : 0);
    vmi.number('catEarScaleX')?.value = catEarSX;
    vmi.number('catEarScaleY')?.value = catEarSY;
    vmi.number('catEarRot')?.value = catEarR + (sad ? -0.22 : 0);

    // Olhos (Redondos / Brilhantes / Amendoados)
    final (eyeSX, eyeSY, pupilOp) = switch (dna.eyes) {
      EyeStyle.round => (1.32, 0.85, 0.0),
      EyeStyle.sparkle => (1.0, 1.0, 1.0),
      EyeStyle.almond => (1.15, 0.68, 1.0),
    };
    vmi.number('eyeScaleX')?.value = eyeSX;
    vmi.number('eyeScaleY')?.value = eyeSY;
    vmi.number('pupilOpacity')?.value = pupilOp;
  }

  void _triggerBarkOrMeow() {
    if (!widget.interactive) return;
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    _riveViewModel?.trigger('barkTrigger')?.trigger();
    setState(() => _barkCount++);
    _actionController.forward(from: 0);
  }

  void _updateLook(Offset localPos) {
    if (!widget.interactive) return;
    final half = widget.size / 2;
    final next = Offset(
      ((localPos.dx - half) / half).clamp(-1.0, 1.0),
      ((localPos.dy - half) / half).clamp(-1.0, 1.0),
    );
    setState(() {
      _targetLook = next;
      if (_reduceMotion) {
        _smoothedLook = next;
      }
    });
  }

  void _resetLook() {
    if (!mounted) return;
    setState(() {
      _targetLook = Offset.zero;
      if (_reduceMotion) {
        _smoothedLook = Offset.zero;
      }
      _isBeingPetted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final isCat = widget.dna.species == PetSpecies.cat;
    final barkLabel = isCat ? 'MIAU! 🐾' : 'AU AU! 🐾';
    final riveCtrl = _riveController;

    return MouseRegion(
      cursor: widget.interactive
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onHover: (e) => _updateLook(e.localPosition),
      onExit: (_) => _resetLook(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _triggerBarkOrMeow,
        onPanStart: (d) {
          if (!widget.interactive) return;
          HapticFeedback.selectionClick();
          setState(() => _isBeingPetted = true);
          _updateLook(d.localPosition);
        },
        onPanUpdate: (d) => _updateLook(d.localPosition),
        onPanEnd: (_) => _resetLook(),
        onPanCancel: _resetLook,
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_actionController, _breathController]),
            builder: (context, _) {
              final t = _actionController.value;
              final acting = _actionController.isAnimating;
              final breath = _breathController.value;
              final showOverlay = acting || _isBeingPetted;

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  RepaintBoundary(
                    child: Transform.translate(
                      offset: Offset(
                        _smoothedLook.dx * size * 0.02,
                        _smoothedLook.dy * size * 0.015,
                      ),
                      child: riveCtrl != null
                          ? rive.RiveWidget(
                              controller: riveCtrl,
                              fit: rive.Fit.contain,
                            )
                          : SizedBox.square(
                              dimension: size,
                              child: const Center(
                                child: Icon(Icons.pets, size: 64),
                              ),
                            ),
                    ),
                  ),

                  if (showOverlay)
                    ..._buildFloatingHearts(size, acting ? t : breath),

                  if (showOverlay)
                    Positioned(
                      top: -4 - (acting ? t * 14 : 0),
                      right: 4,
                      child: Opacity(
                        opacity: _isBeingPetted
                            ? 1.0
                            : (1.0 - t).clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            _isBeingPetted ? '❤️ Carinho!' : barkLabel,
                            key: ValueKey<int>(_barkCount),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFloatingHearts(double size, double t) {
    const xs = [0.18, 0.78];
    return List.generate(xs.length, (i) {
      final local = ((t + i * 0.25) % 1.0).clamp(0.0, 1.0);
      return Positioned(
        left: size * xs[i],
        top: size * 0.24 - local * size * 0.22,
        child: Opacity(
          opacity: (1.0 - local).clamp(0.0, 1.0),
          child: Text('❤️', style: TextStyle(fontSize: size * 0.085)),
        ),
      );
    });
  }
}
