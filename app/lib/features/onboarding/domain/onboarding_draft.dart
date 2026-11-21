import '../../avatar/domain/avatar_dna.dart';

enum PetGender {
  male('male', 'Macho', '♂️', 'o'),
  female('female', 'Fêmea', '♀️', 'a');

  const PetGender(this.code, this.label, this.symbol, this.article);
  final String code;
  final String label;
  final String symbol;
  final String article;

  static PetGender fromCode(String? code) => PetGender.values.firstWhere(
    (e) => e.code == code,
    orElse: () => PetGender.male,
  );
}

enum FeedPreset {
  twice('twice', '2x (08h e 19h)', ['08:00', '19:00']),
  thrice('thrice', '3x (07h, 13h, 20h)', ['07:00', '13:00', '20:00']),
  custom('custom', 'Personalizar', ['08:30', '19:30']);

  const FeedPreset(this.code, this.label, this.defaultTimes);
  final String code;
  final String label;
  final List<String> defaultTimes;

  static FeedPreset fromCode(String? code) => FeedPreset.values.firstWhere(
    (e) => e.code == code,
    orElse: () => FeedPreset.twice,
  );
}

enum WalkPreset {
  none('none', 'Não passeia', []),
  once('once', '1x (18h)', ['18:00']),
  twice('twice', '2x (07h30 e 18h30)', ['07:30', '18:30']);

  const WalkPreset(this.code, this.label, this.defaultTimes);
  final String code;
  final String label;
  final List<String> defaultTimes;

  static WalkPreset fromCode(String? code) => WalkPreset.values.firstWhere(
    (e) => e.code == code,
    orElse: () => WalkPreset.twice,
  );
}

enum ForgettableCareType {
  fleaTick('flea_tick', 'Antipulgas / Carrapatos', '🐜', 30),
  deworm('deworm', 'Vermífugo', '💊', 90),
  medication('medication', 'Remédio contínuo', '🩺', 1);

  const ForgettableCareType(
    this.code,
    this.label,
    this.emoji,
    this.intervalDays,
  );
  final String code;
  final String label;
  final String emoji;
  final int intervalDays;

  static ForgettableCareType fromCode(String code) =>
      ForgettableCareType.values.firstWhere(
        (e) => e.code == code,
        orElse: () => ForgettableCareType.fleaTick,
      );
}

enum LastDoneRecency {
  thisMonth('this_month', 'Este mês'),
  older('older', 'Faz mais tempo'),
  dontRemember('dont_remember', 'Não lembro');

  const LastDoneRecency(this.code, this.label);
  final String code;
  final String label;

  static LastDoneRecency fromCode(String? code) =>
      LastDoneRecency.values.firstWhere(
        (e) => e.code == code,
        orElse: () => LastDoneRecency.dontRemember,
      );
}

/// Rascunho imutável do Onboarding (Seção 4 da SPEC_MVP.md).
/// Persistido localmente a cada passo para permitir retomada se o app fechar.
class OnboardingDraft {
  const OnboardingDraft({
    required this.species,
    this.gender = PetGender.male,
    required this.petName,
    required this.avatarDna,
    required this.feedPreset,
    required this.customFeedTimes,
    required this.walkPreset,
    this.customWalkTimes,
    required this.forgettableCare,
    this.fleaLastDate,
    this.fleaIntervalDays = 30,
    required this.tutorDisplayName,
    required this.timezone,
  });

  final PetSpecies species;
  final PetGender gender;
  final String petName;
  final AvatarDna avatarDna;
  final FeedPreset feedPreset;
  final List<String> customFeedTimes;
  final WalkPreset walkPreset;
  final List<String>? customWalkTimes;
  final Map<ForgettableCareType, LastDoneRecency> forgettableCare;
  final DateTime? fleaLastDate;
  final int fleaIntervalDays;

  DateTime fleaDue(DateTime today) {
    final last = fleaLastDate;
    if (last == null) return DateTime(today.year, today.month, today.day);
    return DateTime(last.year, last.month, last.day + fleaIntervalDays);
  }

  final String tutorDisplayName;
  final String timezone;

  factory OnboardingDraft.initial() {
    return OnboardingDraft(
      species: PetSpecies.dog,
      gender: PetGender.male,
      petName: '',
      avatarDna: AvatarDna.initial(species: PetSpecies.dog),
      feedPreset: FeedPreset.twice,
      customFeedTimes: const ['08:00', '19:00'],
      walkPreset: WalkPreset.twice,
      forgettableCare: const {
        ForgettableCareType.fleaTick: LastDoneRecency.dontRemember,
      },
      tutorDisplayName: 'Tutor',
      timezone: 'America/Sao_Paulo',
    );
  }

  List<String> get activeFeedTimes => feedPreset == FeedPreset.custom
      ? customFeedTimes
      : feedPreset.defaultTimes;

  List<String> get activeWalkTimes =>
      customWalkTimes ?? walkPreset.defaultTimes;

