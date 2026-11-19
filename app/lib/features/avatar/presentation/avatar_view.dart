import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rive/rive.dart' as rive;

import '../../../core/theme/app_theme.dart';
import '../domain/avatar_dna.dart';
import '../domain/avatar_mood.dart';
import 'flat_pet_paths.dart';

/// Avatar Vetorial Flat/Line-Art (fiel à ilustração de referência) + Rive Runtime.
///
/// Desenha os polígonos vetoriais suavizados extraídos da arte de referência
/// (`FlatPetVectorData` / `rive_pets/scene.rml`), permitindo customização em
/// tempo real de todas as cores e acessórios (`baseColor`, `patternColor`,
/// `pattern`, `ears`, `eyes`, `accessory`), além de:
/// - **Olhar (Eye-tracking):** Os olhinhos acompanham suavemente o cursor/dedo.
/// - **Toque (Tap):** Pulo elástico com *squash & stretch*, abano e `"AU AU! 🐾"`.
/// - **Carinho (Arrastar):** Olhos fechados felizes e corações subindo.
class AvatarView extends StatefulWidget {
  const AvatarView({
    super.key,
    required this.dna,
    this.mood = AvatarMood.happy,
    this.size = 200,
    this.showBackdrop = true,
    this.interactive = true,
  });

  final AvatarDna dna;
  final AvatarMood mood;
  final double size;
  final bool showBackdrop;
  final bool interactive;

  @override
  State<AvatarView> createState() => _AvatarViewState();
}

class _AvatarViewState extends State<AvatarView>
    with TickerProviderStateMixin {
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

    _tryLoadCompiledRiv();
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
    _riveFile?.dispose();
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
    for (final assetPath in const [
      'assets/pets/lumin_pet.riv',
      'assets/pets/lumin_pets.riv',
    ]) {
      try {
        final data = await rootBundle.load(assetPath);
        if (!mounted || data.lengthInBytes == 0) continue;
        final file = await rive.File.decode(
          data.buffer.asUint8List(),
          riveFactory: rive.Factory.rive,
        );
        if (!mounted || file == null) continue;
        _riveFile = file;
        _bindRiveArtboardForSpecies(file);
        return;
      } catch (_) {
        // Tenta o próximo caminho ou usa o fallback vetorial
      }
    }
  }

  void _bindRiveArtboardForSpecies(rive.File file) {
    _riveViewModel?.dispose();
    _riveController?.dispose();

    final isCat = widget.dna.species == PetSpecies.cat;
    rive.RiveWidgetController controller;
    try {
      controller = rive.RiveWidgetController(
        file,
        artboardSelector: rive.ArtboardSelector.byName(
          isCat ? 'CatArtboard' : 'Artboard 1',
        ),
      );
    } catch (_) {
      controller = rive.RiveWidgetController(file);
    }

    rive.ViewModelInstance? vmi;
    try {
      vmi = controller.dataBind(rive.DataBind.auto());
    } catch (_) {
      // O arquivo .riv pode usar as cores salvas direto no Artboard sem DataBind
    }

    if (!mounted) return;
    setState(() {
      _riveController = controller;
      _riveViewModel = vmi;
    });
    _syncRiveViewModel();
  }

  void _syncRiveViewModel() {
    final vmi = _riveViewModel;
    if (vmi == null) return;
    final dna = widget.dna;

    final baseCol = _FlatVectorPetPainter.parseHex(dna.baseColor);
    final patCol = _FlatVectorPetPainter.parseHex(
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
    vmi.color('patternColor')?.value = patCol;
    vmi.color('secondaryColor')?.value = secCol;
    vmi.color('accessoryColor')?.value = accCol;

    vmi.number('accessoryOpacity')?.value =
        (dna.accessory == null || dna.accessory == 'none') ? 0.0 : 1.0;
    vmi.number('patternOpacity')?.value =
        dna.pattern == FurPattern.solid ? 0.0 : 1.0;

    // Focinho (Curto / Clássico / Bigodudo)
    final (snoutSX, snoutSY, dogWhiskers, catWhiskers) = switch (dna.snout) {
      SnoutStyle.short => (0.86, 0.92, 0.0, 0.35),
      SnoutStyle.medium => (1.10, 1.06, 0.0, 1.0),
      SnoutStyle.whiskers => (1.22, 1.12, 1.0, 1.0),
    };
    vmi.number('snoutScaleX')?.value = snoutSX;
    vmi.number('snoutScaleY')?.value = snoutSY;
    vmi.number('dogWhiskersOpacity')?.value = dogWhiskers;
    vmi.number('catWhiskersOpacity')?.value = catWhiskers;

    // Orelhas (Caídas / Pontudas / Redondinhas)
    final (dogEarSX, dogEarSY, dogEarR, catEarSX, catEarSY, catEarR) =
        switch (dna.ears) {
      EarStyle.floppy => (1.10, 1.70, 0.0, 1.05, 0.78, -0.28),
      EarStyle.pointed => (0.88, 1.15, 0.42, 1.0, 1.05, 0.0),
      EarStyle.round => (1.32, 1.25, 0.12, 1.18, 0.76, 0.08),
    };
    vmi.number('dogEarScaleX')?.value = dogEarSX;
    vmi.number('dogEarScaleY')?.value = dogEarSY;
    vmi.number('dogEarRot')?.value = dogEarR;
    vmi.number('catEarScaleX')?.value = catEarSX;
    vmi.number('catEarScaleY')?.value = catEarSY;
    vmi.number('catEarRot')?.value = catEarR;

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

              final jumpY =
                  acting ? -size * 0.055 * math.sin(math.pi * t) : 0.0;
              final wobble = acting ? math.sin(2 * math.pi * t) * (1 - t) : 0.0;
              final scaleY = 1.0 - 0.045 * wobble + 0.014 * breath;
              final scaleX = 1.0 + 0.035 * wobble - 0.008 * breath;

              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Sombra suave no chão
                  Positioned(
                    bottom: size * 0.03,
                    child: Container(
                      width: size *
                          (0.68 -
                              (acting ? 0.10 * math.sin(math.pi * t) : 0) -
                              0.02 * breath),
                      height: size * 0.055,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                    ),
                  ),

                  RepaintBoundary(
                    child: Transform.translate(
                      offset: Offset(
                        _smoothedLook.dx * size * 0.02,
                        jumpY + _smoothedLook.dy * size * 0.015,
                      ),
                      child: Transform(
                        alignment: Alignment.bottomCenter,
                        transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
                        child: riveCtrl != null
                            ? ClipRect(
                                child: Transform.scale(
                                  scale: 1.42,
                                  alignment: const Alignment(0.05, 0.78),
                                  child: rive.RiveWidget(
                                    controller: riveCtrl,
                                    fit: rive.Fit.contain,
                                  ),
                                ),
                              )
                            : CustomPaint(
                                size: Size.square(size),
                                painter: _FlatVectorPetPainter(
                                  dna: widget.dna,
                                  mood: widget.mood,
                                  lookOffset: _smoothedLook,
                                  isBlinkingOrPetted: _isBeingPetted ||
                                      widget.mood == AvatarMood.sleepy,
                                  isBarking: acting,
                                ),
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
                            border: Border.all(color: AppColors.primary, width: 1.5),
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
          child: Text(
            '❤️',
            style: TextStyle(fontSize: size * 0.085),
          ),
        ),
      );
    });
  }
}

