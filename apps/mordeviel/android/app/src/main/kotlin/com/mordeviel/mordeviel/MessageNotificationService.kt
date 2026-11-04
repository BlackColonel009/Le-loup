package com.mordeviel.mordeviel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Collections
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Opt-in message reception while the application is minimized, without Firebase.
 * Credentials stay in memory; WorkManager remains the recovery mechanism.
 */
class MessageNotificationService : Service() {
    private val executor = Executors.newSingleThreadScheduledExecutor()
    @Volatile private var base = ""
    @Volatile private var token = ""
    @Volatile private var phoneSound = false
    private val shown = Collections.synchronizedSet(mutableSetOf<Int>())
    private var scheduled = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val nextBase = intent?.getStringExtra("base") ?: ""
        val parsed = Uri.parse(nextBase)
        val nextToken = intent?.getStringExtra("token") ?: ""
        if (parsed.scheme !in listOf("https", "http") || parsed.host.isNullOrBlank() ||
            !parsed.userInfo.isNullOrEmpty() || nextToken.isBlank()) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (token != nextToken) shown.clear()
        base = nextBase.trimEnd('/')
        token = nextToken
        phoneSound = intent?.getBooleanExtra("phoneSound", false) == true
        val manager = getSystemService(NotificationManager::class.java)
        channels(manager)
        val open = PendingIntent.getActivity(this, ID, Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CONNECTION) else Notification.Builder(this)
        val notice = builder.setSmallIcon(R.drawable.ic_social_wolf)
            .setContentTitle("Mordeviel · Messages actifs")
            .setContentText("Réception des messages de tes amis en arrière-plan.")
            .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE).build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(ID, notice, ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING)
        } else startForeground(ID, notice)
        running = true
        if (!scheduled) {
            scheduled = true
            executor.scheduleWithFixedDelay({ poll() }, 1, 6, TimeUnit.SECONDS)
        }
        return START_NOT_STICKY
    }

    private fun channels(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < 26) return
        manager.createNotificationChannel(NotificationChannel(CONNECTION, "Réception des messages", NotificationManager.IMPORTANCE_LOW))
        val audio = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
        for ((id, name, sound) in listOf(
            Triple(CAVE, "Messages · Goutte Mordeviel", Uri.parse("android.resource://$packageName/raw/mordeviel_message_drop")),
            Triple(PHONE, "Messages · Son du téléphone", RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)))) {
            manager.createNotificationChannel(NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Nouveaux messages privés des amis"
                setSound(sound, audio)
                enableVibration(true)
            })
        }
    }

    private fun request(path: String, method: String = "GET", credential: String): JSONObject {
        val connection = URL(base + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = 8000
            connection.readTimeout = 10000
            connection.instanceFollowRedirects = false
            connection.setRequestProperty("Authorization", "Bearer $credential")
            if (connection.responseCode == 401 || connection.responseCode == 403) {
                stopSelf()
                return JSONObject()
            }
            if (connection.responseCode !in 200..299) return JSONObject()
            val text = connection.inputStream.bufferedReader().use { it.readText().take(1048576) }
            return JSONObject(text)
        } finally { connection.disconnect() }
    }

    private fun poll() {
        if (foreground || token.isBlank()) return
        val credential = token
        try {
            val data = request("/social/device/notifications", credential = credential)
            if (credential != token || foreground) return
            if (data.has("enabled") && !data.optBoolean("enabled")) {
                stopSelf()
                return
            }
            if (!data.optBoolean("enabled")) return
            val manager = getSystemService(NotificationManager::class.java)
            val cancelled = data.optJSONArray("cancelled_ids")
            if (cancelled != null) for (i in 0 until cancelled.length()) {
                manager.cancel(cancelled.getInt(i))
                shown.remove(cancelled.getInt(i))
            }
            val messages = data.optJSONArray("notifications") ?: return
            for (i in 0 until messages.length()) {
                if (foreground || credential != token) return
                val message = messages.getJSONObject(i)
                if (message.optString("kind") != "message") continue
                val id = message.getInt("id")
                if (!shown.contains(id)) {
                    val click = Intent(this, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        .putExtra("social_payload", message.optString("payload"))
                    val pending = PendingIntent.getActivity(this, id, click,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, if (phoneSound) PHONE else CAVE) else Notification.Builder(this)
                    val notice = builder.setSmallIcon(R.drawable.ic_social_wolf)
                        .setContentTitle(message.optString("title"))
                        .setContentText(message.optString("body"))
                        .setStyle(Notification.BigTextStyle().bigText(message.optString("body")))
                        .setContentIntent(pending).setAutoCancel(true).setOnlyAlertOnce(true)
                        .setCategory(Notification.CATEGORY_MESSAGE)
                        .setVisibility(Notification.VISIBILITY_PRIVATE)
                    if (Build.VERSION.SDK_INT < 26) notice.setSound(if (phoneSound)
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        else Uri.parse("android.resource://$packageName/raw/mordeviel_message_drop"))
                    manager.notify(id, notice.build())
                    shown.add(id)
                    synchronized(shown) {
                        if (shown.size > 1000) shown.remove(shown.first())
                    }
                }
                request("/social/device/notifications/$id/delivered", "POST", credential)
            }
        } catch (_: Exception) {
            // Connectivity will be retried without disturbing the game or microphone.
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
    override fun onDestroy() {
        token = ""
        running = false
        executor.shutdownNow()
        val manager = getSystemService(NotificationManager::class.java)
        synchronized(shown) { for (id in shown) manager.cancel(id) }
        super.onDestroy()
    }
    companion object {
        @Volatile var foreground = true
        @Volatile var running = false
        const val ID = 940003
        const val CONNECTION = "mordeviel_message_connection_v1"
        const val CAVE = "mordeviel_messages_cave_v1"
        const val PHONE = "mordeviel_messages_phone_v1"
    }
}
