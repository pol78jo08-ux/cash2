import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/monitor.dart';
import '../models/log_entry.dart';

/// نقطة وصول واحدة لقاعدة البيانات - Singleton عشان كل أجزاء التطبيق
/// (الواجهة + الخدمة الخلفية) يشتغلوا على نفس الاتصال.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_forwarder.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE monitors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT NOT NULL,
            senderPattern TEXT NOT NULL,
            botToken TEXT NOT NULL,
            chatId TEXT NOT NULL,
            isEnabled INTEGER NOT NULL DEFAULT 1,
            createdAt INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            monitorId INTEGER,
            monitorLabel TEXT NOT NULL,
            sender TEXT NOT NULL,
            messageBody TEXT NOT NULL,
            status TEXT NOT NULL,
            errorReason TEXT,
            timestamp INTEGER NOT NULL,
            retryCount INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('CREATE INDEX idx_logs_status ON logs(status)');
        await db.execute('CREATE INDEX idx_logs_timestamp ON logs(timestamp)');
      },
    );
  }

  // ============ عمليات المراقبات ============

  Future<int> insertMonitor(Monitor monitor) async {
    final db = await database;
    return db.insert('monitors', monitor.toMap());
  }

  Future<int> updateMonitor(Monitor monitor) async {
    final db = await database;
    return db.update('monitors', monitor.toMap(),
        where: 'id = ?', whereArgs: [monitor.id]);
  }

  Future<int> deleteMonitor(int id) async {
    final db = await database;
    return db.delete('monitors', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Monitor>> getAllMonitors() async {
    final db = await database;
    final maps = await db.query('monitors', orderBy: 'createdAt DESC');
    return maps.map((m) => Monitor.fromMap(m)).toList();
  }

  Future<List<Monitor>> getEnabledMonitors() async {
    final db = await database;
    final maps = await db.query('monitors', where: 'isEnabled = 1');
    return maps.map((m) => Monitor.fromMap(m)).toList();
  }

  // ============ عمليات السجل ============

  Future<int> insertLog(LogEntry log) async {
    final db = await database;
    return db.insert('logs', log.toMap());
  }

  Future<int> updateLog(LogEntry log) async {
    final db = await database;
    return db.update('logs', log.toMap(), where: 'id = ?', whereArgs: [log.id]);
  }

  Future<List<LogEntry>> getLogs({int limit = 200}) async {
    final db = await database;
    final maps = await db.query('logs', orderBy: 'timestamp DESC', limit: limit);
    return maps.map((m) => LogEntry.fromMap(m)).toList();
  }

  Future<List<LogEntry>> getQueuedLogs() async {
    final db = await database;
    final maps = await db.query('logs', where: 'status = ?', whereArgs: ['queued']);
    return maps.map((m) => LogEntry.fromMap(m)).toList();
  }

  Future<void> clearOldLogs({int keepDays = 30}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: keepDays))
        .millisecondsSinceEpoch;
    await db.delete('logs', where: 'timestamp < ? AND status != ?', whereArgs: [cutoff, 'queued']);
  }
}
