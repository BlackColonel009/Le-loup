package com.mordeviel.mordeviel

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Build
import android.app.Notification
import android.app.NotificationManager

class MainActivity : FlutterActivity() {
    private var messageChannel: MethodChannel? = null
    override fun onResume() {
        super.onResume()
        MessageNotificationService.foreground = true
    }
    override fun onPause() {
        MessageNotificationService.foreground = false
        super.onPause()
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra("social_payload")?.let { payload ->
            messageChannel?.invokeMethod("notification", payload)
            intent.removeExtra("social_payload")
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        messageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mordeviel/private_messages")
        messageChannel?.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        val intent = Intent(this, MessageNotificationService::class.java)
                            .putExtra("base", call.argument<String>("base"))
                            .putExtra("token", call.argument<String>("token"))
                            .putExtra("phoneSound", call.argument<Boolean>("phoneSound") ?: false)
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                        result.success(true)
                    }
                    "stop" -> {
                        stopService(Intent(this, MessageNotificationService::class.java))
                        if (Build.VERSION.SDK_INT >= 23) {
                            val manager = getSystemService(NotificationManager::class.java)
                            for (notice in manager.activeNotifications) {
                                val message = if (Build.VERSION.SDK_INT >= 26)
                                    notice.notification.channelId in listOf(MessageNotificationService.CAVE, MessageNotificationService.PHONE)
                                    else notice.notification.category == Notification.CATEGORY_MESSAGE
                                if (message) manager.cancel(notice.id)
                            }
                        }
                        result.success(true)
                    }
                    "running" -> result.success(MessageNotificationService.running)
                    "takePayload" -> {
                        result.success(intent.getStringExtra("social_payload"))
                        intent.removeExtra("social_payload")
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("messages_unavailable", "Réception des messages indisponible.", null) }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mordeviel/game_session")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "start" -> {
                            val intent = Intent(this, GameSessionService::class.java)
                                .putExtra("code", call.argument<String>("code") ?: "")
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                            result.success(true)
                        }
                        "stop" -> {
                            stopService(Intent(this, GameSessionService::class.java))
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("game_session_unavailable", "Connexion en arrière-plan indisponible.", null)
                }
            }
    }
}
