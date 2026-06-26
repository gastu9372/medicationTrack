package com.example.medstracker

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.medstracker/alarms"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId")
                    val triggerTimeMs = call.argument<Long>("triggerTimeMs")
                    val medicineId = call.argument<Int>("medicineId")

                    if (alarmId != null && triggerTimeMs != null && medicineId != null) {
                        AlarmScheduler.scheduleExactAlarm(this, alarmId, triggerTimeMs, medicineId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Arguments alarmId, triggerTimeMs, or medicineId were null", null)
                    }
                }
                "cancelAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId")
                    if (alarmId != null) {
                        AlarmScheduler.cancelAlarm(this, alarmId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Argument alarmId was null", null)
                    }
                }
                "checkOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                "checkExactAlarmPermission" -> {
                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        result.success(alarmManager.canScheduleExactAlarms())
                    } else {
                        result.success(true)
                    }
                }
                "requestExactAlarmPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
