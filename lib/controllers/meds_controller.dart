import 'dart:convert';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';

class MedsController {
  static const _channel = MethodChannel('com.example.medstracker/alarms');
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Method to request overlay permission on Android
  Future<bool> checkAndRequestPermissions() async {
    try {
      bool hasNotification = await _channel.invokeMethod<bool>('checkNotificationPermission') ?? false;
      if (!hasNotification) {
        await _channel.invokeMethod('requestNotificationPermission');
      }

      bool hasOverlay = await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
      if (!hasOverlay) {
        await _channel.invokeMethod('requestOverlayPermission');
      }

      bool hasExactAlarm = await _channel.invokeMethod<bool>('checkExactAlarmPermission') ?? false;
      if (!hasExactAlarm) {
        await _channel.invokeMethod('requestExactAlarmPermission');
      }

      return hasNotification && hasOverlay && hasExactAlarm;
    } catch (e) {
      print("Error managing permissions: $e");
      return false;
    }
  }

  // Check the individual status of each permission
  Future<Map<String, bool>> checkPermissionsDetail() async {
    try {
      bool hasNotification = await _channel.invokeMethod<bool>('checkNotificationPermission') ?? false;
      bool hasOverlay = await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
      bool hasExactAlarm = await _channel.invokeMethod<bool>('checkExactAlarmPermission') ?? false;
      return {
        'notification': hasNotification,
        'overlay': hasOverlay,
        'exactAlarm': hasExactAlarm,
      };
    } catch (_) {
      return {
        'notification': false,
        'overlay': false,
        'exactAlarm': false,
      };
    }
  }

  // --- CRUD Medicines ---

