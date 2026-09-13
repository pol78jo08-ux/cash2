import 'package:telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/log_entry.dart';
import 'telegram_service.dart';

@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  debugPrint("🚨 [BACKGROUND] تم استدعاء معالج الخلفية لرسالة من: ${message.address}");
  await SmsProcessor.processIncomingMessage(message);
}

class SmsProcessor {
  static Future<void> processIncomingMessage(SmsMessage message) async {
    final sender = message.address ?? 'UNKNOWN';
    final body = message.body ?? '';
    
    debugPrint("📩 [DEBUG] رسالة واردة جديدة:");
    debugPrint("   - المرسل: $sender");
    debugPrint("   - النص: $body");

    final db = DatabaseHelper.instance;
    final monitors = await db.getEnabledMonitors();

    debugPrint("🔍 [DEBUG] عدد المراقبات المفعلة المسترجعة من قاعدة البيانات: ${monitors.length}");
    
    if (monitors.isEmpty) {
      debugPrint("⚠️ [DEBUG] تحذير: لا توجد مراقبات مفعلة! سيتم تجاهل الرسالة.");
      return;
    }

    bool anyMatch = false;

    for (final monitor in monitors) {
      debugPrint("🔄 [DEBUG] فحص المراقبة: '${monitor.label}' | النمط المطلوب: '${monitor.senderPattern}'");
      
      final isMatch = sender.toLowerCase().contains(monitor.senderPattern.toLowerCase());
      
      if (!isMatch) {
        debugPrint("❌ [DEBUG] لا يوجد تطابق مع '${monitor.label}'. جاري تخطي هذه المراقبة.");
        continue; 
      }
      
      anyMatch = true;
      debugPrint("✅ [DEBUG] تطابق ناجح مع '${monitor.label}'! جاري الإرسال لتليجرام...");

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
      debugPrint("💾 [DEBUG] تم حفظ السجل في قاعدة البيانات بنجاح. الحالة: ${log.status}");
    }

    if (!anyMatch) {
      debugPrint("⚠️ [DEBUG] نهاية المعالجة: الرسالة وصلت، لكن لم تطابق أي نمط من المراقبات المفعلة.");
    }
  }

  static String _formatMessage(String monitorLabel, String sender, String body) {
    return '🔔 *$monitorLabel*\n'
           '📨 المرسل: `$sender`\n\n'
           '```\n$body\n```';
  }
}
