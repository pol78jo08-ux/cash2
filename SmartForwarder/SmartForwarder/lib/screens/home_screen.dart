import 'package:flutter/material.dart';
import '../models/monitor.dart';
import '../db/database_helper.dart';
import '../widgets/monitor_card.dart';
import 'add_edit_monitor_screen.dart';
import 'logs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Monitor> _monitors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMonitors();
  }

  Future<void> _loadMonitors() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getAllMonitors();
    setState(() {
      _monitors = data;
      _loading = false;
    });
  }

  Future<void> _toggleMonitor(Monitor monitor, bool value) async {
    await DatabaseHelper.instance.updateMonitor(monitor.copyWith(isEnabled: value));
    _loadMonitors();
  }

  Future<void> _openMonitor(Monitor? monitor) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditMonitorScreen(existingMonitor: monitor)),
    );
    if (result == true) _loadMonitors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المراقبات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'السجل',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogsScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _monitors.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _loadMonitors,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: _monitors.length,
                    itemBuilder: (ctx, i) {
                      final m = _monitors[i];
                      return MonitorCard(
                        monitor: m,
                        onTap: () => _openMonitor(m),
                        onToggle: (v) => _toggleMonitor(m, v),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMonitor(null),
        icon: const Icon(Icons.add),
        label: const Text('مراقبة جديدة'),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'مفيش مراقبات لسه',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'اضغط على "مراقبة جديدة" عشان تبدأ تحدد رسايل مين تتبع لتليجرام',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
