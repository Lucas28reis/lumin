/// Estados de humor do Avatar (Seção 3.2 da SPEC_MVP.md).
enum AvatarMood {
  celebrating('celebrating', 'Festejando! 🎉'),
  hungry('hungry', 'Com fominha 🥺'),
  worried('worried', 'Precisando de cuidado 💊'),
  bored('bored', 'Querendo passear 🦮'),
  sleepy('sleepy', 'Com soninho 💤'),
  happy('happy', 'Feliz e cuidado ✨');

  const AvatarMood(this.code, this.badgeLabel);
  final String code;
  final String badgeLabel;

  String speechBubble(String petName) {
    return switch (this) {
      AvatarMood.celebrating => 'Nham! Obrigado por cuidar de mim! 💛',
      AvatarMood.hungry => '$petName está olhando pro pote... e pra você 🥺',
      AvatarMood.worried => 'Tem um cuidado importante vencendo hoje!',
      AvatarMood.bored => 'Que tal uma voltinha? Prometo me comportar!',
      AvatarMood.sleepy => 'Zzz... Tudo em dia por aqui, boa noite!',
      AvatarMood.happy => '$petName está super feliz com a família em dia!',
    };
  }
}
