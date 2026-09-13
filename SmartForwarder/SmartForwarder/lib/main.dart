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
  String _statusLog = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _log(String message) {
    if (mounted) {
      setState(() => _statusLog += '$message\n');
    }
  }

  Future<void> _initializeApp() async {
    try {
      _log('🔄 بدء التهيئة...');

      final smsStatus = await Permission.sms.request();
      _log('📩 صلاحية SMS: ${smsStatus.isGranted ? "مسموحة ✅" : "مرفوضة ❌"}');

      try {
        await Permission.notification.request();
        _log('🔔 صلاحية الإشعارات: تم الطلب');
      } catch (e) {
        _log('🔔 صلاحية الإشعارات: مش مطلوبة في نسخة أندرويد دي');
      }

      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      _log('🔋 استثناء البطارية: تم الطلب');

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
      _log('⚙️ تهيئة إعدادات الخدمة: تمت');

      final bool alreadyRunning = await FlutterForegroundTask.isRunningService;
      final serviceResult = alreadyRunning
          ? await FlutterForegroundTask.restartService()
          : await FlutterForegroundTask.startService(
              notificationTitle: 'Smart Forwarder شغال',
              notificationText: 'جاري مراقبة الرسائل النصية',
              callback: startCallback,
            );

      if (serviceResult is ServiceRequestFailure) {
        _log('🚀 بدء الخدمة الخلفية: فشل ❌ - ${serviceResult.error}');
      } else {
        _log(alreadyRunning
            ? '🚀 الخدمة الخلفية: كانت شغالة بالفعل - تم إعادة تشغيلها ✅'
            : '🚀 بدء الخدمة الخلفية: نجح ✅');
      }

      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          SmsProcessor.processIncomingMessage(message);
        },
        onBackgroundMessage: backgroundMessageHandler,
        listenInBackground: true,
      );
      _log('👂 بدء الاستماع لرسائل SMS: تم');

      ConnectivityService.startMonitoring();
      _log('🌐 مراقبة الاتصال بالإنترنت: بدأت');

      _log('✅ كل حاجة اشتغلت بنجاح!');
    } catch (e, stackTrace) {
      _log('❌ حصل خطأ:\n$e\nStack:\n$stackTrace');
    }

    if (globalErrorLog.isNotEmpty) {
      _log('\n⚠️ أخطاء عامة:');
      for (final err in globalErrorLog) {
        _log(err);
      }
    }

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Forwarder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: !_initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _buildDiagnosticScreen(),
    );
  }

  Widget _buildDiagnosticScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التشغيل (تشخيص)'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
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
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    debugPrint('▶️ تم الضغط على زر الدخول للتطبيق');
                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('الدخول للتطبيق', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_ForwarderTaskHandler());
}

class _ForwarderTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('✅ Foreground service started');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('🛑 Foreground service destroyed');
  }
}
