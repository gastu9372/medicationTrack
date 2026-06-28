package com.example.meds_tracker

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.util.Log

class DatabaseHelper(private val context: Context) {

    private fun getWritableDatabase(): SQLiteDatabase? {
        return try {
            val dbFile = context.getDatabasePath("meds_tracker.db")
            if (!dbFile.exists()) {
                Log.e("DatabaseHelper", "Database file does not exist yet.")
                return null
            }
            SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
        } catch (e: Exception) {
            Log.e("DatabaseHelper", "Error opening database: ${e.message}")
            null
        }
    }

    private fun getReadableDatabase(): SQLiteDatabase? {
        return try {
            val dbFile = context.getDatabasePath("meds_tracker.db")
            if (!dbFile.exists()) {
                Log.e("DatabaseHelper", "Database file does not exist yet.")
                return null
            }
            SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
        } catch (e: Exception) {
            Log.e("DatabaseHelper", "Error opening database: ${e.message}")
            null
        }
    }

    fun getMedicineDetails(medicineId: Int): Pair<String, String>? {
        val db = getReadableDatabase() ?: return null
        var cursor: Cursor? = null
        try {
            cursor = db.rawQuery(
                "SELECT name, dosage FROM medicines WHERE id = ?",
                arrayOf(medicineId.toString())
            )
            if (cursor != null && cursor.moveToFirst()) {
                val nameIdx = cursor.getColumnIndexOrThrow("name")
                val dosageIdx = cursor.getColumnIndexOrThrow("dosage")
                val name = cursor.getString(nameIdx)
                val dosage = cursor.getString(dosageIdx)
                return Pair(name, dosage)
            }
        } catch (e: Exception) {
            Log.e("DatabaseHelper", "Error getting medicine details: ${e.message}")
        } finally {
            cursor?.close()
            db.close()
        }
        return null
    }

    fun markAlarmAsFired(alarmId: Int) {
        updateAlarmStatus(alarmId, "fired")
    }

    fun updateAlarmStatus(alarmId: Int, status: String) {
        val db = getWritableDatabase() ?: return
        try {
            val values = ContentValues().apply {
                put("status", status)
            }
            db.update("alarms", values, "id = ?", arrayOf(alarmId.toString()))
        } catch (e: Exception) {
            Log.e("DatabaseHelper", "Error updating alarm status: ${e.message}")
        } finally {
            db.close()
        }
    }

    fun insertComplianceLog(medicineId: Int, scheduledTime: Long, status: String, actionTime: Long, snoozeCount: Int = 0) {
        val db = getWritableDatabase() ?: return
        try {
            val values = ContentValues().apply {
                put("medicine_id", medicineId)
                put("scheduled_time", scheduledTime)
                put("status", status)
                put("action_time", actionTime)
                put("snooze_count", snoozeCount)
            }
            db.insert("compliance_logs", null, values)
        } catch (e: Exception) {
            Log.e("DatabaseHelper", "Error inserting compliance log: ${e.message}")
        } finally {
            db.close()
        }
    }

    fun scheduleNewAlarm(medicineId: Int, scheduledTimeMs: Long): Long {
        val db = getWritableDatabase() ?: return -1
        return try {
            val values = ContentValues().apply {
                put("medicine_id", medicineId)
                put("scheduled_time", scheduledTimeMs)
                put("status", "pending")
            }
            db.insert("alarms", null, values)
        } catch (e: Exception) {
            Log.e("DatabaseHelper", "Error inserting new alarm: ${e.message}")
            -1
        } finally {
            db.close()
        }
    }

    fun getPendingFutureAlarms(): List<Triple<Int, Int, Long>> {
        val db = getReadableDatabase() ?: return emptyList()
        val list = mutableListOf<Triple<Int, Int, Long>>()
        var cursor: Cursor? = null
        try {
            cursor = db.rawQuery(
                "SELECT id, medicine_id, scheduled_time FROM alarms WHERE status = 'pending' AND scheduled_time > ?",
                arrayOf(System.currentTimeMillis().toString())
            )
            if (cursor != null && cursor.moveToFirst()) {
                val idIdx = cursor.getColumnIndexOrThrow("id")
                val medIdIdx = cursor.getColumnIndexOrThrow("medicine_id")
                val timeIdx = cursor.getColumnIndexOrThrow("scheduled_time")
                do {
                    list.add(Triple(
                        cursor.getInt(idIdx),
                        cursor.getInt(medIdIdx),
                        cursor.getLong(timeIdx)
                    ))
                } while (cursor.moveToNext())
            }
        } catch (e: Exception) {
            Log.e("DatabaseHelper", "Error getting pending alarms: ${e.message}")
        } finally {
            cursor?.close()
            db.close()
        }
        return list
    }

    fun getMedicineSchedule(medicineId: Int): Pair<String, String>? {
        val db = getReadableDatabase() ?: return null
        var cursor: Cursor? = null
        try {
            cursor = db.rawQuery(
                "SELECT schedule_type, schedule_value FROM medicines WHERE id = ? AND is_active = 1",
                arrayOf(medicineId.toString())
            )
            if (cursor != null && cursor.moveToFirst()) {
                val typeIdx = cursor.getColumnIndexOrThrow("schedule_type")
                val valueIdx = cursor.getColumnIndexOrThrow("schedule_value")
                val type = cursor.getString(typeIdx)
                val value = cursor.getString(valueIdx)
                return Pair(type, value)
            }
        } catch (e: Exception) {
            Log.e("DatabaseHelper", "Error getting medicine schedule: ${e.message}")
        } finally {
            cursor?.close()
            db.close()
        }
        return null
    }
}
