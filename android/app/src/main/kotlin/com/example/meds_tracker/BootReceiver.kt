package com.example.meds_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == "android.intent.action.QUICKBOOT_POWERON" || 
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON") {
            
            Log.d("BootReceiver", "Device booted! Rescheduling alarms...")
            
            val dbHelper = DatabaseHelper(context)
            val pendingAlarms = dbHelper.getPendingFutureAlarms()
            
            for (alarm in pendingAlarms) {
                val alarmId = alarm.first
                val medicineId = alarm.second
                val triggerTimeMs = alarm.third
                
                AlarmScheduler.scheduleExactAlarm(context, alarmId, triggerTimeMs, medicineId)
            }
            Log.d("BootReceiver", "Rescheduled ${pendingAlarms.size} alarms.")
        }
    }
}
