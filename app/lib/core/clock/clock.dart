/// Relógio injetável para permitir testes determinísticos de meia-noite,
/// atraso de refeições e virada de ofensiva no fuso do pet.
abstract interface class Clock {
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

final class FixedClock implements Clock {
  FixedClock(this._current);

  DateTime _current;

  @override
  DateTime now() => _current;

  void advance(Duration delta) {
    _current = _current.add(delta);
  }
}
