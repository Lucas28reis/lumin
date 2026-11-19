enum CareSlotKind { dailyFeed, dailyWalk, interval }

class CareSlotItem {
  const CareSlotItem({
    required this.id,
    required this.taskId,
    required this.slotIndex,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.emoji,
    this.iconAsset,
    this.scheduledHour,
    this.scheduledMinute,
    this.isDone = false,
    this.doneByName,
    this.doneAt,
    this.logId,
    this.isPendingSync = false,
  });

  final String id;
  final String taskId;
  final int slotIndex;
  final CareSlotKind kind;
  final String title;
  final String subtitle;
  final String emoji;

  /// Caminho opcional para a figura/imagem customizada escolhida pelo usuário
  /// (ex: 'assets/icons/walk.png', 'assets/icons/food.png').
  final String? iconAsset;

  final int? scheduledHour;
  final int? scheduledMinute;
  final bool isDone;
  final String? doneByName;
  final DateTime? doneAt;
  final String? logId;
  final bool isPendingSync;

  /// Horário curto formatado ("07:30", "08:00") para exibição limpa sem excesso de texto.
  String get timeLabel {
    if (scheduledHour == null) return 'Hoje';
    final h = scheduledHour!.toString().padLeft(2, '0');
    final m = (scheduledMinute ?? 0).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Minutos desde 00:00 para ordenação cronológica sequencial (07:30 -> 08:00 -> 18:30 -> 19:00).
  int get sortMinutes =>
      scheduledHour != null ? (scheduledHour! * 60 + (scheduledMinute ?? 0)) : 9999;

  CareSlotItem copyWith({
    bool? isDone,
    String? doneByName,
    DateTime? doneAt,
    String? logId,
    bool? isPendingSync,
    bool clearCompletion = false,
  }) {
    if (clearCompletion) {
      return CareSlotItem(
        id: id,
        taskId: taskId,
        slotIndex: slotIndex,
        kind: kind,
        title: title,
        subtitle: subtitle,
        emoji: emoji,
        iconAsset: iconAsset,
        scheduledHour: scheduledHour,
        scheduledMinute: scheduledMinute,
      );
    }
    return CareSlotItem(
      id: id,
      taskId: taskId,
      slotIndex: slotIndex,
      kind: kind,
      title: title,
      subtitle: subtitle,
      emoji: emoji,
      iconAsset: iconAsset,
      scheduledHour: scheduledHour,
      scheduledMinute: scheduledMinute,
      isDone: isDone ?? this.isDone,
      doneByName: doneByName ?? this.doneByName,
      doneAt: doneAt ?? this.doneAt,
      logId: logId ?? this.logId,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }
}

/// Resolve o próximo slot pendente do dia para destacar no botão principal da Home.
abstract final class NextSlotResolver {
  static CareSlotItem? resolveNextPending(List<CareSlotItem> slots) {
    for (final slot in slots) {
      if (!slot.isDone) return slot;
    }
    return null;
  }
}
