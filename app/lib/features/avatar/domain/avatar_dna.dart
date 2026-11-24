import 'dart:math';

enum PetSpecies {
  dog('dog', 'Cachorro', '🐶'),
  cat('cat', 'Gato', '🐱');

  const PetSpecies(this.code, this.label, this.emoji);
  final String code;
  final String label;
  final String emoji;

  static PetSpecies fromCode(String? code) =>
      PetSpecies.values.firstWhere(
        (e) => e.code == code,
        orElse: () => PetSpecies.dog,
      );
}

enum FurPattern {
  solid('solid', 'Liso'),
  spots('spots', 'Manchinhas'),
  bicolor('bicolor', 'Peito Branco'),
  stripes('stripes', 'Rajado');

  const FurPattern(this.code, this.label);
  final String code;
  final String label;

  static FurPattern fromCode(String? code) =>
      FurPattern.values.firstWhere(
        (e) => e.code == code,
        orElse: () => FurPattern.spots,
      );
}

enum EarStyle {
  floppy('floppy', 'Caídas'),
  pointed('pointed', 'Pontudas'),
  round('round', 'Redondinhas');

  const EarStyle(this.code, this.label);
  final String code;
  final String label;

  static EarStyle fromCode(String? code) =>
      EarStyle.values.firstWhere(
        (e) => e.code == code,
        orElse: () => EarStyle.floppy,
      );
}

enum SnoutStyle {
  short('short', 'Curto'),
  medium('medium', 'Clássico'),
  whiskers('whiskers', 'Bigodudo');

  const SnoutStyle(this.code, this.label);
  final String code;
  final String label;

  static SnoutStyle fromCode(String? code) =>
      SnoutStyle.values.firstWhere(
        (e) => e.code == code,
        orElse: () => SnoutStyle.medium,
      );
}

enum EyeStyle {
  round('round', 'Redondos'),
  sparkle('sparkle', 'Brilhantes'),
  almond('almond', 'Amendoados');

  const EyeStyle(this.code, this.label);
  final String code;
  final String label;

  static EyeStyle fromCode(String? code) =>
      EyeStyle.values.firstWhere(
        (e) => e.code == code,
        orElse: () => EyeStyle.sparkle,
      );
}

/// DNA imutável e versionado (`v: 1`) do Avatar (Seção 6.5 da SPEC_MVP.md).
/// Compatível com a constraint `check (avatar_dna ? 'v')` do PostgreSQL.
class AvatarDna {
  const AvatarDna({
    this.v = 1,
    required this.species,
    required this.baseColor,
    required this.pattern,
    required this.patternColor,
    required this.ears,
    required this.snout,
    required this.eyes,
    this.accessory,
  });

  final int v;
  final PetSpecies species;
  final String baseColor;
  final FurPattern pattern;
  final String patternColor;
  final EarStyle ears;
  final SnoutStyle snout;
  final EyeStyle eyes;
  final String? accessory;

  static const List<({String hex, String label})> basePalette = [
    (hex: '#F2BC62', label: 'Golden'),
    (hex: '#EAD2A4', label: 'Labrador Creme'),
    (hex: '#F4A258', label: 'Laranja Tigrado'),
    (hex: '#FBB49A', label: 'Pêssego'),
    (hex: '#D48C46', label: 'Caramelo'),
    (hex: '#5C4033', label: 'Chocolate'),
    (hex: '#2C2C2E', label: 'Preto'),
    (hex: '#F4EDE4', label: 'Creme'),
    (hex: '#9E9E9E', label: 'Cinza'),
    (hex: '#E07A5F', label: 'Ruivo'),
  ];

  static const List<({String hex, String label})> patternPalette = [
    (hex: '#D59D4D', label: 'Mel'),
    (hex: '#BC8036', label: 'Dourado Mel'),
    (hex: '#C56B27', label: 'Rajado Âmbar'),
    (hex: '#CE7A6E', label: 'Terracota'),
    (hex: '#FFFFFF', label: 'Branco'),
    (hex: '#3D2B1F', label: 'Escuro'),
    (hex: '#F2CC8F', label: 'Dourado'),
    (hex: '#7A7A7A', label: 'Acinzentado'),
  ];

