/// موديل "المراقبة" - كل مراقبة عملية مستقلة بالكامل عن غيرها:
/// ليها اسم مرسل بتراقبه، ووجهة إرسال خاصة بيها (جروب أو شات خاص)، وحالة تفعيل.
class Monitor {
  final int? id;
  final String label; // اسم وصفي يختاره المستخدم لتمييز المراقبة (مثلاً "فودافون كاش الرئيسي")
  final String senderPattern; // النص اللي هيتقارن بيه المرسل (originatingAddress)
  final String botToken;
  final String chatId; // ممكن يكون جروب أو شات خاص بمستخدم - نفس الآلية في تليجرام
  final bool isEnabled;
  final int createdAt;

  Monitor({
    this.id,
    required this.label,
    required this.senderPattern,
    required this.botToken,
    required this.chatId,
    this.isEnabled = true,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'senderPattern': senderPattern,
      'botToken': botToken,
      'chatId': chatId,
      'isEnabled': isEnabled ? 1 : 0,
      'createdAt': createdAt,
    };
  }

  factory Monitor.fromMap(Map<String, dynamic> map) {
    return Monitor(
      id: map['id'] as int?,
      label: map['label'] as String,
      senderPattern: map['senderPattern'] as String,
      botToken: map['botToken'] as String,
      chatId: map['chatId'] as String,
      isEnabled: (map['isEnabled'] as int) == 1,
      createdAt: map['createdAt'] as int,
    );
  }

  Monitor copyWith({
    String? label,
    String? senderPattern,
    String? botToken,
    String? chatId,
    bool? isEnabled,
  }) {
    return Monitor(
      id: id,
      label: label ?? this.label,
      senderPattern: senderPattern ?? this.senderPattern,
      botToken: botToken ?? this.botToken,
      chatId: chatId ?? this.chatId,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt,
    );
  }
}
