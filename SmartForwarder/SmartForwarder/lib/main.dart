import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'screens/home_screen.dart';
import 'services/sms_service.dart';
import 'services/connectivity_service.dart';
import 'theme/app_theme.dart';

final Telephony telephony = Telephony.instance;
final List<String> globalErrorLog = [];
bool _smsListenerInitialized = false;

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterForegroundTask.initCommunicationPort();
    FlutterError.onError = (FlutterErrorDetails details) {
      globalErrorLog.add('FlutterError: ${details.exceptionAsString()}');
    };
    runApp(const SmartForwarderApp());
  }, (error, stackTrace) {
    globalErrorLog.add('Uncaught: $error\n$stackTrace');
  });
}

class SmartForwarderApp extends StatefulWidget {
  const SmartForwarderApp({super.key});

  @override
  State<SmartForwarderApp> createState() => _SmartForwarderAppState();
}

class _SmartForwarderAppState extends State<SmartForwarderApp> {
  bool _initialized = false;
  String? _errorMessage;
  String _statusLog = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _log(String message) {
    setState(() => _statusLog += '$message\n');
  }

  Future<void> _initializeApp() async {
    try {
      _log('🔄 بدء التهيئة...');
      final smsStatus = await Permission.sms.request();
      _log('📩 صلاحية SMS: ${smsStatus.isGranted ? "مسموحة ✅" : "مرفوضة ❌ (${smsStatus.name})"}');

      try {
        await Permission.notification.request();
        _log('🔔 صلاحية الإشعارات: تم الطلب');
      } catch (e) {
        _log('🔔 صلاحية الإشعارات: مش مطلوبة في نسخة أندرويد دي (طبيعي)');
      }

      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      _log('🔋 استثناء البطارية: تم الطلب');

      _initForegroundTask();
      _log('⚙️ تهيئة إعدادات الخدمة: تمت');

      // التحقق من حالة الخدمة قبل التشغيل
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) {
        _log('✅ الخدمة الخلفية شغالة أصلاً - لا حاجة لإعادة التشغيل');
      } else {
        _log('🔄 الخدمة مش شغالة - جاري تشغيلها...');
        try {
          final serviceResult = await FlutterForegroundTask.startService(
            notificationTitle: 'Smart Forwarder شغال',
            notificationText: 'جاري مراقبة الرسائل النصية',
            callback: startCallback,
          );

          if (serviceResult is ServiceRequestFailure) {
            _log('🚀 بدء الخدمة الخلفية: فشل ❌');
            _log('سبب الفشل: ${serviceResult.error}');
          } else {
            _log('🚀 بدء الخدمة الخلفية: نجح ✅');
          }
        } catch (e) {
          _log('⚠️ تحذير: الخدمة قد تكون شغالة - ${e.toString()}');
        }
      }

      // التأكد من أن الـ SMS listener مش بيتسجل أكتر من مرة
      if (!_smsListenerInitialized) {
        telephony.listenIncomingSms(
          onNewMessage: (SmsMessage message) {
            SmsProcessor.processIncomingMessage(message);
          },
          onBackgroundMessage: backgroundMessageHandler,
          listenInBackground: true,
        );
        _smsListenerInitialized = true;
        _log('👂 بدء الاستماع لرسائل SMS: تم');
      } else {
        _log('👂 الاستماع لرسائل SMS شغال أصلاً');
      }

      ConnectivityService.startMonitoring();
      _log('🌐 مراقبة الاتصال بالإنترنت: بدأت');

      _log('✅ كل حاجة اشتغلت بنجاح!');
    } catch (e, stackTrace) {
      _errorMessage = ' حصل خطأ:\n$e\nStack:\n$stackTrace';
      _log(_errorMessage!);
    }

    if (globalErrorLog.isNotEmpty) {
      _log('\n⚠️ أخطاء عامة اتسجلت أثناء التشغيل:');
      for (final err in globalErrorLog) {
        _log(err);
      }
    }

    setState(() => _initialized = true);
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'smart_forwarder_channel',
        channelName: 'Smart Forwarder Service',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Forwarder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      home: !_initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _buildDiagnosticScreen(),
    );
  }

  Widget _buildDiagnosticScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل التشغيل (تشخيص)')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _statusLog,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _fetchLastSms,
                    icon: const Icon(Icons.sms, size: 20),
                    label: const Text('🔍 فحص آخر رسالة SMS وصلت للجهاز'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
                    child: const Text('الدخول للتطبيق'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchLastSms() async {
    setState(() => _statusLog += '\n\n [TEST] جاري البحث عن آخر رسالة SMS...');

    try {
      final status = await Permission.sms.status;
      if (!status.isGranted) {
        setState(() => _statusLog += '\n❌ [TEST] صلاحية SMS غير ممنوحة! الحالة: ${status.name}');
        return;
      }

      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      );

      if (messages.isEmpty) {
        setState(() => _statusLog += '\n️ [TEST] صندوق الوارد فارغ أو لا يمكن الوصول إليه!');
        return;
      }

      final count = messages.length > 5 ? 5 : messages.length;
      setState(() => _statusLog += '\n✅ [TEST] تم العثور على ${messages.length} رسالة. عرض آخر $count:');

      for (int i = 0; i < count; i++) {
        final msg = messages[i];
        final date = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0);
        setState(() => _statusLog +=
            '\n\n📨 [${i + 1}] من: ${msg.address ?? "غير معروف"}'
            '\n   التاريخ: ${date.toLocal()}'
            '\n   النص: ${(msg.body ?? "").length > 100 ? (msg.body ?? "").substring(0, 100) + "..." : msg.body}');
      }
    } catch (e, st) {
      setState(() => _statusLog += '\n❌ [TEST] خطأ أثناء قراءة الرسائل:\n$e\n$st');
    }
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_ForwarderTaskHandler());
}

class _ForwarderTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