  factory AvatarDna.initial({PetSpecies species = PetSpecies.dog}) {
    final isCat = species == PetSpecies.cat;
    return AvatarDna(
      species: species,
      baseColor: isCat ? '#F4A258' : '#F2BC62',
      pattern: isCat ? FurPattern.stripes : FurPattern.spots,
      patternColor: isCat ? '#C56B27' : '#D59D4D',
      ears: isCat ? EarStyle.pointed : EarStyle.floppy,
      snout: isCat ? SnoutStyle.whiskers : SnoutStyle.medium,
      eyes: EyeStyle.sparkle,
      accessory: 'collar',
    );
  }

  factory AvatarDna.random({PetSpecies? species, Random? rng}) {
    final random = rng ?? Random();
    final chosenSpecies =
        species ?? PetSpecies.values[random.nextInt(PetSpecies.values.length)];
    final base = basePalette[random.nextInt(basePalette.length)].hex;
    final pat = patternPalette[random.nextInt(patternPalette.length)].hex;
    return AvatarDna(
      species: chosenSpecies,
      baseColor: base,
      pattern: FurPattern.values[random.nextInt(FurPattern.values.length)],
      patternColor: pat == base ? '#FFFFFF' : pat,
      ears: EarStyle.values[random.nextInt(EarStyle.values.length)],
      snout: SnoutStyle.values[random.nextInt(SnoutStyle.values.length)],
      eyes: EyeStyle.values[random.nextInt(EyeStyle.values.length)],
      accessory: const [null, 'collar', 'bandana'][random.nextInt(3)],
    );
  }

  AvatarDna copyWith({
    PetSpecies? species,
    String? baseColor,
    FurPattern? pattern,
    String? patternColor,
    EarStyle? ears,
    SnoutStyle? snout,
    EyeStyle? eyes,
    String? accessory,
  }) {
    return AvatarDna(
      v: v,
      species: species ?? this.species,
      baseColor: baseColor ?? this.baseColor,
      pattern: pattern ?? this.pattern,
      patternColor: patternColor ?? this.patternColor,
      ears: ears ?? this.ears,
      snout: snout ?? this.snout,
      eyes: eyes ?? this.eyes,
      accessory: accessory ?? this.accessory,
    );
  }

  Map<String, Object?> toJson() => {
        'v': v,
        'species': species.code,
        'base_color': baseColor,
        'pattern': pattern.code,
        'pattern_color': patternColor,
        'ears': ears.code,
        'snout': snout.code,
        'eyes': eyes.code,
        'accessory': accessory,
      };

  factory AvatarDna.fromJson(Map<String, dynamic> json) {
    final species = PetSpecies.fromCode(json['species'] as String?);
    return AvatarDna(
      v: (json['v'] as num?)?.toInt() ?? 1,
      species: species,
      baseColor: (json['base_color'] as String?) ?? '#D48C46',
      pattern: FurPattern.fromCode(json['pattern'] as String?),
      patternColor: (json['pattern_color'] as String?) ?? '#FFFFFF',
      ears: EarStyle.fromCode(json['ears'] as String?),
      snout: SnoutStyle.fromCode(json['snout'] as String?),
      eyes: EyeStyle.fromCode(json['eyes'] as String?),
      accessory: json['accessory'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AvatarDna &&
          v == other.v &&
          species == other.species &&
          baseColor == other.baseColor &&
          pattern == other.pattern &&
          patternColor == other.patternColor &&
          ears == other.ears &&
          snout == other.snout &&
          eyes == other.eyes &&
          accessory == other.accessory;

  @override
  int get hashCode => Object.hash(
        v,
        species,
        baseColor,
        pattern,
        patternColor,
        ears,
        snout,
        eyes,
        accessory,
      );
}
