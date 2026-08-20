package com.duxweb.codux

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val connectionKeeperChannel = "com.duxweb.codux/connection_keeper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, connectionKeeperChannel)
            .setMethodCallHandler { call, result ->
                val intent = Intent(this, ConnectionKeeperService::class.java)
                when (call.method) {
                    "prepareNotifications" -> {
                        createInterventionChannel()
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                                PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                notificationPermissionRequest,
                            )
                        }
                        result.success(null)
                    }
                    "notifyIntervention" -> {
                        val id = call.argument<Int>("id") ?: interventionNotificationBase
                        val title = call.argument<String>("title") ?: "Codux needs your input"
                        val body = call.argument<String>("body") ?: "Tap to return to the terminal"
                        showInterventionNotification(id, title, body)
                        result.success(null)
                    }
                    "cancelIntervention" -> {
                        val id = call.argument<Int>("id") ?: interventionNotificationBase
                        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancel(id)
                        result.success(null)
                    }
                    "start" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun createInterventionChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(
                interventionChannel,
                "AI needs attention",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Alerts when Codex or Claude is waiting for your input"
                enableVibration(true)
            },
        )
    }

    private fun showInterventionNotification(id: Int, title: String, body: String) {
        createInterventionChannel()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            id,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, interventionChannel)
        } else {
            Notification.Builder(this)
                .setPriority(Notification.PRIORITY_HIGH)
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_codux)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .build()
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).notify(id, notification)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        disableDefaultFocusHighlight(window.decorView)
    }

    private fun disableDefaultFocusHighlight(view: android.view.View) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            view.defaultFocusHighlightEnabled = false
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                disableDefaultFocusHighlight(view.getChildAt(index))
            }
        }
    }

    companion object {
        private const val interventionChannel = "codux_ai_attention"
        private const val interventionNotificationBase = 3000
        private const val notificationPermissionRequest = 2028
    }
}