class _FlatVectorPetPainter extends CustomPainter {
  _FlatVectorPetPainter({
    required this.dna,
    required this.mood,
    required this.lookOffset,
    required this.isBlinkingOrPetted,
    required this.isBarking,
  });

  final AvatarDna dna;
  final AvatarMood mood;
  final Offset lookOffset;
  final bool isBlinkingOrPetted;
  final bool isBarking;

  static Color parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  static Path _buildSmoothPolyPath(List<double> coords) {
    final path = Path();
    final count = coords.length ~/ 2;
    if (count < 3) return path;

    // Usa curvas quadráticas suaves entre os pontos médios (equivalente ao
    // `StraightVertex radius="..."` do Rive!)
    double midX(int i, int j) => (coords[i * 2] + coords[j * 2]) * 0.5;
    double midY(int i, int j) => (coords[i * 2 + 1] + coords[j * 2 + 1]) * 0.5;

    path.moveTo(midX(count - 1, 0), midY(count - 1, 0));
    for (var i = 0; i < count; i++) {
      final next = (i + 1) % count;
      path.quadraticBezierTo(
        coords[i * 2],
        coords[i * 2 + 1],
        midX(i, next),
        midY(i, next),
      );
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 500.0;
    canvas.save();
    canvas.scale(scale, scale);

    final baseColor = parseHex(dna.baseColor);
    final patternColor = dna.pattern == FurPattern.solid
        ? baseColor
        : parseHex(dna.patternColor);
    final accessoryColor = dna.accessory == 'bandana'
        ? const Color(0xFF2B8A6E)
        : const Color(0xFF5D8373); // Verde-sálvia da arte de referência

    // 1. Silhueta Base (Pêssego / baseColor)
    final bodyPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    for (final poly in FlatPetVectorData.dogBodyPolys) {
      canvas.drawPath(_buildSmoothPolyPath(poly), bodyPaint);
    }

    // Se Espécie = Gato, adiciona orelhinhas felinas pontudas e bigodes no mesmo estilo Flat
    if (dna.species == PetSpecies.cat) {
      final catEarPath = Path()
        ..moveTo(276, 102)
        ..lineTo(264, 42)
        ..lineTo(318, 72)
        ..close()
        ..moveTo(334, 68)
        ..lineTo(366, 26)
        ..lineTo(392, 74)
        ..close();
      canvas.drawPath(catEarPath, bodyPaint);
    }

    // 2. Manchas Orgânicas (Terracota / patternColor)
    final patternPaint = Paint()
      ..color = patternColor
      ..style = PaintingStyle.fill;
    for (var i = 0; i < FlatPetVectorData.dogPatternPolys.length; i++) {
      // No padrão `bicolor`, exibe a orelha, topete e mancha do peito; no `spots`, exibe todas
      if (dna.pattern == FurPattern.bicolor && i > 4) continue;
      canvas.drawPath(
        _buildSmoothPolyPath(FlatPetVectorData.dogPatternPolys[i]),
        patternPaint,
      );
    }

    // 3. Acessórios (Florzinha na orelha + Coleira verde-sálvia)
    if (dna.accessory != 'none') {
      final accPaint = Paint()
        ..color = accessoryColor
        ..style = PaintingStyle.fill;
      for (var i = 0; i < FlatPetVectorData.dogAccessoryPolys.length; i++) {
        // Se for `bandana`, oculta a florzinha do topo (i == 1) e mantém só a coleira
        if (dna.accessory == 'bandana' && i == 1) continue;
        canvas.drawPath(
          _buildSmoothPolyPath(FlatPetVectorData.dogAccessoryPolys[i]),
          accPaint,
        );
      }
    }

    // 4. Contornos e Detalhes Pretos (Olhos com Eye-Tracking, Nariz, Sorriso, Pernas, Rabo)
    final strokePaint = Paint()
      ..color = const Color(0xFF0D0D0D)
      ..style = PaintingStyle.fill;

    for (final poly in FlatPetVectorData.dogStrokePolys) {
      // Calcula centroide rápido para saber se é um dos 2 olhos (x: 330..405, y: 120..155)
      var sumX = 0.0;
      var sumY = 0.0;
      final n = poly.length ~/ 2;
      for (var k = 0; k < n; k++) {
        sumX += poly[k * 2];
        sumY += poly[k * 2 + 1];
      }
      final cx = sumX / n;
      final cy = sumY / n;
      final isEye = cx >= 330 && cx <= 408 && cy >= 120 && cy <= 154 && n <= 16;

      if (isEye) {
        canvas.save();
        canvas.translate(lookOffset.dx * 5.0, lookOffset.dy * 3.5);
        if (isBlinkingOrPetted) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(cx, cy), width: 14, height: 3.5),
              const Radius.circular(2),
            ),
            strokePaint,
          );
        } else {
          canvas.drawPath(_buildSmoothPolyPath(poly), strokePaint);
          if (dna.eyes == EyeStyle.sparkle) {
            canvas.drawCircle(
              Offset(cx - 1.5, cy - 2.5),
              2.2,
              Paint()..color = Colors.white,
            );
          }
        }
        canvas.restore();
      } else {
        canvas.drawPath(_buildSmoothPolyPath(poly), strokePaint);
      }
    }

    // Bigodes se for gato ou estilo bigodudo
    if (dna.species == PetSpecies.cat || dna.snout == SnoutStyle.whiskers) {
      final whiskerPaint = Paint()
        ..color = const Color(0xFF0D0D0D)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        const Offset(396, 168),
        const Offset(432, 162),
        whiskerPaint,
      );
      canvas.drawLine(
        const Offset(396, 176),
        const Offset(430, 178),
        whiskerPaint,
      );
    }

    // Língua rosada fofa quando latindo (`isBarking`)
    if (isBarking) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(354, 174, 16, 18),
          const Radius.circular(8),
        ),
        Paint()..color = const Color(0xFFE86F7C),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlatVectorPetPainter oldDelegate) {
    return oldDelegate.dna != dna ||
        oldDelegate.mood != mood ||
        oldDelegate.lookOffset != lookOffset ||
        oldDelegate.isBlinkingOrPetted != isBlinkingOrPetted ||
        oldDelegate.isBarking != isBarking;
  }
}
