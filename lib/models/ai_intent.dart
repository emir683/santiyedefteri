class AIIntent {
  final String action;
  final String message;
  final Map<String, dynamic> params;

  AIIntent({
    required this.action,
    required this.message,
    required this.params,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        'message': message,
        'params': params,
      };

  factory AIIntent.fromJson(Map<String, dynamic> json) => AIIntent(
        action: json['action'] ?? '',
        message: json['message'] ?? '',
        params: Map<String, dynamic>.from(json['params'] ?? {}),
      );
}
