import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

const lagoon = Color(0xff127b79);
const ink = Color(0xff332b28);

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.tint = Colors.white,
    this.borderColor = const Color(0xd9ffffff),
  });
  final Widget child;
  final EdgeInsets padding;
  final Color tint;
  final Color borderColor;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: const Color(0xff916d51).withValues(alpha: .09),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withValues(alpha: .92),
                tint.withValues(alpha: .66),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    ),
  );
}

class DayProgress extends StatelessWidget {
  const DayProgress({super.key, required this.done, required this.total});
  final int done, total;
  @override
  Widget build(BuildContext context) => GlassPanel(
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: total == 0 ? 0 : done / total),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Row(
        children: [
          SizedBox.square(
            dimension: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: value,
                    color: lagoon,
                    backgroundColor: const Color(0xffd7e9e1),
                    strokeWidth: 4.5,
                  ),
                ),
                const Icon(Icons.pets, color: lagoon, size: 18),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Progresso do dia',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ),
                    Text(
                      '${(value * 100).round()}%',
                      style: const TextStyle(
                        color: lagoon,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                  color: lagoon,
                  backgroundColor: const Color(0xffdfebe6),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class CelebrationPainter extends CustomPainter {
  CelebrationPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;
  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t <= 0 || t >= 1) return;
    const colors = [
      Color(0xff19c5b9),
      Color(0xfffa823e),
      Color(0xffffbf37),
      Color(0xffc464a6),
    ];
    final paint = Paint();
    for (var i = 0; i < 52; i++) {
      final phase = (i * 137 % 360) * math.pi / 180;
      final x =
          size.width * (.5 + math.cos(phase) * t * (.22 + (i % 9) * .065));
      final y = size.height * (.45 - math.sin(phase) * t * .60 + t * t * .43);
      paint.color = colors[i % 4].withValues(alpha: 1 - t);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(phase + t * 4);
      if (i % 4 == 0) {
        final path = Path();
        for (var k = 0; k < 10; k++) {
          final a = k * math.pi / 5, r = k.isEven ? 7.0 : 3.0;
          if (k == 0) {
            path.moveTo(r, 0);
          } else {
            path.lineTo(math.cos(a) * r, math.sin(a) * r);
          }
        }
        canvas.drawPath(path..close(), paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-2, -4, 4, 9),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CelebrationPainter oldDelegate) =>
      animation != oldDelegate.animation;
}
