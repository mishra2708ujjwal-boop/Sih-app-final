package com.example.sih_test_app_new

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Native bridge for PRANA's fully-automatic fall dispatch.
 *
 * SMS, phone call and GPS are implemented here with plain Android SDK APIs
 * rather than third-party Flutter plugins on purpose: this module compiles at a
 * consistent JVM 17 in our own :app project, so it sidesteps the AGP-9 plugin
 * JVM-target build failures that have already bitten this repo. The Dart side
 * talks to it over the [CHANNEL] MethodChannel (see emergency_dispatcher.dart).
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "prana/emergency"
        private const val FILES_CHANNEL = "prana/files"
        private const val REQ_CODE = 9001
        // A last-known fix newer than this is good enough to skip a live update.
        private const val FRESH_ENOUGH_MS = 120_000L
        // How long to wait for a fresh fix before falling back to last-known.
        private const val LOCATION_TIMEOUT_MS = 8_000L
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermissions" -> {
                        requestEmergencyPermissions()
                        result.success(true)
                    }
                    "permissions" -> result.success(permissionMap())
                    "getLocation" -> getLocation(result)
                    "sendSms" -> {
                        val phone = call.argument<String>("phone")
                        val message = call.argument<String>("message")
                        if (phone.isNullOrBlank() || message == null) {
                            result.success(false)
                        } else {
                            result.success(sendSms(phone, message))
                        }
                    }
                    "placeCall" -> {
                        val phone = call.argument<String>("phone")
                        if (phone.isNullOrBlank()) result.success("failed")
                        else result.success(placeCall(phone))
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareFile" -> {
                        val path = call.argument<String>("path")
                        val mime = call.argument<String>("mime") ?: "application/pdf"
                        val subject = call.argument<String>("subject")
                        result.success(shareFile(path, mime, subject))
                    }
                    "openFile" -> {
                        val path = call.argument<String>("path")
                        val mime = call.argument<String>("mime") ?: "application/pdf"
                        result.success(openFile(path, mime))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── File share / open (FileProvider, no plugin) ───────────────────────────

    private fun fileUri(path: String): Uri =
        FileProvider.getUriForFile(this, "$packageName.fileprovider", File(path))

    private fun shareFile(path: String?, mime: String, subject: String?): Boolean {
        if (path.isNullOrBlank() || !File(path).exists()) return false
        return try {
            val uri = fileUri(path)
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                if (!subject.isNullOrBlank()) putExtra(Intent.EXTRA_SUBJECT, subject)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(send, subject ?: "Share report")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(chooser)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openFile(path: String?, mime: String): Boolean {
        if (path.isNullOrBlank() || !File(path).exists()) return false
        return try {
            val uri = fileUri(path)
            val view = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(view)
            true
        } catch (e: Exception) {
            false
        }
    }

    // ── Permissions ─────────────────────────────────────────────────────────

    private fun granted(permission: String): Boolean =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    private fun permissionMap(): Map<String, Boolean> = mapOf(
        "sms" to granted(Manifest.permission.SEND_SMS),
        "call" to granted(Manifest.permission.CALL_PHONE),
        "location" to (granted(Manifest.permission.ACCESS_FINE_LOCATION) ||
            granted(Manifest.permission.ACCESS_COARSE_LOCATION)),
    )

    /** Fire-and-forget: pops the OS dialogs; Dart re-checks grants at dispatch. */
    private fun requestEmergencyPermissions() {
        val wanted = arrayOf(
            Manifest.permission.SEND_SMS,
            Manifest.permission.CALL_PHONE,
            Manifest.permission.ACCESS_FINE_LOCATION,
        )
        val missing = wanted.filter { !granted(it) }
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), REQ_CODE)
        }
    }

    // ── SMS ─────────────────────────────────────────────────────────────────

    private fun sendSms(phone: String, message: String): Boolean {
        if (!granted(Manifest.permission.SEND_SMS)) return false
        return try {
            val manager = smsManager() ?: return false
            val parts = manager.divideMessage(message)
            if (parts.size > 1) {
                manager.sendMultipartTextMessage(phone, null, parts, null, null)
            } else {
                manager.sendTextMessage(phone, null, message, null, null)
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun smsManager(): SmsManager? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
    } catch (e: Exception) {
        null
    }

    // ── Call ──────────────────────────────────────────────────────────────────

    /** "called" (auto-placed), "dialer" (opened prefilled), or "failed". */
    private fun placeCall(phone: String): String = try {
        val uri = Uri.parse("tel:$phone")
        if (granted(Manifest.permission.CALL_PHONE)) {
            startActivity(
                Intent(Intent.ACTION_CALL, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            "called"
        } else {
            startActivity(
                Intent(Intent.ACTION_DIAL, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            "dialer"
        }
    } catch (e: Exception) {
        "failed"
    }

    // ── Location ────────────────────────────────────────────────────────────

    private fun locationToMap(loc: Location): Map<String, Any> = mapOf(
        "lat" to loc.latitude,
        "lng" to loc.longitude,
        "accuracy" to if (loc.hasAccuracy()) loc.accuracy.toDouble() else -1.0,
    )

    private fun getLocation(result: MethodChannel.Result) {
        val hasLocationPerm = granted(Manifest.permission.ACCESS_FINE_LOCATION) ||
            granted(Manifest.permission.ACCESS_COARSE_LOCATION)
        if (!hasLocationPerm) {
            result.success(null)
            return
        }
        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (lm == null) {
            result.success(null)
            return
        }

        // Best cached fix across providers.
        var best: Location? = null
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER,
        )
        for (p in providers) {
            try {
                val loc = lm.getLastKnownLocation(p) ?: continue
                if (best == null || loc.time > best!!.time) best = loc
            } catch (e: SecurityException) {
                // provider not permitted — skip
            } catch (e: IllegalArgumentException) {
                // provider not present on this device — skip
            }
        }

        val now = System.currentTimeMillis()
        if (best != null && now - best!!.time < FRESH_ENOUGH_MS) {
            result.success(locationToMap(best!!))
            return
        }

        // Otherwise request a single fresh fix, falling back to `best` on timeout.
        val delivered = AtomicBoolean(false)
        var listener: LocationListener? = null

        fun finish(loc: Location?) {
            if (delivered.compareAndSet(false, true)) {
                listener?.let { l -> try { lm.removeUpdates(l) } catch (_: Exception) {} }
                result.success(if (loc != null) locationToMap(loc) else null)
            }
        }

        listener = object : LocationListener {
            override fun onLocationChanged(location: Location) = finish(location)
        }

        var requested = false
        try {
            if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                lm.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER, 0L, 0f, listener!!, Looper.getMainLooper(),
                )
                requested = true
            }
            if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                lm.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER, 0L, 0f, listener!!, Looper.getMainLooper(),
                )
                requested = true
            }
        } catch (e: SecurityException) {
            // fall through to timeout/last-known
        }

        if (!requested) {
            finish(best)
            return
        }
        Handler(Looper.getMainLooper()).postDelayed({ finish(best) }, LOCATION_TIMEOUT_MS)
    }
}
