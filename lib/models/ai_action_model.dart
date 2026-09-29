enum AIActionType {
  addWorker,
  addPayment,
  submitDailyLog,
  addSite,
  siteMonthlySummary,
  workerMonthlySummary,
}

enum AIActionStatus {
  pending, // Bekliyor
  confirmed, // Onaylandı
  cancelled, // İptal edildi
}

class AIActionCardData {
  final String id;
  final AIActionType type;
  final String title;
  final String description;
  AIActionStatus status;
  final Map<String, dynamic> data;

  AIActionCardData({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.status = AIActionStatus.pending,
    required this.data,
  });

  AIActionCardData copyWith({
    String? id,
    AIActionType? type,
    String? title,
    String? description,
    AIActionStatus? status,
    Map<String, dynamic>? data,
  }) {
    return AIActionCardData(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      data: data ?? this.data,
    );
  }
}

class AIChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final AIActionCardData? actionCard;

  AIChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.actionCard,
  });
}
