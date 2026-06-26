import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('meds_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const integerDefaultType = 'INTEGER DEFAULT 1';
    const integerDefaultZero = 'INTEGER DEFAULT 0';

    // 1. Medicines Table
    await db.execute('''
      CREATE TABLE medicines (
        id $idType,
        name $textType,
        dosage $textType,
        schedule_type $textType,
        schedule_value $textNullableType,
        is_active $integerDefaultType
      )
    ''');

    // 2. Alarms Table (Scheduled alarms on Android side)
    await db.execute('''
      CREATE TABLE alarms (
        id $idType,
        medicine_id $integerType,
        scheduled_time $integerType,
        status TEXT DEFAULT 'pending',
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');

    // 3. Compliance Logs Table (History)
    await db.execute('''
      CREATE TABLE compliance_logs (
        id $idType,
        medicine_id $integerType,
        scheduled_time $integerType,
        action_time INTEGER,
        status $textType,
        snooze_count $integerDefaultZero,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- Medicine CRUD ---
  Future<int> insertMedicine(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('medicines', row);
  }

  Future<List<Map<String, dynamic>>> queryAllMedicines() async {
    final db = await instance.database;
    return await db.query('medicines');
  }

  Future<int> updateMedicine(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update(
      'medicines',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMedicine(int id) async {
    final db = await instance.database;
    // Delete cascading alarms & compliance logs first just in case
    await db.delete('alarms', where: 'medicine_id = ?', whereArgs: [id]);
    return await db.delete(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Alarms operations ---
  Future<int> insertAlarm(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('alarms', row);
  }

  Future<List<Map<String, dynamic>>> queryAlarmsForDay(int startMs, int endMs) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT a.*, m.name, m.dosage 
      FROM alarms a
      JOIN medicines m ON a.medicine_id = m.id
      WHERE a.scheduled_time >= ? AND a.scheduled_time <= ?
      ORDER BY a.scheduled_time ASC
    ''', [startMs, endMs]);
  }

  Future<int> updateAlarmStatus(int id, String status) async {
    final db = await instance.database;
    return await db.update(
      'alarms',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePendingAlarmsForMedicine(int medicineId) async {
    final db = await instance.database;
    return await db.delete(
      'alarms',
      where: "medicine_id = ? AND status = 'pending'",
      whereArgs: [medicineId],
    );
  }

  // --- Compliance Logs operations ---
  Future<int> insertComplianceLog(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('compliance_logs', row);
  }

  Future<List<Map<String, dynamic>>> queryComplianceLogsForDay(int startMs, int endMs) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.*, m.name, m.dosage 
      FROM compliance_logs c
      JOIN medicines m ON c.medicine_id = m.id
      WHERE c.scheduled_time >= ? AND c.scheduled_time <= ?
      ORDER BY c.scheduled_time ASC
    ''', [startMs, endMs]);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
