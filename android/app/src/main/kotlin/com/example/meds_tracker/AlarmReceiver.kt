package com.example.meds_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Calendar
import org.json.JSONObject

class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getIntExtra("alarm_id", -1)
        val medicineId = intent.getIntExtra("medicine_id", -1)
        val scheduledTime = intent.getLongExtra("scheduled_time", 0L)
        
        Log.d("AlarmReceiver", "Received alarm! ID: $alarmId, Med ID: $medicineId")

        if (medicineId == -1 || alarmId == -1) return

        // 1. Fetch medicine details from DB
        val dbHelper = DatabaseHelper(context)
        val details = dbHelper.getMedicineDetails(medicineId) ?: Pair("Medicamento", "Dosis programada")
        val name = details.first
        val dosage = details.second

        dbHelper.markAlarmAsFired(alarmId)

        // Reschedule next occurrence
        val schedule = dbHelper.getMedicineSchedule(medicineId)
        if (schedule != null) {
            val nextTime = calculateNextScheduleTime(scheduledTime, schedule.first, schedule.second)
            if (nextTime != null) {
                val newAlarmId = dbHelper.scheduleNewAlarm(medicineId, nextTime)
                if (newAlarmId != -1L) {
                    AlarmScheduler.scheduleExactAlarm(context, newAlarmId.toInt(), nextTime, medicineId)
                    Log.d("AlarmReceiver", "Automatically rescheduled alarm ID $newAlarmId at $nextTime for medicine $medicineId")
                }
            }
        }

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val useAlarmSound = prefs.getBoolean("flutter.use_alarm_sound", true)

        if (useAlarmSound) {
            // 2. Start Alarm Audio/Vibration Service
            val serviceIntent = Intent(context, AlarmService::class.java).apply {
                putExtra("medicine_name", name)
                putExtra("medicine_dosage", dosage)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }

        // 3. Show high priority / full-screen notification
        showNotification(context, alarmId, medicineId, scheduledTime, name, dosage, useAlarmSound)
    }

    private fun showNotification(
        context: Context,
        alarmId: Int,
        medicineId: Int,
        scheduledTime: Long,
        name: String,
        dosage: String,
        useAlarmSound: Boolean
    ) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val channelId = if (useAlarmSound) "meds_alarm_channel" else "meds_alarm_channel_silent"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelName = if (useAlarmSound) "Recordatorios de Medicamentos" else "Recordatorios Silenciosos"
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = if (useAlarmSound) "Alarmas con sonido continuo" else "Alarmas silenciosas en pantalla completa"
                setBypassDnd(true)
                enableLights(true)
                if (useAlarmSound) {
                    enableVibration(true)
                } else {
                    enableVibration(false)
                    vibrationPattern = longArrayOf(0L)
                    setSound(null, null)
                }
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Action Intents (Snooze & Take directly from notification)
        val takeIntent = Intent(context, AlarmActivity::class.java).apply {
            action = "ACTION_TAKE"
            putExtra("alarm_id", alarmId)
            putExtra("medicine_id", medicineId)
            putExtra("scheduled_time", scheduledTime)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val takePendingIntent = PendingIntent.getActivity(
            context,
            alarmId * 2,
            takeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val snoozeIntent = Intent(context, AlarmActivity::class.java).apply {
            action = "ACTION_SNOOZE"
            putExtra("alarm_id", alarmId)
            putExtra("medicine_id", medicineId)
            putExtra("scheduled_time", scheduledTime)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val snoozePendingIntent = PendingIntent.getActivity(
            context,
            alarmId * 2 + 1,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Full Screen Intent Activity
        val fullScreenIntent = Intent(context, AlarmActivity::class.java).apply {
            putExtra("alarm_id", alarmId)
            putExtra("medicine_id", medicineId)
            putExtra("scheduled_time", scheduledTime)
            putExtra("medicine_name", name)
            putExtra("medicine_dosage", dosage)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            alarmId,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Build premium notification
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("¡Hora de tu medicina!")
            .setContentText("$name - $dosage")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setAutoCancel(false)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_media_play, "TOMAR", takePendingIntent)
            .addAction(android.R.drawable.ic_media_pause, "POSPONER 15 MIN", snoozePendingIntent)

        if (!useAlarmSound) {
            builder.setSound(null)
            builder.setVibrate(longArrayOf(0L))
        }

        notificationManager.notify(alarmId, builder.build())
    }

    private fun calculateNextScheduleTime(currentScheduledTimeMs: Long, scheduleType: String, scheduleValueJson: String): Long? {
        try {
            val calendar = Calendar.getInstance().apply {
                timeInMillis = currentScheduledTimeMs
            }
            
            if (scheduleType == "daily") {
                calendar.add(Calendar.DAY_OF_YEAR, 1)
                return calendar.timeInMillis
            } else if (scheduleType == "days") {
                val json = JSONObject(scheduleValueJson)
                val daysArray = json.optJSONArray("days") ?: return null
                val selectedDays = mutableSetOf<Int>()
                for (i in 0 until daysArray.length()) {
                    selectedDays.add(daysArray.getInt(i))
                }
                if (selectedDays.isEmpty()) return null
                
                // Search day by day starting from tomorrow
                for (offset in 1..7) {
                    calendar.add(Calendar.DAY_OF_YEAR, 1)
                    val androidDayOfWeek = calendar.get(Calendar.DAY_OF_WEEK)
                    val dartDayOfWeek = if (androidDayOfWeek == Calendar.SUNDAY) 7 else androidDayOfWeek - 1
                    
                    if (selectedDays.contains(dartDayOfWeek)) {
                        return calendar.timeInMillis
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("AlarmReceiver", "Error calculating next schedule time: ${e.message}")
        }
        return null
    }
}
