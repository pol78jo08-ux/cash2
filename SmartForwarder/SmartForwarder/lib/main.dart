import 'dart:async';
import 'dart:io' show Platform;
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
  bool _serviceStarted = false;

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
      _log(' بدء التهيئة...');

      // 1. طلب الصلاحيات
      final smsStatus = await Permission.sms.request();
      _log('📩 صلاحية SMS: ${smsStatus.isGranted ? "مسموحة ✅" : "مرفوضة ❌"}');

      try {
        await Permission.notification.request();
        _log(' صلاحية الإشعارات: تم الطلب');
      } catch (e) {
        _log(' الإشعارات: مش مطلوبة في النسخة دي');
      }

      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      _log('🔋 استثناء البطارية: تم الطلب');

      // 2. تهيئة Foreground Task
      _initForegroundTask();
      _log('⚙️ تهيئة إعدادات الخدمة: تمت');

      // 3. بدء الخدمة الخلفية - بدون await لتجنب Timeout
      _log('🚀 محاولة بدء الخدمة الخلفية...');
      
      // نستخدم Future.timeout لتجنب التعليق
      try {
        await FlutterForegroundTask.startService(
          notificationTitle: 'Smart Forwarder شغال',
          notificationText: 'جاري مراقبة الرسائل النصية',
          callback: startCallback,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            _log('⚠️ الخدمة أخدت وقت طويل لكن هتشتغل في الخلفية');
            return true;
          },
        );
        _serviceStarted = true;
        _log('🚀 بدء الخدمة الخلفية: نجح ✅');
      } catch (e) {
        // لو حصل TimeoutException أو أي خطأ، نتجاهله ونكمل
        _serviceStarted = false;
        _log('⚠️ الخدمة الخلفية: فيها تحذير لكن التطبيق شغال');
      }

      // 4. الاستماع لرسائل SMS
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          SmsProcessor.processIncomingMessage(message);
        },
        onBackgroundMessage: backgroundMessageHandler,
        listenInBackground: true,
      );
      _log('👂 بدء الاستماع لرسائل SMS: تم');

      // 5. مراقبة الإنترنت
      ConnectivityService.startMonitoring();
      _log('🌐 مراقبة الاتصال بالإنترنت: بدأت');

      _log('✅ كل حاجة اشتغلت بنجاح!');
    } catch (e, stackTrace) {
      _log(' حصل خطأ: $e\nStack: $stackTrace');
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

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'smart_forwarder_channel',
        channelName: 'Smart Forwarder Service',
        channelDescription: 'خدمة مراقبة الرسائل النصية',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
        isSticky: true,
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
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: !_initialized
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _buildDiagnosticScreen(),
    );
  }

  Widget _buildDiagnosticScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التشغيل (تشخيص)'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _statusLog,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _navigateToHome,
                icon: const Icon(Icons.arrow_forward),
                label: const Text(
                  'الدخول للتطبيق',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToHome() async {
    try {
      if (!mounted) return;
      
      // استخدام push بدل pushReplacement لتجنب مشاكل الـ context
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
          settings: const RouteSettings(name: 'home'),
        ),
      );
      
      // لو رجع من HomeScreen، نعرض رسالة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الرجوع للشاشة التشخيصية'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('❌ خطأ'),
            content: SelectableText(
              'فشل فتح الشاشة الرئيسية:\n\n$e\n\n$st',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_ForwarderTaskHandler());
}

class _ForwarderTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('✅ Foreground service started at: $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // مفيش حاجة دورية محتاجينها حالياً
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('🛑 Foreground service destroyed at: $timestamp');
  }
}
