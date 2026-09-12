import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../db/database_helper.dart';
import '../models/log_entry.dart';
import 'telegram_service.dart';

/// بيراقب حالة النت باستمرار. أول ما يرجع الاتصال بعد انقطاع،
/// بيدور على كل الرسايل المتراكمة بحالة "queued" ويحاول يبعتها تاني تلقائيًا.
class ConnectivityService {
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static bool _wasOffline = false;

  static void startMonitoring() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((results) async {
      final isOnline = results.any((r) => r != ConnectivityResult.none);

      if (isOnline && _wasOffline) {
        await _retryQueuedMessages();
      }
      _wasOffline = !isOnline;
    });
  }

  static void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// إعادة محاولة إرسال كل الرسايل المعلّقة. كل رسالة بتتحدث حالتها
  /// حسب نتيجة المحاولة الجديدة، وبيزيد عدد المحاولات في كل مرة.
  static Future<void> _retryQueuedMessages() async {
    final db = DatabaseHelper.instance;
    final queued = await db.getQueuedLogs();

    for (final log in queued) {
      // نحتاج بيانات المراقبة الأصلية (توكن + chatId) عشان نعيد الإرسال بنفس الوجهة
      final monitors = await db.getAllMonitors();
      final monitor = monitors.where((m) => m.id == log.monitorId).firstOrNull;

      if (monitor == null) {
        // المراقبة اتحذفت من ساعتها - تسجيل نهائي كفشل
        await db.updateLog(log.copyWith(
          status: LogStatus.failed,
          errorReason: 'المراقبة الأصلية محذوفة',
        ));
        continue;
      }

      final formattedMessage =
          '🔔 *${monitor.label}* (إعادة إرسال)\n📨 المرسل: `${log.sender}`\n\n```\n${log.messageBody}\n```';

      final result = await TelegramService.send(
        botToken: monitor.botToken,
        chatId: monitor.chatId,
        message: formattedMessage,
      );

      await db.updateLog(log.copyWith(
        status: result.success ? LogStatus.success : LogStatus.queued,
        errorReason: result.success ? null : result.errorReason,
        retryCount: log.retryCount + 1,
      ));
    }
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
