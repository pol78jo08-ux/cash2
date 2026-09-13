import 'package:telephony/telephony.dart';
import '../db/database_helper.dart';
import '../models/log_entry.dart';
import 'telegram_service.dart';

/// نقطة الدخول اللي بتستقبل الرسالة سواء التطبيق مفتوح أو مقفول أو في الخلفية.
/// لازم تفضل top-level function (مش جوه كلاس) وعليها الـ annotation ده
/// عشان أندرويد يقدر يناديها من عملية منفصلة (Isolate) وقت التطبيق مقفول.
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  await SmsProcessor.processIncomingMessage(message);
}

class SmsProcessor {
  /// المنطق الأساسي: ياخد أي رسالة واردة، يقارنها بكل المراقبات المفعّلة،
  /// وأي مراقبة تطابق يبعتلها الرسالة لتليجرام بشكل مستقل تمامًا عن باقي المراقبات.
  ///
  /// لو الرسالة وصلت ومتطابقتش مع أي مراقبة، بتتسجل بحالة "ignored" في السجل
  /// عشان تقدر تشوف الشكل الحقيقي لاسم المرسل ومحتوى الرسالة - ده تسجيل تشخيصي
  /// مؤقت لحد ما تتأكد إن كل حاجة شغالة صح، وممكن تشيله بعدين لو عايز.
  static Future<void> processIncomingMessage(SmsMessage message) async {
    final sender = message.address ?? 'UNKNOWN';
    final body = message.body ?? '';

    final db = DatabaseHelper.instance;
    final monitors = await db.getEnabledMonitors();

    bool matchedAny = false;

    for (final monitor in monitors) {
      final isMatch = sender.toLowerCase().contains(monitor.senderPattern.toLowerCase());
      if (!isMatch) continue; // كل مراقبة بتتفلتر لوحدها، مستقلة عن الباقي

      matchedAny = true;

      final formattedMessage = _formatMessage(monitor.label, sender, body);

      final result = await TelegramService.send(
        botToken: monitor.botToken,
        chatId: monitor.chatId,
        message: formattedMessage,
      );

      final log = LogEntry(
        monitorId: monitor.id,
        monitorLabel: monitor.label,
        sender: sender,
        messageBody: body,
        status: result.success ? LogStatus.success : LogStatus.queued,
        errorReason: result.success ? null : result.errorReason,
      );

      await db.insertLog(log);
      // لو فشل الإرسال (غالبًا بسبب النت)، الرسالة بتفضل محفوظة بحالة "queued"
      // وهيجي عليها دور إعادة المحاولة من خلال ConnectivityService لما النت يرجع.
    }

    if (!matchedAny) {
      // تسجيل تشخيصي: الرسالة وصلت فعلاً للتطبيق بس مفيش أي مراقبة اتطابقت معاها
      // (سواء لأن مفيش مراقبات مفعّلة أصلاً، أو لأن نص المرسل مختلف عن اللي متوقّع)
      await db.insertLog(LogEntry(
        monitorId: null,
        monitorLabel: monitors.isEmpty ? '(مفيش مراقبات مفعّلة)' : '(مفيش تطابق)',
        sender: sender,
        messageBody: body,
        status: LogStatus.ignored,
      ));
    }
  }

  static String _formatMessage(String monitorLabel, String sender, String body) {
    return '🔔 *$monitorLabel*\n'
        '📨 المرسل: `$sender`\n\n'
        '```\n$body\n```';
  }
}
