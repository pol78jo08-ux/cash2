"""
يعدّل ملفات الأندرويد اللي بتتولّد تلقائيًا من أمر `flutter create`:
1) AndroidManifest.xml: إضافة صلاحيات SMS + Foreground Service + استثناء البطارية.
2) settings.gradle: رفع إصدار Kotlin Gradle Plugin و Android Gradle Plugin (AGP)
   عشان يتوافقوا مع بعض ومع المكتبات الحديثة (shared_preferences وغيرها).
3) gradle-wrapper.properties: رفع إصدار Gradle نفسه عشان يدعم إصدار AGP الجديد.
"""
import re

MANIFEST_PATH = "android/app/src/main/AndroidManifest.xml"
SETTINGS_GRADLE_PATH = "android/settings.gradle"
WRAPPER_PROPS_PATH = "android/gradle/wrapper/gradle-wrapper.properties"
APP_BUILD_GRADLE_PATH = "android/app/build.gradle"

NEW_KOTLIN_VERSION = "1.9.22"
NEW_AGP_VERSION = "7.4.2"
NEW_GRADLE_DIST = "https\\://services.gradle.org/distributions/gradle-8.0-all.zip"
NDK_VERSION = "25.1.8937393"

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

# ---------- 1) تعديل الـ Manifest ----------
with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
    manifest_content = f.read()

if "RECEIVE_SMS" not in manifest_content:
    manifest_content = manifest_content.replace(
        "<application", PERMISSIONS + "\n    <application", 1
    )

with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
    f.write(manifest_content)

print("AndroidManifest.xml patched successfully.")

# ---------- 2) رفع إصدار Kotlin و AGP في settings.gradle ----------
with open(SETTINGS_GRADLE_PATH, "r", encoding="utf-8") as f:
    settings_content = f.read()

settings_content = re.sub(
    r'(id\s+"org\.jetbrains\.kotlin\.android"\s+version\s+")[\d.]+(")',
    r"\g<1>" + NEW_KOTLIN_VERSION + r"\g<2>",
    settings_content,
)

settings_content = re.sub(
    r'(id\s+"com\.android\.application"\s+version\s+")[\d.]+(")',
    r"\g<1>" + NEW_AGP_VERSION + r"\g<2>",
    settings_content,
)

with open(SETTINGS_GRADLE_PATH, "w", encoding="utf-8") as f:
    f.write(settings_content)

print(f"Kotlin plugin bumped to {NEW_KOTLIN_VERSION}, AGP bumped to {NEW_AGP_VERSION}.")

# ---------- 3) رفع إصدار Gradle نفسه ----------
with open(WRAPPER_PROPS_PATH, "r", encoding="utf-8") as f:
    wrapper_content = f.read()

wrapper_content = re.sub(
    r"distributionUrl=.*",
    "distributionUrl=" + NEW_GRADLE_DIST,
    wrapper_content,
)

with open(WRAPPER_PROPS_PATH, "w", encoding="utf-8") as f:
    f.write(wrapper_content)

print("Gradle wrapper bumped to 8.0.")

# ---------- 4) توحيد إصدار NDK (المكتبات محتاجة نسخة أحدث من الافتراضية) ----------
with open(APP_BUILD_GRADLE_PATH, "r", encoding="utf-8") as f:
    app_gradle_content = f.read()

if "ndkVersion" not in app_gradle_content:
    app_gradle_content = re.sub(
        r"(android\s*\{)",
        r'\1\n    ndkVersion = "' + NDK_VERSION + '"',
        app_gradle_content,
        count=1,
    )

with open(APP_BUILD_GRADLE_PATH, "w", encoding="utf-8") as f:
    f.write(app_gradle_content)

print(f"ndkVersion set to {NDK_VERSION} in app/build.gradle.")

# ---------- 5) رفع minSdkVersion لـ 23 (مطلوبة من مكتبة telephony) ----------
with open(APP_BUILD_GRADLE_PATH, "r", encoding="utf-8") as f:
    app_gradle_content = f.read()

app_gradle_content = re.sub(
    r"minSdkVersion\s+flutter\.minSdkVersion",
    "minSdkVersion 23",
    app_gradle_content,
)
# احتياطي: لو الصيغة كانت رقم ثابت بدل flutter.minSdkVersion
app_gradle_content = re.sub(
    r"minSdkVersion\s+\d+",
    "minSdkVersion 23",
    app_gradle_content,
)

with open(APP_BUILD_GRADLE_PATH, "w", encoding="utf-8") as f:
    f.write(app_gradle_content)

print("minSdkVersion set to 23.")
