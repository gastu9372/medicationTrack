package com.example.medstracker

import android.app.Activity
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import android.util.Log

class AlarmActivity : Activity() {

    private var alarmId: Int = -1
    private var medicineId: Int = -1
    private var scheduledTime: Long = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 1. Configure lock screen flags
        turnScreenOnAndShowOnLockScreen()

        // 2. Retrieve intent data
        alarmId = intent.getIntExtra("alarm_id", -1)
        medicineId = intent.getIntExtra("medicine_id", -1)
        scheduledTime = intent.getLongExtra("scheduled_time", 0L)
        val medicineName = intent.getStringExtra("medicine_name") ?: "Medicamento"
        val medicineDosage = intent.getStringExtra("medicine_dosage") ?: "Dosis programada"

        Log.d("AlarmActivity", "AlarmActivity started. AlarmId: $alarmId, MedId: $medicineId, Action: ${intent.action}")

        // 3. Handle immediate notification actions
        when (intent.action) {
            "ACTION_TAKE" -> {
                handleTakeAction()
                return
            }
            "ACTION_SNOOZE" -> {
                handleSnoozeAction()
                return
            }
        }

        // 4. Set UI Content
        setContentView(R.layout.activity_alarm)

        val tvName = findViewById<TextView>(R.id.tv_medicine_name)
        val tvDosage = findViewById<TextView>(R.id.tv_medicine_dosage)
        val btnTake = findViewById<Button>(R.id.btn_take)
        val btnSnooze = findViewById<Button>(R.id.btn_snooze)

        // Query database if values are generic
        if (medicineName == "Medicamento" && medicineId != -1) {
            val dbHelper = DatabaseHelper(this)
            val details = dbHelper.getMedicineDetails(medicineId)
            if (details != null) {
                tvName.text = details.first
                tvDosage.text = details.second
            }
        } else {
            tvName.text = medicineName
            tvDosage.text = medicineDosage
        }

        btnTake.setOnClickListener {
            handleTakeAction()
        }

        btnSnooze.setOnClickListener {
            handleSnoozeAction()
        }
    }

    private fun turnScreenOnAndShowOnLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    private fun stopAlarmServiceAndNotification() {
        // Stop the foreground music & vibration service
        stopService(Intent(this, AlarmService::class.java))

        // Dismiss the status bar notification
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(alarmId)
    }

    private fun handleTakeAction() {
        if (medicineId != -1 && alarmId != -1) {
            val dbHelper = DatabaseHelper(this)
            
            // Mark current alarm as taken in database
            dbHelper.updateAlarmStatus(alarmId, "taken")
            
            // Add compliance log
            dbHelper.insertComplianceLog(
                medicineId = medicineId,
                scheduledTime = scheduledTime,
                status = "taken",
                actionTime = System.currentTimeMillis()
            )
        }
        stopAlarmServiceAndNotification()
        finish()
    }

    private fun handleSnoozeAction() {
        if (medicineId != -1 && alarmId != -1) {
            val dbHelper = DatabaseHelper(this)
            
            // Mark current alarm as snoozed
            dbHelper.updateAlarmStatus(alarmId, "snoozed")
            
            // Add compliance log
            dbHelper.insertComplianceLog(
                medicineId = medicineId,
                scheduledTime = scheduledTime,
                status = "snoozed",
                actionTime = System.currentTimeMillis()
            )

            // Calculate and schedule new alarm in 15 minutes
            val snoozeIntervalMs = 15 * 60 * 1000 // 15 mins
            val triggerTimeMs = System.currentTimeMillis() + snoozeIntervalMs
            
            val newAlarmId = dbHelper.scheduleNewAlarm(medicineId, triggerTimeMs)
            if (newAlarmId != -1L) {
                AlarmScheduler.scheduleExactAlarm(this, newAlarmId.toInt(), triggerTimeMs, medicineId)
            }
        }
        stopAlarmServiceAndNotification()
        finish()
    }
}
