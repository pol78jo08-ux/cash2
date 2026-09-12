import re

MANIFEST_PATH = "android/app/src/main/AndroidManifest.xml"
SETTINGS_GRADLE_PATH = "android/settings.gradle"

NEW_KOTLIN_VERSION = "2.1.0"

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
    manifest_content = f.read()

if "RECEIVE_SMS" not in manifest_content:
    manifest_content = manifest_content.replace(
        "<application", PERMISSIONS + "\n    <application", 1
    )

with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
    f.write(manifest_content)

print("AndroidManifest.xml patched successfully.")

with open(SETTINGS_GRADLE_PATH, "r", encoding="utf-8") as f:
    settings_content = f.read()

settings_content_new = re.sub(
    r'(id\s+"org\.jetbrains\.kotlin\.android"\s+version\s+")[\d.]+(")',
    r"\g<1>" + NEW_KOTLIN_VERSION + r"\g<2>",
    settings_content,
)

with open(SETTINGS_GRADLE_PATH, "w", encoding="utf-8") as f:
    f.write(settings_content_new)

print(f"Kotlin plugin version bumped to {NEW_KOTLIN_VERSION} in settings.gradle.")
