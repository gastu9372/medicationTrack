import 'dart:convert';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';

class MedsController {
  static const _channel = MethodChannel('com.example.medstracker/alarms');
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Method to request overlay permission on Android
  Future<bool> checkAndRequestPermissions() async {
    try {
      bool hasOverlay = await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
      if (!hasOverlay) {
        await _channel.invokeMethod('requestOverlayPermission');
      }

      bool hasExactAlarm = await _channel.invokeMethod<bool>('checkExactAlarmPermission') ?? false;
      if (!hasExactAlarm) {
        await _channel.invokeMethod('requestExactAlarmPermission');
      }

      return hasOverlay && hasExactAlarm;
    } catch (e) {
      print("Error managing permissions: $e");
      return false;
    }
  }

  // --- CRUD Medicines ---

  Future<int> addMedicine({
    required String name,
    required String dosage,
    required String scheduleType,
    required List<String> scheduleTimes,
  }) async {
    // 1. Insert medication
    final medId = await _dbHelper.insertMedicine({
      'name': name,
      'dosage': dosage,
      'schedule_type': scheduleType,
      'schedule_value': jsonEncode(scheduleTimes),
      'is_active': 1,
    });

    // 2. Schedule alarms for each time slot
    for (String timeStr in scheduleTimes) {
      await _scheduleNextAlarm(medId, timeStr);
    }

    return medId;
  }

  Future<List<Map<String, dynamic>>> getAllMedicines() async {
    return await _dbHelper.queryAllMedicines();
  }

  Future<void> deleteMedicine(int id) async {
    // Cancel any active alarms in the system before deleting from database
    final alarms = await _dbHelper.queryAlarmsForDay(
      DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
    );
    for (var alarm in alarms) {
      if (alarm['medicine_id'] == id && alarm['status'] == 'pending') {
        await _channel.invokeMethod('cancelAlarm', {'alarmId': alarm['id']});
      }
    }
    await _dbHelper.deleteMedicine(id);
  }

  // --- Internal Alarm Schedulers ---

  Future<void> _scheduleNextAlarm(int medicineId, String timeStr) async {
    final nextTime = _calculateNextOccurrence(timeStr);
    final triggerTimeMs = nextTime.millisecondsSinceEpoch;

    // 1. Insert alarm into SQLite in pending state
    final alarmId = await _dbHelper.insertAlarm({
      'medicine_id': medicineId,
      'scheduled_time': triggerTimeMs,
      'status': 'pending',
    });

    // 2. Schedule the alarm in Android's AlarmManager via MethodChannel
    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'alarmId': alarmId,
        'triggerTimeMs': triggerTimeMs,
        'medicineId': medicineId,
      });
      print("Scheduled alarm ID $alarmId at $nextTime for medicine $medicineId");
    } catch (e) {
      print("Failed to schedule alarm via platform channel: $e");
    }
  }

  DateTime _calculateNextOccurrence(String timeStr) {
    // Expects "HH:mm" format (e.g. "08:30" or "20:00")
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = DateTime.now();
    var scheduledDateTime = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduledDateTime.isBefore(now)) {
      // If the time has already passed today, schedule for tomorrow
      scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
    }
    return scheduledDateTime;
  }

  // --- Tracker / Compliance Ops ---

  Future<List<Map<String, dynamic>>> getTodayTimeline() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

    // Fetch scheduled alarms and compliance logs for today
    final alarms = await _dbHelper.queryAlarmsForDay(startOfDay, endOfDay);
    return alarms;
  }

  Future<void> markTaken(int alarmId, int medicineId, int scheduledTimeMs) async {
    await _dbHelper.updateAlarmStatus(alarmId, 'taken');
    await _dbHelper.insertComplianceLog({
      'medicine_id': medicineId,
      'scheduled_time': scheduledTimeMs,
      'status': 'taken',
      'action_time': DateTime.now().millisecondsSinceEpoch,
    });
    // Stop system alarm in case it's currently ringing
    try {
      await _channel.invokeMethod('cancelAlarm', {'alarmId': alarmId});
    } catch (_) {}
  }

  Future<void> markSnoozed(int alarmId, int medicineId, int scheduledTimeMs) async {
    await _dbHelper.updateAlarmStatus(alarmId, 'snoozed');
    await _dbHelper.insertComplianceLog({
      'medicine_id': medicineId,
      'scheduled_time': scheduledTimeMs,
      'status': 'snoozed',
      'action_time': DateTime.now().millisecondsSinceEpoch,
    });

    // Schedule next trigger in 15 minutes
    final snoozeTime = DateTime.now().add(const Duration(minutes: 15));
    final triggerTimeMs = snoozeTime.millisecondsSinceEpoch;

    final newAlarmId = await _dbHelper.insertAlarm({
      'medicine_id': medicineId,
      'scheduled_time': triggerTimeMs,
      'status': 'pending',
    });

    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'alarmId': newAlarmId,
        'triggerTimeMs': triggerTimeMs,
        'medicineId': medicineId,
      });
      await _channel.invokeMethod('cancelAlarm', {'alarmId': alarmId});
    } catch (_) {}
  }
}
