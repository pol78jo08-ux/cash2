enum LogStatus {
  success, // اتبعتت بنجاح
  failed, // فشل الإرسال (خطأ من تليجرام أو الشبكة)
  queued, // متأخرة بانتظار عودة الإنترنت
  ignored, // وصلت للتطبيق بس متطابقتش مع أي مراقبة - تسجيل تشخيصي
}

extension LogStatusExtension on LogStatus {
  String get label {
    switch (this) {
      case LogStatus.success:
        return 'تم الإرسال';
      case LogStatus.failed:
        return 'فشل الإرسال';
      case LogStatus.queued:
        return 'بانتظار الاتصال';
      case LogStatus.ignored:
        return 'وصلت - مش متطابقة';
    }
  }

  static LogStatus fromString(String value) {
    return LogStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LogStatus.failed,
    );
  }
}

class LogEntry {
  final int? id;
  final int? monitorId; // ممكن يكون null لو الرسالة معملهاش match مع أي مراقبة (تسجيل تشخيصي)
  final String monitorLabel; // نسخة من اسم المراقبة وقت الإرسال (تفضل موجودة حتى لو اتحذفت المراقبة بعدين)
  final String sender;
  final String messageBody;
  final LogStatus status;
  final String? errorReason;
  final int timestamp;
  final int retryCount;

  LogEntry({
    this.id,
    this.monitorId,
    required this.monitorLabel,
    required this.sender,
    required this.messageBody,
    required this.status,
    this.errorReason,
    int? timestamp,
    this.retryCount = 0,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'monitorId': monitorId,
      'monitorLabel': monitorLabel,
      'sender': sender,
      'messageBody': messageBody,
      'status': status.name,
      'errorReason': errorReason,
      'timestamp': timestamp,
      'retryCount': retryCount,
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'] as int?,
      monitorId: map['monitorId'] as int?,
      monitorLabel: map['monitorLabel'] as String,
      sender: map['sender'] as String,
      messageBody: map['messageBody'] as String,
      status: LogStatusExtension.fromString(map['status'] as String),
      errorReason: map['errorReason'] as String?,
      timestamp: map['timestamp'] as int,
      retryCount: map['retryCount'] as int? ?? 0,
    );
  }

  LogEntry copyWith({LogStatus? status, String? errorReason, int? retryCount}) {
    return LogEntry(
      id: id,
      monitorId: monitorId,
      monitorLabel: monitorLabel,
      sender: sender,
      messageBody: messageBody,
      status: status ?? this.status,
      errorReason: errorReason ?? this.errorReason,
      timestamp: timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