  OnboardingDraft copyWith({
    PetSpecies? species,
    PetGender? gender,
    String? petName,
    AvatarDna? avatarDna,
    FeedPreset? feedPreset,
    List<String>? customFeedTimes,
    WalkPreset? walkPreset,
    List<String>? customWalkTimes,
    Map<ForgettableCareType, LastDoneRecency>? forgettableCare,
    DateTime? fleaLastDate,
    bool clearFleaDate = false,
    int? fleaIntervalDays,
    String? tutorDisplayName,
    String? timezone,
  }) {
    return OnboardingDraft(
      species: species ?? this.species,
      gender: gender ?? this.gender,
      petName: petName ?? this.petName,
      avatarDna: avatarDna ?? this.avatarDna,
      feedPreset: feedPreset ?? this.feedPreset,
      customFeedTimes: customFeedTimes ?? this.customFeedTimes,
      walkPreset: walkPreset ?? this.walkPreset,
      customWalkTimes:
          customWalkTimes ?? (walkPreset == null ? this.customWalkTimes : null),
      forgettableCare: forgettableCare ?? this.forgettableCare,
      fleaLastDate: clearFleaDate ? null : fleaLastDate ?? this.fleaLastDate,
      fleaIntervalDays: fleaIntervalDays ?? this.fleaIntervalDays,
      tutorDisplayName: tutorDisplayName ?? this.tutorDisplayName,
      timezone: timezone ?? this.timezone,
    );
  }

  /// Gera o payload JSON esperado pela RPC `public.complete_onboarding(p jsonb)`.
  Map<String, Object?> toRpcPayload({required DateTime now}) {
    final tasks = <Map<String, Object?>>[
      {
        'type': 'feed',
        'label': 'Alimentar',
        'kind': 'daily',
        'daily_times': activeFeedTimes,
      },
      if (activeWalkTimes.isNotEmpty)
        {
          'type': 'walk',
          'label': 'Passeio',
          'kind': 'daily',
          'daily_times': activeWalkTimes,
        },
    ];

    for (final entry in forgettableCare.entries) {
      final type = entry.key;
      final recency = entry.value;
      final nextDue = type == ForgettableCareType.fleaTick
          ? fleaDue(now)
          : recency == LastDoneRecency.thisMonth
          ? now.add(Duration(days: type.intervalDays))
          : now;
      final nextDueIso =
          '${nextDue.year.toString().padLeft(4, '0')}-${nextDue.month.toString().padLeft(2, '0')}-${nextDue.day.toString().padLeft(2, '0')}';

      tasks.add({
        'type': type.code,
        'label': type.label,
        'kind': 'interval',
        'interval_days': type == ForgettableCareType.fleaTick
            ? fleaIntervalDays
            : type.intervalDays,
        'next_due_date': nextDueIso,
      });
    }

    return {
      'display_name': tutorDisplayName.trim().isEmpty
          ? 'Tutor'
          : tutorDisplayName.trim(),
      'pet': {
        'name': petName.trim(),
        'species': species.code,
        'gender': gender.code,
        'timezone': timezone,
        'avatar_dna': avatarDna.toJson(),
      },
      'tasks': tasks,
    };
  }

  Map<String, Object?> toJson() => {
    'species': species.code,
    'gender': gender.code,
    'pet_name': petName,
    'avatar_dna': avatarDna.toJson(),
    'feed_preset': feedPreset.code,
    'custom_feed_times': customFeedTimes,
    'flea_last_date': fleaLastDate?.toIso8601String(),
    'flea_interval_days': fleaIntervalDays,
    'walk_preset': walkPreset.code,
    'custom_walk_times': customWalkTimes,
    'forgettable_care': {
      for (final e in forgettableCare.entries) e.key.code: e.value.code,
    },
    'tutor_display_name': tutorDisplayName,
    'timezone': timezone,
  };

  factory OnboardingDraft.fromJson(Map<String, dynamic> json) {
    final species = PetSpecies.fromCode(json['species'] as String?);
    final gender = PetGender.fromCode(json['gender'] as String?);
    final rawCare =
        (json['forgettable_care'] as Map<String, dynamic>?) ?? const {};
    return OnboardingDraft(
      species: species,
      gender: gender,
      petName: (json['pet_name'] as String?) ?? '',
      avatarDna: json['avatar_dna'] is Map<String, dynamic>
          ? AvatarDna.fromJson(json['avatar_dna'] as Map<String, dynamic>)
          : AvatarDna.initial(species: species),
      feedPreset: FeedPreset.fromCode(json['feed_preset'] as String?),
      customFeedTimes:
          (json['custom_feed_times'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['08:00', '19:00'],
      fleaLastDate: DateTime.tryParse(json['flea_last_date'] as String? ?? ''),
      fleaIntervalDays: json['flea_interval_days'] as int? ?? 30,
      customWalkTimes: (json['custom_walk_times'] as List?)?.cast<String>(),
      walkPreset: WalkPreset.fromCode(json['walk_preset'] as String?),
      forgettableCare: {
        for (final entry in rawCare.entries)
          ForgettableCareType.fromCode(entry.key): LastDoneRecency.fromCode(
            entry.value as String?,
          ),
      },
      tutorDisplayName: (json['tutor_display_name'] as String?) ?? 'Tutor',
      timezone: (json['timezone'] as String?) ?? 'America/Sao_Paulo',
    );
  }
}
