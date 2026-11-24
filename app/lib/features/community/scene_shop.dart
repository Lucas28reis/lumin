import 'dart:math' as math;

import 'package:rive/rive.dart' as rive;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/app_theme.dart';
import '../care/presentation/care_controller.dart';
import '../onboarding/presentation/onboarding_controller.dart';

enum PetScene {
  studio(
    'Estúdio de creme',
    0,
    Color(0xfffff5e5),
    Color(0xfff2dbba),
    Color(0xffe2bd88),
  ),
  meadow(
    'Jardim ao sol',
    0,
    Color(0xffbee5ef),
    Color(0xffa1ce91),
    Color(0xff71ac85),
  ),
  sunset(
    'Colinas ao entardecer',
    3,
    Color(0xffffcfad),
    Color(0xffdb9997),
    Color(0xffab7b90),
  ),
  night(
    'Noite estrelada',
    7,
    Color(0xff34436d),
    Color(0xff60698e),
    Color(0xff465779),
  ),
  starryBrush(
    'Céu de Van Gogh',
    0,
    Color(0xff213969),
    Color(0xff60698e),
    Color(0xff465779),
  ),
  mist(
    'Manhã de neblina',
    0,
    Color(0xffe1ebef),
    Color(0xffb6cbd0),
    Color(0xff98adbb),
  );

  const PetScene(this.label, this.days, this.sky, this.hills, this.ground);
  final String label;
  final int days;
  final Color sky, hills, ground;
}

class ScenePainter extends CustomPainter {
  ScenePainter(this.scene);
  final PetScene scene;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()..color = scene.sky;
    canvas.drawRect(Offset.zero & size, paint);
    if (scene != PetScene.studio) {
      paint.color = scene == PetScene.night
          ? const Color(0xfff9edd3)
          : const Color(0xffffebbc);
      canvas.drawCircle(Offset(w * .78, h * .24), math.min(w, h) * .10, paint);
      if (scene == PetScene.night) {
        for (var i = 1; i < 22; i++) {
          canvas.drawCircle(
            Offset(w * ((i * 37) % 100) / 100, h * ((i * 13) % 48) / 100),
            1.3,
            paint,
          );
        }
      }
    }
    for (var i = 0; i < 2; i++) {
      final y = h * (i == 0 ? 0.65 : 0.85);
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(w * .27, y - h * .21, w * .54, y - h * .02)
        ..quadraticBezierTo(w * .76, y + h * .10, w, y - h * .10)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(path, paint..color = i == 0 ? scene.hills : scene.ground);
    }
  }

  @override
  bool shouldRepaint(ScenePainter oldDelegate) => oldDelegate.scene != scene;
}

final _sceneFile = FutureProvider<rive.File?>((ref) async {
  final file = await rive.File.asset(
    'assets/scenes/LuminScenarios.riv',
    riveFactory: rive.Factory.rive,
  );
  if (!ref.mounted) {
    file?.dispose();
    return null;
  }
  ref.onDispose(() => file?.dispose());
  return file;
});

class SceneBackdrop extends ConsumerWidget {
  const SceneBackdrop(this.scene, {this.child, super.key});
  final PetScene scene;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(_sceneFile).asData?.value;
    return Stack(
      fit: child == null ? StackFit.expand : StackFit.loose,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: file == null
                ? CustomPaint(painter: ScenePainter(scene))
                : _SceneArtboard(
                    key: ValueKey(scene),
                    file: file,
                    scene: scene,
                  ),
          ),
        ),
        if (child != null) SizedBox(width: double.infinity, child: child),
      ],
    );
  }
}

class _SceneArtboard extends StatefulWidget {
  const _SceneArtboard({super.key, required this.file, required this.scene});
  final rive.File file;
  final PetScene scene;
  @override
  State<_SceneArtboard> createState() => _SceneArtboardState();
}

class _SceneArtboardState extends State<_SceneArtboard> {
  late final controller = rive.RiveWidgetController(
    widget.file,
    artboardSelector: rive.ArtboardSelector.byName(widget.scene.name),
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      rive.RiveWidget(controller: controller, fit: rive.Fit.cover);
}

class SceneStore extends Notifier<PetScene> {
  late String key;
  @override
  PetScene build() {
    final id = ref.watch(onboardingControllerProvider.select((s) => s.petId));
    key = 'lumin.scenes.${id ?? "draft"}';
    final current = ref
        .read(sharedPreferencesProvider)
        .getString('$key.selected');
    return PetScene.values.where((s) => s.name == current).firstOrNull ??
        PetScene.studio;
  }

  bool owned(PetScene s) =>
      s.days == 0 ||
      ref.read(sharedPreferencesProvider).getBool('$key.${s.name}') == true;
  Future<void> equip(PetScene s) async {
    if (!owned(s) && ref.read(careControllerProvider).streakDays < s.days)
      return;
    final prefs = ref.read(sharedPreferencesProvider);
    if (!owned(s) && !await prefs.setBool('$key.${s.name}', true))
      throw StateError('Falha ao liberar cenário');
    if (!await prefs.setString('$key.selected', s.name))
      throw StateError('Falha ao salvar cenário');
    state = s;
  }
}

final sceneProvider = NotifierProvider<SceneStore, PetScene>(SceneStore.new);

class SceneShop extends ConsumerStatefulWidget {
  const SceneShop({super.key});
  @override
  ConsumerState<SceneShop> createState() => _SceneShopState();
}

class _SceneShopState extends ConsumerState<SceneShop> {
  late int index;
  late final PageController pages;
  @override
  void initState() {
    super.initState();
    index = ref.read(sceneProvider).index;
    pages = PageController(initialPage: index);
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  void move(int delta) => pages.animateToPage(
    index + delta,
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOut,
  );
  @override
  Widget build(BuildContext context) {
    final s = PetScene.values[index];
    final selected = ref.watch(sceneProvider);
    final store = ref.read(sceneProvider.notifier);
    final days = ref.watch(careControllerProvider.select((c) => c.streakDays));
    return Scaffold(
      appBar: AppBar(title: const Text('Loja')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Sua ofensiva: $days ${days == 1 ? "dia" : "dias"}',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: AppColors.onBackground),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cenários',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cenário anterior',
                    onPressed: index > 0 ? () => move(-1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${index + 1} de ${PetScene.values.length}'),
                  IconButton(
                    tooltip: 'Próximo cenário',
                    onPressed: index + 1 < PetScene.values.length
                        ? () => move(1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 2,
                      child: PageView.builder(
                        controller: pages,
                        onPageChanged: (value) => setState(() => index = value),
                        itemCount: PetScene.values.length,
                        itemBuilder: (context, i) =>
                            SceneBackdrop(PetScene.values[i]),
                      ),
                    ),
                    ListTile(
                      title: Text(s.label),
                      subtitle: Text(
                        store.owned(s)
                            ? (s.days == 0 ? 'Grátis' : 'Na sua coleção')
                            : 'Ofensiva de ${s.days} dias',
                      ),
                      trailing: FilledButton(
                        onPressed:
                            selected == s || (!store.owned(s) && days < s.days)
                            ? null
                            : () async {
                                try {
                                  await store.equip(s);
                                } catch (_) {
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Não foi possível salvar o cenário.',
                                        ),
                                      ),
                                    );
                                }
                              },
                        child: Text(
                          selected == s
                              ? 'Em uso'
                              : store.owned(s)
                              ? 'Usar'
                              : days >= s.days
                              ? 'Resgatar'
                              : 'Bloqueado',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
