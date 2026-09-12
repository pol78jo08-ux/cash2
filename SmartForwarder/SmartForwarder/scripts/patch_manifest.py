"""
يعدّل AndroidManifest.xml اللي بيتولّد تلقائيًا من أمر `flutter create`
عشان يضيف: صلاحيات SMS + صلاحيات Foreground Service + استثناء البطارية.
بيشتغل عن طريق البحث عن نصوص ثابتة موجودة في كل نسخ Flutter الحديثة.
"""
import re
import sys

MANIFEST_PATH = "android/app/src/main/AndroidManifest.xml"

PERMISSIONS = """
    <uses-permission android:name="android.permission.RECEIVE_SMS" />
    <uses-permission android:name="android.permission.READ_SMS" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
"""

with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
    content = f.read()

# إضافة الصلاحيات قبل وسم <application
if "RECEIVE_SMS" not in content:
    content = content.replace("<application", PERMISSIONS + "\n    <application", 1)

with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("AndroidManifest.xml patched successfully.")
