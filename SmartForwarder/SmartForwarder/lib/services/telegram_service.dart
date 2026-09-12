import 'dart:convert';
import 'package:http/http.dart' as http;

class TelegramResult {
  final bool success;
  final String? errorReason;
  TelegramResult({required this.success, this.errorReason});
}

class TelegramService {
  /// إرسال رسالة نصية لتليجرام. بيرجع نتيجة واضحة (نجاح/فشل + سبب الفشل)
  /// عشان نقدر نسجلها في الـ Log بدقة.
  static Future<TelegramResult> send({
    required String botToken,
    required String chatId,
    required String message,
  }) async {
    if (botToken.trim().isEmpty || chatId.trim().isEmpty) {
      return TelegramResult(success: false, errorReason: 'بيانات البوت أو الـ Chat ID ناقصة');
    }

    final url = Uri.parse('https://api.telegram.org/bot$botToken/sendMessage');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'chat_id': chatId,
              'text': message,
              'parse_mode': 'Markdown',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return TelegramResult(success: true);
      } else {
        final body = jsonDecode(response.body);
        final desc = body['description'] ?? 'خطأ غير معروف من تليجرام';
        return TelegramResult(success: false, errorReason: 'HTTP ${response.statusCode}: $desc');
      }
    } catch (e) {
      return TelegramResult(success: false, errorReason: 'خطأ في الاتصال: ${e.toString()}');
    }
  }
}
