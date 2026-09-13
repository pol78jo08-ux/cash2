import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'screens/home_screen.dart';
import 'services/sms_service.dart';
import 'services/connectivity_service.dart';
import 'services/system_settings_service.dart';
import 'theme/app_theme.dart';

final Telephony telephony = Telephony.instance;

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterForegroundTask.initCommunicationPort();
    runApp(const SmartForwarderApp());
  }, (error, stackTrace) {
    debugPrint('Uncaught: $error\n$stackTrace');
  });
}

class SmartForwarderApp extends StatefulWidget {
  const SmartForwarderApp({super.key});

  @override
  State<SmartForwarderApp> createState() => _SmartForwarderAppState();
}

class _SmartForwarderAppState extends State<SmartForwarderApp> {
  bool _initialized = false;
  final List<String> _issues = [];
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final smsStatus = await Permission.sms.request();
      if (!smsStatus.isGranted) {
        _issues.add('صلاحية قراءة الرسائل (SMS) مش متاحة - التطبيق مش هيقدر يرصد أي رسالة جديدة.');
      }

      try {
        await Permission.notification.request();
      } catch (_) {
        // مش مطلوبة في نسخ أندرويد الأقدم من 13
      }

      await SystemSettingsService.requestIgnoreBatteryOptimization();
      final batteryOk = await SystemSettingsService.isIgnoringBatteryOptimizations();
      if (!batteryOk) {
        _issues.add('توفير البطارية لسه شغال على التطبيق - ممكن الخدمة توقف نفسها في الخلفية.');
      }

      SystemSettingsService.openAutoStartSettings();

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

      final bool alreadyRunning = await FlutterForegroundTask.isRunningService;
      final serviceResult = alreadyRunning
          ? await FlutterForegroundTask.restartService()
          : await FlutterForegroundTask.startService(
              notificationTitle: 'Smart Forwarder شغال',
              notificationText: 'جاري مراقبة الرسائل النصية',
              callback: startCallback,
            );

      if (serviceResult is ServiceRequestFailure) {
        _issues.add('الخدمة اللي بتراقب الرسائل في الخلفية فشلت تبدأ (${serviceResult.error}).');
      }

      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          SmsProcessor.processIncomingMessage(message);
        },
        onBackgroundMessage: backgroundMessageHandler,
        listenInBackground: true,
      );

      ConnectivityService.startMonitoring();
    } catch (e) {
      _issues.add('حصل خطأ غير متوقع أثناء بدء التطبيق: $e');
    }

    if (mounted) {
      setState(() => _initialized = true);
      if (_issues.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showIssuesDialog());
      }
    }
  }

  void _showIssuesDialog() {
    final ctx = _navigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('في حاجات محتاجة انتباهك'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _issues
                .map((issue) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $issue'),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await SystemSettingsService.openAppDetailsSettings();
            },
            child: const Text('فتح إعدادات التطبيق'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
          : const HomeScreen(),
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
