sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Sem conexão no momento. Seus dados estão salvos no aparelho.',
  ]);
}

final class InvalidInviteFailure extends Failure {
  const InvalidInviteFailure([
    super.message = 'Código inválido ou expirado. Confira os 6 caracteres.',
  ]);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'Sessão expirada. Tente novamente.',
  ]);
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.message = 'Algo saiu do esperado. Tente novamente em instantes.',
  ]);
}
