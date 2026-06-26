package com.example.medstracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

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

        // 3. Show high priority / full-screen notification
        showNotification(context, alarmId, medicineId, scheduledTime, name, dosage)
    }

    private fun showNotification(
        context: Context,
        alarmId: Int,
        medicineId: Int,
        scheduledTime: Long,
        name: String,
        dosage: String
    ) {
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val channelId = "meds_alarm_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Recordatorios de Medicamentos",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alarmas de alta prioridad para medicamentos"
                setBypassDnd(true)
                enableLights(true)
                enableVibration(true)
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

        notificationManager.notify(alarmId, builder.build())
    }
}
