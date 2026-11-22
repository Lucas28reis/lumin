import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lumin_app/app/app.dart';
import 'package:lumin_app/core/clock/clock.dart';
import 'package:lumin_app/core/providers/core_providers.dart';
import 'package:lumin_app/features/avatar/domain/avatar_dna.dart';
import 'package:lumin_app/features/avatar/domain/avatar_mood.dart';
import 'package:lumin_app/features/avatar/domain/mood_resolver.dart';
import 'package:lumin_app/features/avatar/presentation/avatar_view.dart';
import 'package:lumin_app/features/care/domain/care_slot.dart';
import 'package:lumin_app/features/care/domain/periodic_care.dart';
import 'package:lumin_app/features/care/presentation/routine_calendar.dart';
import 'package:lumin_app/features/onboarding/domain/onboarding_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Calendário prevê cuidados coincidentes no mês seguinte', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(FixedClock(DateTime(2026, 11, 22, 12))),
    ], child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: RoutineCalendar(changes: {
        'bath': PeriodicCare('2026-11-27', '09:00', 15),
        'medication': PeriodicCare('2026-11-22', '07:00', 1),
      }),
    )))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    expect(find.text('Banho · Previsto · 09:00'), findsOneWidget);
    expect(find.text('Remédio · Previsto · 07:00'), findsOneWidget);
  });

  group('Domínio: MoodResolver & AvatarDna (🐛 QA + ⚖️ Tech Lead)', () {
    test('Respeita a ordem estrita de prioridade de humor do Avatar', () {
      final now = DateTime(2026, 11, 16, 10, 0);

      // 1. Celebrating nos primeiros 5 segundos sobrepõe qualquer atraso
      expect(
        MoodResolver.resolve(
          now: now,
          lastCareLoggedAt: now.subtract(const Duration(seconds: 3)),
          todayFeedSlots: const [(hour: 8, minute: 0, isDone: false)],
          todayWalkSlots: const [],
          hasOverdueIntervalTask: true,
        ),
        AvatarMood.celebrating,
      );

      // 2. Hungry quando refeição atrasa > 30 min
      expect(
        MoodResolver.resolve(
          now: now,
          todayFeedSlots: const [(hour: 8, minute: 0, isDone: false)],
          todayWalkSlots: const [],
          hasOverdueIntervalTask: true,
        ),
        AvatarMood.hungry,
      );

      // 3. Worried quando tarefa de intervalo vence hoje
      expect(
        MoodResolver.resolve(
          now: now,
          todayFeedSlots: const [(hour: 8, minute: 0, isDone: true)],
          todayWalkSlots: const [],
          hasOverdueIntervalTask: true,
        ),
        AvatarMood.worried,
      );

      // 4. Bored quando passeio atrasa > 60 min
      expect(
        MoodResolver.resolve(
          now: now,
          todayFeedSlots: const [(hour: 8, minute: 0, isDone: true)],
          todayWalkSlots: const [(hour: 8, minute: 30, isDone: false)],
          hasOverdueIntervalTask: false,
        ),
        AvatarMood.bored,
      );

      // 5. Sleepy entre 22h e 06h sem pendências
      expect(
        MoodResolver.resolve(
          now: DateTime(2026, 11, 16, 23, 15),
          todayFeedSlots: const [(hour: 8, minute: 0, isDone: true)],
          todayWalkSlots: const [],
          hasOverdueIntervalTask: false,
        ),
        AvatarMood.sleepy,
      );

      // 6. Happy por padrão
      expect(
        MoodResolver.resolve(
          now: now,
          todayFeedSlots: const [(hour: 8, minute: 0, isDone: true)],
          todayWalkSlots: const [],
          hasOverdueIntervalTask: false,
        ),
        AvatarMood.happy,
      );
    });

    test('AvatarDna inclui chave "v" obrigatória para o schema PostgreSQL', () {
      final dna = AvatarDna.initial(species: PetSpecies.cat);
      final json = dna.toJson();
      expect(json.containsKey('v'), isTrue);
      expect(json['v'], 1);
      expect(AvatarDna.fromJson(json), equals(dna));
    });

    test(
      'OnboardingDraft agenda cuidado esquecível para hoje quando "Não lembro"',
      () {
        final now = DateTime(2026, 11, 16, 14, 0);
        final draft = OnboardingDraft.initial().copyWith(
          petName: 'Paçoca',
          forgettableCare: const {
            ForgettableCareType.fleaTick: LastDoneRecency.dontRemember,
          },
        );
        final payload = draft.toRpcPayload(now: now);
        final tasks = payload['tasks'] as List<Map<String, Object?>>;
        final fleaTask = tasks.firstWhere((t) => t['type'] == 'flea_tick');
        expect(fleaTask['next_due_date'], '2026-11-16');
      },
    );

    test('Antipulgas preserva a data e a frequência ao reabrir', () {
      final draft = OnboardingDraft.initial().copyWith(
        fleaLastDate: DateTime(2026, 11, 25),
        fleaIntervalDays: 15,
      );
      final restored = OnboardingDraft.fromJson(draft.toJson());
      final tasks =
          restored.toRpcPayload(now: DateTime(2026, 12, 1))['tasks']
              as List<Map<String, Object?>>;
      final task = tasks.singleWhere((item) => item['type'] == 'flea_tick');
      expect(task['next_due_date'], '2026-12-10');
      expect(task['interval_days'], 15);
    });

    test('NextSlotResolver retorna o primeiro slot pendente', () {
      const slots = [
        CareSlotItem(
          id: '1',
          taskId: 't1',
          slotIndex: 0,
          kind: CareSlotKind.dailyFeed,
          title: 'Café',
          subtitle: '1/2',
          emoji: '🍖',
          isDone: true,
        ),
        CareSlotItem(
          id: '2',
          taskId: 't1',
          slotIndex: 1,
          kind: CareSlotKind.dailyFeed,
          title: 'Jantar',
          subtitle: '2/2',
          emoji: '🍖',
          isDone: false,
        ),
      ];
      expect(NextSlotResolver.resolveNextPending(slots)?.id, '2');
    });
  });

  testWidgets('Fluxo completo do Onboarding (Passos 0..6) até a Home', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fixedClock = FixedClock(DateTime(2026, 11, 16, 9, 0));

    // Reduz movimento: desliga a respiração em loop do avatar (senão o
    // pumpAndSettle nunca termina). Também valida o respeito à acessibilidade.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(fixedClock),
        ],
        child: const LuminApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Passo 0: Boas-vindas
    expect(
      find.text('Todo pet merece uma família organizada 🐾'),
      findsOneWidget,
    );
    await tester.tap(find.text('Começar agora'));
    await tester.pumpAndSettle();

    // Passo 1: Espécie + Nome do Pet
    expect(find.text('Quem é o dono do seu coração?'), findsOneWidget);
    await tester.tap(find.text('Fêmea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Luma');
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Vamos desenhar a Luma!'), findsOneWidget);
    await tester.tap(find.text('É a Luma!'));
    await tester.pumpAndSettle();

    // Passo 3: Rotina diária
    expect(find.text('Qual a rotina da Luma?'), findsOneWidget);
    await tester.tap(find.text('Personalizar'));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar refeição'), findsOneWidget);
    await tester.tap(find.text('08:00'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(TimePickerDialog))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Passo 4: Cuidados esquecíveis
    expect(find.text('Os cuidados que todo mundo esquece 😅'), findsOneWidget);
    await tester.tap(find.text('Selecionar última aplicação'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar e continuar'));
    await tester.pumpAndSettle();

    // Passo 5: Convite da família
    expect(find.text('Quem mais cuida da Luma?'), findsOneWidget);
    await tester.tap(find.text('Cuido sozinho(a) por enquanto'));
    await tester.pumpAndSettle();

    // Passo 6: Pre-prompt de notificações
    expect(
      find.text('Quer que eu te avise se a Luma ficar com fome?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Sim, me avise!'));
    await tester.pumpAndSettle();

    if (find.text('Fechar').evaluate().isNotEmpty) {
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Família'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar nome'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Luiza');
    await tester.tap(find.text('Salvar nome'));
    await tester.pumpAndSettle();
    expect(find.text('Luiza'), findsOneWidget);
    expect(find.text('Pagamentos e compras'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('07:30'), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('07:30'));
    expect(find.text('07:30'), findsWidgets);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('18:30'), findsOneWidget);
    await tester.drag(find.text('Rotina de hoje'), const Offset(0,-300));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Próximos cuidados'));
    await tester.pumpAndSettle();
    expect(find.text('19:00'), findsOneWidget);
    for (final destination in [
      ('Missões', 'Ranking de ofensivas'),
      ('Loja', 'Loja de cenários'),
      ('Rotina', 'Horários dos passeios'),
      ('Prontuário', 'Histórico de saúde'),
      ('Ração', 'Estoque de ração'),
      ('Estilo', 'Nome do pet'),
    ]) {
      await tester.tap(find.text(destination.$1));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      if (destination.$1 == 'Rotina') {
        expect(find.byTooltip('Mês anterior'), findsOneWidget);
        await tester.scrollUntilVisible(find.text(destination.$2), 200,
            scrollable: find.byType(Scrollable).first);
      }
      expect(find.text(destination.$2), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('AvatarView 3D sentado reage ao toque com latido/miado', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarView(
            dna: AvatarDna.initial(species: PetSpecies.dog),
            mood: AvatarMood.happy,
            size: 180,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AvatarView));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('AU AU! 🐾'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}

