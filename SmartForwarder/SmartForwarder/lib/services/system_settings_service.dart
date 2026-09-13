import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:device_info_plus/device_info_plus.dart';

class SystemSettingsService {
  static const Map<String, Map<String, String>> _autoStartIntents = {
    'xiaomi': {
      'package': 'com.miui.securitycenter',
      'component': 'com.miui.permcenter.autostart.AutoStartManagementActivity',
    },
    'redmi': {
      'package': 'com.miui.securitycenter',
      'component': 'com.miui.permcenter.autostart.AutoStartManagementActivity',
    },
    'poco': {
      'package': 'com.miui.securitycenter',
      'component': 'com.miui.permcenter.autostart.AutoStartManagementActivity',
    },
    'oppo': {
      'package': 'com.coloros.safecenter',
      'component': 'com.coloros.safecenter.permission.startup.StartupAppListActivity',
    },
    'realme': {
      'package': 'com.coloros.safecenter',
      'component': 'com.coloros.safecenter.permission.startup.StartupAppListActivity',
    },
    'vivo': {
      'package': 'com.iqoo.secure',
      'component': 'com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity',
    },
    'huawei': {
      'package': 'com.huawei.systemmanager',
      'component': 'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
    },
    'honor': {
      'package': 'com.huawei.systemmanager',
      'component': 'com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
    },
    'asus': {
      'package': 'com.asus.mobilemanager',
      'component': 'com.asus.mobilemanager.autostart.AutoStartActivity',
    },
    'letv': {
      'package': 'com.letv.android.letvsafe',
      'component': 'com.letv.android.letvsafe.AutobootManageActivity',
    },
    'samsung': {
      'package': 'com.samsung.android.lool',
      'component': 'com.samsung.android.sm.ui.battery.BatteryActivity',
    },
  };

  static Future<bool> requestIgnoreBatteryOptimization() async {
    try {
      return await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    } catch (e) {
      debugPrint('battery optimization request failed: $e');
      return false;
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (e) {
      debugPrint('battery optimization check failed: $e');
      return false;
    }
  }

  static Future<String?> _detectManufacturer() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.manufacturer.toLowerCase();
    } catch (e) {
      debugPrint('manufacturer detection failed: $e');
      return null;
    }
  }

  static Future<bool> openAutoStartSettings() async {
    final manufacturer = await _detectManufacturer();
    if (manufacturer == null) return false;

    final match = _autoStartIntents[manufacturer];
    if (match == null) return false;

    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: match['package'],
        componentName: match['component'],
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('autostart settings intent failed: $e');
      return false;
    }
  }

  static Future<bool> hasKnownAutoStartScreen() async {
    final manufacturer = await _detectManufacturer();
    return manufacturer != null && _autoStartIntents.containsKey(manufacturer);
  }

  static Future<void> openAppDetailsSettings() async {
    try {
      const intent = AndroidIntent(
        action: 'action_application_details_settings',
        data: 'package:com.mywork.smart_forwarder',
      );
      await intent.launch();
    } catch (e) {
      debugPrint('app details settings intent failed: $e');
    }
  }
}
