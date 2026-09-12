import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<LogEntry> _logs = [];
  bool _loading = true;
  LogStatus? _filter;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getLogs();
    setState(() {
      _logs = data;
      _loading = false;
    });
  }

  List<LogEntry> get _filteredLogs {
    if (_filter == null) return _logs;
    return _logs.where((l) => l.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الرسائل')),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                    ? const Center(child: Text('مفيش سجلات بعد'))
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _filteredLogs.length,
                          itemBuilder: (ctx, i) => _logTile(_filteredLogs[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _chip('الكل', null),
          const SizedBox(width: 8),
          _chip('نجح', LogStatus.success),
          const SizedBox(width: 8),
          _chip('فشل', LogStatus.failed),
          const SizedBox(width: 8),
          _chip('بانتظار', LogStatus.queued),
        ],
      ),
    );
  }

  Widget _chip(String text, LogStatus? status) {
    final selected = _filter == status;
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => setState(() => _filter = status),
    );
  }

  Widget _logTile(LogEntry log) {
    final color = AppTheme.statusColor(log.status.name);
    final time = DateFormat('yyyy-MM-dd  HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(log.timestamp),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    log.status.label,
                    style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(time, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),
            Text(log.monitorLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text('المرسل: ${log.sender}', style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
            const SizedBox(height: 6),
            Text(
              log.messageBody,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
            if (log.errorReason != null) ...[
              const SizedBox(height: 6),
              Text(
                'السبب: ${log.errorReason}',
                style: TextStyle(fontSize: 11.5, color: AppTheme.danger),
              ),
            ],
            if (log.retryCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'عدد المحاولات: ${log.retryCount}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
