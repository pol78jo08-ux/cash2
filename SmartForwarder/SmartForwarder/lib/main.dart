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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final smsStatus = await Permission.sms.request();
      if (!smsStatus.isGranted) return;

      try {
        await Permission.notification.request();
      } catch (e) {}

      await FlutterForegroundTask.requestIgnoreBatteryOptimization();

      _initForegroundTask();

      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) {
        try {
          await FlutterForegroundTask.startService(
            notificationTitle: 'Smart Forwarder شغال',
            notificationText: 'جاري مراقبة الرسائل النصية',
            callback: startCallback,
          );
        } catch (e) {}
      }

      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          SmsProcessor.processIncomingMessage(message);
        },
        onBackgroundMessage: backgroundMessageHandler,
        listenInBackground: true,
      );

      ConnectivityService.startMonitoring();
    } catch (e) {}

    if (mounted) {
      setState(() => _initialized = true);
    }
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
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
