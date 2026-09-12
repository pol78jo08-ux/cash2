import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'screens/home_screen.dart';
import 'services/sms_service.dart';
import 'services/connectivity_service.dart';
import 'theme/app_theme.dart';

final Telephony telephony = Telephony.instance;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  runApp(const SmartForwarderApp());
}

class SmartForwarderApp extends StatefulWidget {
  const SmartForwarderApp({super.key});

  @override
  State<SmartForwarderApp> createState() => _SmartForwarderAppState();
}

class _SmartForwarderAppState extends State<SmartForwarderApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. طلب صلاحيات SMS
    await Permission.sms.request();

    // 2. طلب استثناء البطارية (API رسمي من أندرويد نفسه)
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();

    // 3. تهيئة إعدادات الـ Foreground Service (يخلي التطبيق محصّن ضد قيود MIUI)
    _initForegroundTask();
    await FlutterForegroundTask.startService(
      notificationTitle: 'Smart Forwarder شغال',
      notificationText: 'جاري مراقبة الرسائل النصية',
      callback: startCallback,
    );

    // 4. بدء الاستماع لأي SMS واردة (شغال حتى لو التطبيق مقفول)
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        SmsProcessor.processIncomingMessage(message);
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );

    // 5. بدء مراقبة الإنترنت لإعادة إرسال الرسايل المعلّقة تلقائيًا
    ConnectivityService.startMonitoring();

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
      home: _initialized
          ? const HomeScreen()
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

/// دالة مطلوبة من مكتبة flutter_foreground_task - نقطة دخول العملية الخلفية.
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
