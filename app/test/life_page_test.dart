import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lumin_app/core/providers/core_providers.dart';
import 'package:lumin_app/core/clock/clock.dart';
import 'package:lumin_app/core/theme/app_theme.dart';
import 'package:lumin_app/features/life/domain/pet_life.dart';
import 'package:lumin_app/features/life/presentation/life_controller.dart';
import 'package:lumin_app/features/life/presentation/life_page.dart';

void main() {
  testWidgets('Vida do pet em tela pequena mostra estoque e permite editar', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final font = File(
        '../flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
      );
      if (await font.exists()) {
        final loader = FontLoader('Roboto')
          ..addFont(font.readAsBytes().then((b) => ByteData.sublistView(b)));
        await loader.load();
      }
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 19, 12))),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(lifeControllerProvider.notifier)
        .saveFood(
          FoodPlan(
            kilograms: 20,
            gramsPerMeal: 200,
            mealsPerDay: 2,
            openedOn: DateTime(2026, 10, 15),
          ),
        );
    await container
        .read(lifeControllerProvider.notifier)
        .saveRecord(
          HealthRecord(
            id: 'vet',
            kind: HealthKind.vet,
            title: 'Consulta de rotina',
            date: DateTime(2026, 10, 19),
            notes: 'Avaliação registrada pelo tutor',
            nextDate: DateTime(2026, 11, 19),
          ),
        );
    final preview = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(key: preview, child: const LifePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('6.0 kg estimados'), findsOneWidget);
    expect(find.text('30 refeições • 15.0 dias'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          preview.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File('build/life_page_preview.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
    await tester.tap(find.text('Atualizar estoque / novo saco'));
    await tester.pumpAndSettle();
    for (final label in [
      'Ração em estoque',
      'Porção por refeição',
      'Refeições por dia',
      'Avisar quando restarem',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Data do estoque · 15/10/2026'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '25');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('11.0 kg estimados'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
