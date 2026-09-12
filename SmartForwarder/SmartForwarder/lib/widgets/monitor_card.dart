import 'package:flutter/material.dart';
import '../models/monitor.dart';

class MonitorCard extends StatelessWidget {
  final Monitor monitor;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  const MonitorCard({
    super.key,
    required this.monitor,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: monitor.isEnabled
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sms_outlined,
                  color: monitor.isEnabled ? const Color(0xFF16A34A) : Colors.grey,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(monitor.label,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      'المرسل: ${monitor.senderPattern}',
                      style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                    Text(
                      'الوجهة: ${monitor.chatId}',
                      style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Switch(value: monitor.isEnabled, onChanged: onToggle),
            ],
          ),
        ),
      ),
    );
  }
}