  Future<int> addMedicine({
    required String name,
    required String dosage,
    required String scheduleType,
    required List<String> scheduleTimes,
    List<int>? selectedDays,
  }) async {
    // 1. Insert medication
    final medId = await _dbHelper.insertMedicine({
      'name': name,
      'dosage': dosage,
      'schedule_type': scheduleType,
      'schedule_value': jsonEncode({
        'times': scheduleTimes,
        'days': selectedDays ?? [],
      }),
      'is_active': 1,
    });

    // 2. Schedule alarms for each time slot
    for (String timeStr in scheduleTimes) {
      await _scheduleAlarmForTime(medId, timeStr, scheduleType, selectedDays);
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
        try {
          await _channel.invokeMethod('cancelAlarm', {'alarmId': alarm['id']});
        } catch (_) {}
      }
    }
    await _dbHelper.deleteMedicine(id);
  }

  Future<void> updateMedicine({
    required int id,
    required String name,
    required String dosage,
    required String scheduleType,
    required List<String> scheduleTimes,
    List<int>? selectedDays,
  }) async {
    // 1. Update medication in database
    await _dbHelper.updateMedicine({
      'id': id,
      'name': name,
      'dosage': dosage,
      'schedule_type': scheduleType,
      'schedule_value': jsonEncode({
        'times': scheduleTimes,
        'days': selectedDays ?? [],
      }),
      'is_active': 1,
    });

    // 2. Cancel and delete all pending alarms for this medicine
    final alarms = await _dbHelper.queryAlarmsForDay(
      DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
    );
    for (var alarm in alarms) {
      if (alarm['medicine_id'] == id && alarm['status'] == 'pending') {
        try {
          await _channel.invokeMethod('cancelAlarm', {'alarmId': alarm['id']});
        } catch (_) {}
      }
    }
    await _dbHelper.deletePendingAlarmsForMedicine(id);

    // 3. Reschedule the new alarms for this medicine
    for (String timeStr in scheduleTimes) {
      await _scheduleAlarmForTime(id, timeStr, scheduleType, selectedDays);
    }
  }

  // --- Internal Alarm Schedulers ---

  Future<void> _scheduleAlarmForTime(
    int medicineId,
    String timeStr,
    String scheduleType,
    List<int>? selectedDays,
  ) async {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = DateTime.now();

    if (scheduleType == 'daily') {
      final todayTime = DateTime(now.year, now.month, now.day, hour, minute);

      if (todayTime.isBefore(now)) {
        // 1. Create a placeholder alarm for today (passed) so it shows in today's timeline
        await _dbHelper.insertAlarm({
          'medicine_id': medicineId,
          'scheduled_time': todayTime.millisecondsSinceEpoch,
          'status': 'pending',
        });

        // 2. Create and schedule the actual alarm for tomorrow
        final tomorrowTime = todayTime.add(const Duration(days: 1));
        final tomorrowAlarmId = await _dbHelper.insertAlarm({
          'medicine_id': medicineId,
          'scheduled_time': tomorrowTime.millisecondsSinceEpoch,
          'status': 'pending',
        });

        await _registerSystemAlarm(tomorrowAlarmId, tomorrowTime.millisecondsSinceEpoch, medicineId);
        print("Scheduled tomorrow's alarm ID $tomorrowAlarmId at $tomorrowTime for medicine $medicineId");
      } else {
        // The time is in the future today, schedule normally
        final alarmId = await _dbHelper.insertAlarm({
          'medicine_id': medicineId,
          'scheduled_time': todayTime.millisecondsSinceEpoch,
          'status': 'pending',
        });

        await _registerSystemAlarm(alarmId, todayTime.millisecondsSinceEpoch, medicineId);
        print("Scheduled today's alarm ID $alarmId at $todayTime for medicine $medicineId");
      }
    } else {
      // Days of the week
      final List<int> days = selectedDays ?? [];
      if (days.isEmpty) return;

      final targetTime = _calculateNextOccurrenceForDays(timeStr, days);

      final alarmId = await _dbHelper.insertAlarm({
        'medicine_id': medicineId,
        'scheduled_time': targetTime.millisecondsSinceEpoch,
        'status': 'pending',
      });

      await _registerSystemAlarm(alarmId, targetTime.millisecondsSinceEpoch, medicineId);
      print("Scheduled custom days alarm ID $alarmId at $targetTime for medicine $medicineId");

      // Add a placeholder for today if today was a selected day but the time has already passed
      if (days.contains(now.weekday)) {
        final todayTime = DateTime(now.year, now.month, now.day, hour, minute);
        if (todayTime.isBefore(now)) {
          await _dbHelper.insertAlarm({
            'medicine_id': medicineId,
            'scheduled_time': todayTime.millisecondsSinceEpoch,
            'status': 'pending',
          });
        }
      }
    }
  }

  DateTime _calculateNextOccurrenceForDays(String timeStr, List<int> selectedDays) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = DateTime.now();

    for (int i = 0; i < 8; i++) {
      final candidateDate = now.add(Duration(days: i));
      final candidateDayOfWeek = candidateDate.weekday; // 1 = Monday, 7 = Sunday

      if (selectedDays.contains(candidateDayOfWeek)) {
        final scheduledTime = DateTime(
          candidateDate.year,
          candidateDate.month,
          candidateDate.day,
          hour,
          minute,
        );

        // If candidate is today but the time already passed, skip today
        if (i == 0 && scheduledTime.isBefore(now)) {
          continue;
        }
        return scheduledTime;
      }
    }
    return now.add(const Duration(days: 1));
  }

  Future<void> _registerSystemAlarm(int alarmId, int triggerTimeMs, int medicineId) async {
    try {
      await _channel.invokeMethod('scheduleAlarm', {
        'alarmId': alarmId,
        'triggerTimeMs': triggerTimeMs,
        'medicineId': medicineId,
      });
    } catch (e) {
      print("Failed to schedule system alarm: $e");
    }
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

  Future<void> markMissed(int alarmId, int medicineId, int scheduledTimeMs) async {
    await _dbHelper.updateAlarmStatus(alarmId, 'missed');
    await _dbHelper.insertComplianceLog({
      'medicine_id': medicineId,
      'scheduled_time': scheduledTimeMs,
      'status': 'missed',
      'action_time': DateTime.now().millisecondsSinceEpoch,
    });
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

  Future<Map<int, double>> getWeeklyCompliance() async {
    final now = DateTime.now();
    // Find the Monday of the current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day, 0, 0, 0).millisecondsSinceEpoch;

    // Find the Sunday of the current week
    final sunday = monday.add(const Duration(days: 6));
    final endOfWeek = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59).millisecondsSinceEpoch;

    final alarms = await _dbHelper.queryAlarmsForDay(startOfWeek, endOfWeek);

    final Map<int, double> complianceMap = {};
    for (int day = 1; day <= 7; day++) {
      final dayAlarms = alarms.where((alarm) {
        final alarmDate = DateTime.fromMillisecondsSinceEpoch(alarm['scheduled_time']);
        return alarmDate.weekday == day;
      }).toList();

      final activeAlarms = dayAlarms.where((alarm) => alarm['status'] != 'snoozed').toList();
      if (activeAlarms.isEmpty) {
        complianceMap[day] = -1.0; // No alarms scheduled
      } else {
        final takenCount = activeAlarms.where((alarm) => alarm['status'] == 'taken').length;
        complianceMap[day] = takenCount / activeAlarms.length;
      }
    }
    return complianceMap;
  }
}
