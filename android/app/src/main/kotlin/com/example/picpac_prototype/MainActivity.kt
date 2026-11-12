package com.example.picpac_prototype

import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.Segmentation
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.AtomicFile
import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.Locale
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val channelName = "by.picpac.demo/storage"
    private val pickRequest = 7401
    private val maxBytes = 20L * 1024 * 1024
    private var pendingPick: MethodChannel.Result? = null
    private val ownerRequest = 7402
    private data class OwnerRequest(val operation: String, val role: String?, val password: String?, val reply: MethodChannel.Result)
    private var pendingOwner: OwnerRequest? = null
    private val photoDir: File get() = File(filesDir, "photos").apply { mkdirs() }
    // Device-only educational store, not a secure multi-device backend.
    private val dbHelper by lazy { object : SQLiteOpenHelper(this, "picpac.db", null, 2) {
        private fun createUsers(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE IF NOT EXISTS app_users (email TEXT NOT NULL, role TEXT NOT NULL, salt TEXT NOT NULL, hash TEXT NOT NULL, disabled INTEGER NOT NULL DEFAULT 0, created INTEGER NOT NULL, PRIMARY KEY(email, role))")
        }
        override fun onCreate(db: SQLiteDatabase) {
            db.execSQL("CREATE TABLE app_state (id INTEGER PRIMARY KEY CHECK (id = 1), json TEXT NOT NULL)")
            createUsers(db)
        }
        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) { if (oldVersion < 2) createUsers(db) }
    } }
    private val session get() = getSharedPreferences("local_session", MODE_PRIVATE)
    private fun migrateLegacy() {
        if (session.getBoolean("legacy_migrated", false)) return
        val old = getSharedPreferences("local_auth", MODE_PRIVATE)
        val email = old.getString("email", null)
        val salt = old.getString("salt", null)
        val hash = old.getString("hash", null)
        if (email != null && salt != null && hash != null) {
            val values = ContentValues().apply {
                put("email", email); put("role", "customer"); put("salt", salt); put("hash", hash)
                put("disabled", 0); put("created", System.currentTimeMillis())
            }
            dbHelper.writableDatabase.insertWithOnConflict("app_users", null, values, SQLiteDatabase.CONFLICT_IGNORE)
        }
        val edit = session.edit().putBoolean("legacy_migrated", true)
        if (email != null) edit.putString("legacy_owner", email)
        if (email != null && old.getBoolean("signed_in", false)) edit.putString("email", email).putString("role", "customer")
        if (!edit.commit()) throw Exception("Migration failed")
        old.edit().clear().commit()
    }
    private fun active(role: String): String? {
        if (session.getString("role", null) != role) return null
        val email = session.getString("email", null) ?: return null
        val valid = dbHelper.readableDatabase.rawQuery("SELECT disabled FROM app_users WHERE email=? AND role=?", arrayOf(email, role)).use { it.moveToFirst() && it.getInt(0) == 0 }
        return if (valid) email else null
    }
    private fun derive(password: String, salt: ByteArray): ByteArray {
        val chars = password.toCharArray()
        val spec = PBEKeySpec(chars, salt, 150000, 256)
        return try { SecretKeyFactory.getInstance("PBKDF2WithHmacSHA1").generateSecret(spec).encoded }
        finally { spec.clearPassword(); chars.fill('\u0000') }
    }
    private fun retirePublicDemoCredentials() {
        if (session.getBoolean("retired_public_staff_v1", false)) return
        val db = dbHelper.writableDatabase
        val accounts = listOf(Triple("admin@picpac.local", "admin", "PicPacAdmin2026!"), Triple("support@picpac.local", "support", "PicPacSupport2026!"))
        db.beginTransaction()
        try {
            for ((email, role, password) in accounts) {
                val record = db.rawQuery("SELECT salt,hash FROM app_users WHERE email=? AND role=?", arrayOf(email, role)).use { c -> if (c.moveToFirst()) Pair(c.getString(0), c.getString(1)) else null }
                if (record != null && MessageDigest.isEqual(derive(password, Base64.decode(record.first, Base64.NO_WRAP)), Base64.decode(record.second, Base64.NO_WRAP))) {
                    db.update("app_users", ContentValues().apply { put("disabled", 1) }, "email=? AND role=?", arrayOf(email, role))
                }
            }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
        if (!session.edit().putBoolean("retired_public_staff_v1", true).commit()) throw Exception("Migration failed")
    }
    private fun hasAdmin(): Boolean = dbHelper.readableDatabase.rawQuery("SELECT 1 FROM app_users WHERE role='admin' LIMIT 1", null).use { it.moveToFirst() }
    private val dbExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()

    // ---- Встряхивание телефона (акселерометр) для «Встряхни для коллажа» ----
    private val shakeChannelName = "by.picpac.demo/shake"
    private var shakeChannel: MethodChannel? = null
    private var shakeListener: android.hardware.SensorEventListener? = null
    private var shakeWanted = false
    private var lastShakeAt = 0L
    private fun startShake() {
        if (shakeListener != null) return
        val manager = getSystemService(android.content.Context.SENSOR_SERVICE) as? android.hardware.SensorManager ?: return
        val sensor = manager.getDefaultSensor(android.hardware.Sensor.TYPE_ACCELEROMETER) ?: return
        val listener = object : android.hardware.SensorEventListener {
            override fun onSensorChanged(event: android.hardware.SensorEvent) {
                val g = android.hardware.SensorManager.GRAVITY_EARTH
                val x = event.values[0] / g
                val y = event.values[1] / g
                val z = event.values[2] / g
                val force = Math.sqrt((x * x + y * y + z * z).toDouble())
                if (force > 2.4) {
                    val now = System.currentTimeMillis()
                    if (now - lastShakeAt > 900) {
                        lastShakeAt = now
                        shakeChannel?.invokeMethod("shake", null)
                    }
                }
            }
            override fun onAccuracyChanged(sensor: android.hardware.Sensor?, accuracy: Int) {}
        }
        shakeListener = listener
        manager.registerListener(listener, sensor, android.hardware.SensorManager.SENSOR_DELAY_GAME)
    }
    private fun stopShake() {
        val listener = shakeListener ?: return
        (getSystemService(android.content.Context.SENSOR_SERVICE) as? android.hardware.SensorManager)?.unregisterListener(listener)
        shakeListener = null
    }
    override fun onPause() { stopShake(); super.onPause() }
    override fun onResume() { super.onResume(); if (shakeWanted) startShake() }
    override fun onDestroy() { stopShake(); dbExecutor.shutdown(); super.onDestroy() }
    private fun writeState(value: String) {
        val values = ContentValues().apply { put("id", 1); put("json", value) }
        if (dbHelper.writableDatabase.insertWithOnConflict("app_state", null, values, SQLiteDatabase.CONFLICT_REPLACE) < 0)
            throw Exception("Cannot save state")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val shake = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shakeChannelName)
        shakeChannel = shake
        shake.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> { shakeWanted = true; startShake(); result.success(null) }
                "stop" -> { shakeWanted = false; stopShake(); result.success(null) }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            try { migrateLegacy(); retirePublicDemoCredentials() } catch (e: Exception) { result.error("STORAGE", "Не удалось открыть базу", null); return@setMethodCallHandler }
            when (call.method) {
                "loadState" -> try {
                    val value = dbHelper.readableDatabase.rawQuery("SELECT json FROM app_state WHERE id = 1", null).use { c ->
                        if (c.moveToFirst()) c.getString(0) else null
                    }
                    if (value != null) result.success(value) else {
                        val old = AtomicFile(File(filesDir, "state.json"))
                        val previous = if (old.baseFile.exists()) old.readFully().toString(Charsets.UTF_8) else null
                        if (previous != null) { writeState(previous); old.delete() }
                        result.success(previous)
                    }
                } catch (e: Exception) { result.error("STORAGE", e.message, null) }
                "saveState" -> {
                    val text = call.argument<String>("data")
                    if (text == null) { result.error("ARG", "Missing state", null); return@setMethodCallHandler }
                    // Запись в SQLite (с fsync) не должна блокировать UI-поток.
                    // Один поток сохраняет порядок записей.
                    dbExecutor.execute {
                        try { writeState(text); runOnUiThread { result.success(null) } }
                        catch (e: Exception) { runOnUiThread { result.error("STORAGE", e.message, null) } }
                    }
                }
                "legacyOwner" -> result.success(session.getString("legacy_owner", null))
                "authState" -> result.success(active("customer"))
                "adminState" -> result.success(active("admin"))
                "supportState" -> result.success(active("support"))
                "adminExists" -> result.success(hasAdmin())
                "staffAccessState" -> {
                    val role = call.argument<String>("role")
                    if (role !in setOf("admin", "support")) result.error("INVALID", "Неизвестная роль", null)
                    else try {
                        val email = if (role == "admin") "admin@picpac.local" else "support@picpac.local"
                        val state = dbHelper.readableDatabase.rawQuery("SELECT disabled FROM app_users WHERE email=? AND role=?", arrayOf(email, role)).use { c ->
                            if (!c.moveToFirst()) "missing" else if (c.getInt(0) != 0) "disabled" else "ready"
                        }
                        result.success(state)
                    } catch (e: Exception) { result.error("STORAGE", "Не удалось проверить доступ", null) }
                }
                "setupStaff", "verifyDeviceOwner" -> {
                    val setup = call.method == "setupStaff"
                    val role = call.argument<String>("role")
                    val password = call.argument<String>("password")
                    val manager = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
                    if (setup && (role !in setOf("admin", "support") || password == null || password.length !in 12..128 || password == "PicPacAdmin2026!" || password == "PicPacSupport2026!")) {
                        result.error("INVALID", "Выберите новый пароль от 12 до 128 символов", null)
                    } else if (pendingOwner != null) result.error("BUSY", "Подтверждение уже выполняется", null)
                    else if (!manager.isDeviceSecure) result.error("NO_DEVICE_LOCK", "Сначала настройте блокировку экрана телефона", null)
                    else {
                        @Suppress("DEPRECATION")
                        val intent = manager.createConfirmDeviceCredentialIntent("Подтверждение владельца", "Подтвердите блокировку экрана")
                        if (intent == null) result.error("NO_DEVICE_LOCK", "Не удалось открыть подтверждение устройства", null)
                        else try {
                            pendingOwner = OwnerRequest(call.method, role, password, result)
                            startActivityForResult(intent, ownerRequest)
                        } catch (e: Exception) { pendingOwner = null; result.error("DEVICE_LOCK", "Не удалось открыть подтверждение устройства", null) }
                    }
                }
                "authRegister", "authLogin", "adminLogin", "supportLogin" -> {
                    val email = call.argument<String>("email")?.trim()?.lowercase(Locale.ROOT) ?: ""
                    val password = call.argument<String>("password") ?: ""
                    val admin = call.method.startsWith("admin")
                    val role = if (admin) "admin" else if (call.method == "supportLogin") "support" else "customer"
                    val register = call.method == "authRegister"
                    if (email.isEmpty() || email.length > 254 || password.length < 8 || password.length > 128) {
                        result.error("INVALID", "Проверьте логин и пароль", null)
                    } else thread {
                        try {
                            val db = dbHelper.writableDatabase
                            if (register) {
                                val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
                                val hash = derive(password, salt)
                                val values = ContentValues().apply {
                                    put("email", email); put("role", role)
                                    put("salt", Base64.encodeToString(salt, Base64.NO_WRAP))
                                    put("hash", Base64.encodeToString(hash, Base64.NO_WRAP))
                                    put("disabled", 0); put("created", System.currentTimeMillis())
                                }
                                db.beginTransaction()
                                try {
                                    if (db.insertWithOnConflict("app_users", null, values, SQLiteDatabase.CONFLICT_IGNORE) < 0)
                                        throw IllegalStateException("ACCOUNT_EXISTS")
                                    db.setTransactionSuccessful()
                                } finally { db.endTransaction() }
                            } else {
                                val record = db.rawQuery("SELECT salt,hash,disabled FROM app_users WHERE email=? AND role=?", arrayOf(email, role)).use { cursor ->
                                    if (!cursor.moveToFirst()) null else Triple(cursor.getString(0), cursor.getString(1), cursor.getInt(2))
                                } ?: throw IllegalStateException("AUTH_FAILED")
                                if (record.third != 0) throw IllegalStateException("DISABLED")
                                val hash = derive(password, Base64.decode(record.first, Base64.NO_WRAP))
                                if (!MessageDigest.isEqual(hash, Base64.decode(record.second, Base64.NO_WRAP))) throw IllegalStateException("AUTH_FAILED")
                            }
                            if (!session.edit().putString("email", email).putString("role", role).commit()) throw Exception("SAVE_FAILED")
                            runOnUiThread { result.success(email) }
                        } catch (e: Exception) {
                            val code = when (e.message) {
                                "ACCOUNT_EXISTS" -> "ACCOUNT_EXISTS"; "ADMIN_EXISTS" -> "ADMIN_EXISTS";
                                "AUTH_FAILED" -> "AUTH_FAILED"; "DISABLED" -> "DISABLED"; else -> "AUTH_ERROR"
                            }
                            runOnUiThread { result.error(code, "Не удалось выполнить вход", null) }
                        }
                    }
                }
                "authLogout", "adminLogout", "supportLogout" -> {
                    val ok = session.edit().remove("email").remove("role").commit()
                    if (ok) result.success(null) else result.error("AUTH_ERROR", "Не удалось выйти", null)
                }
                "authDelete" -> {
                    val email = active("customer")
                    if (email == null) { result.error("FORBIDDEN", "Войдите в аккаунт", null); return@setMethodCallHandler }
                    try {
                        dbHelper.writableDatabase.delete("app_users", "email=? AND role='customer'", arrayOf(email))
                        if (!session.edit().remove("email").remove("role").commit()) throw Exception("SAVE_FAILED")
                        result.success(null)
                    } catch (e: Exception) { result.error("AUTH_ERROR", "Не удалось удалить аккаунт", null) }
                }
                "adminListUsers" -> {
                    if (active("admin") == null) { result.error("FORBIDDEN", "Нужен вход администратора", null); return@setMethodCallHandler }
                    try {
                        val users = mutableListOf<Map<String, Any>>()
                        dbHelper.readableDatabase.rawQuery("SELECT email,disabled,created FROM app_users WHERE role='customer' ORDER BY created DESC", null).use { c ->
                            while (c.moveToNext()) users.add(mapOf("email" to c.getString(0), "disabled" to (c.getInt(1) != 0), "created" to c.getLong(2)))
                        }
                        result.success(users)
                    } catch (e: Exception) { result.error("STORAGE", "Не удалось загрузить пользователей", null) }
                }
                "adminSetDisabled" -> {
                    if (active("admin") == null) { result.error("FORBIDDEN", "Нужен вход администратора", null); return@setMethodCallHandler }
                    val email = call.argument<String>("email") ?: ""
                    val disabled = call.argument<Boolean>("disabled") ?: false
                    val changed = dbHelper.writableDatabase.update("app_users", ContentValues().apply { put("disabled", if (disabled) 1 else 0) }, "email=? AND role='customer'", arrayOf(email))
                    if (changed == 1) result.success(null) else result.error("NOT_FOUND", "Пользователь не найден", null)
                }
                "segmentPortrait" -> {
                    val id = call.argument<String>("sourceId") ?: ""
                    val bg = call.argument<String>("backgroundId")
                    val color = call.argument<Number>("color")?.toInt()
                    thread {
                        try {
                            val photo = segmentPortrait(id, bg, color)
                            runOnUiThread { result.success(photo) }
                        } catch (e: OutOfMemoryError) {
                            runOnUiThread { result.error("MEMORY", "Недостаточно памяти для обработки фото", null) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("SEGMENTATION", e.message ?: "Не удалось обработать фото", null) }
                        }
                    }
                }
                "photoDirectory" -> result.success(photoDir.absolutePath)
                "pickPhotos" -> {
                    if (pendingPick != null) { result.error("BUSY", "Выбор уже открыт", null); return@setMethodCallHandler }
                    // Android 13+: system Photo Picker; older Android: installed gallery.
                    val primary = if (Build.VERSION.SDK_INT >= 33) {
                        Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                            type = "image/*"
                            putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, minOf(100, MediaStore.getPickImagesMaxLimit()))
                        }
                    } else {
                        Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI).apply {
                            type = "image/*"
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                        }
                    }
                    try {
                        pendingPick = result
                        try { startActivityForResult(primary, pickRequest) }
                        catch (_: Exception) {
                            // Some older devices have no gallery handler.
                            val fallback = Intent(Intent.ACTION_GET_CONTENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "image/*"
                                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                            }
                            startActivityForResult(fallback, pickRequest)
                        }
                    } catch (e: Exception) { pendingPick = null; result.error("PICKER", "Не удалось открыть галерею", null) }
                }
                "deletePhoto" -> {
                    val id = call.argument<String>("id") ?: ""
                    // Only delete generated UUID filenames inside the application's private directory.
                    if (id.matches(Regex("[a-f0-9-]{36}\\.(jpg|png|webp|bmp)"))) File(photoDir, id).delete()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Android, retained for FlutterActivity compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == ownerRequest) {
            val pending = pendingOwner ?: return
            pendingOwner = null
            if (resultCode != Activity.RESULT_OK) { pending.reply.error("CANCELLED", "Подтверждение отменено", null); return }
            if (pending.operation == "verifyDeviceOwner") { pending.reply.success(true); return }
            thread {
                try {
                    val role = pending.role!!
                    val email = if (role == "admin") "admin@picpac.local" else "support@picpac.local"
                    val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
                    val values = ContentValues().apply {
                        put("salt", Base64.encodeToString(salt, Base64.NO_WRAP)); put("hash", Base64.encodeToString(derive(pending.password!!, salt), Base64.NO_WRAP)); put("disabled", 0)
                    }
                    val db = dbHelper.writableDatabase
                    db.beginTransaction()
                    try {
                        if (db.update("app_users", values, "email=? AND role=?", arrayOf(email, role)) == 0) {
                            values.put("email", email); values.put("role", role); values.put("created", System.currentTimeMillis()); db.insertOrThrow("app_users", null, values)
                        }
                        db.setTransactionSuccessful()
                    } finally { db.endTransaction() }
                    if (session.getString("email", null) == email && session.getString("role", null) == role) {
                        if (!session.edit().remove("email").remove("role").commit()) throw Exception("Cannot end previous session")
                    }
                    runOnUiThread { pending.reply.success(email) }
                } catch (e: Exception) { runOnUiThread { pending.reply.error("STORAGE", "Не удалось сохранить настройки", null) } }
            }
            return
        }
        if (requestCode != pickRequest) return
        val reply = pendingPick ?: return
        pendingPick = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            reply.success(mapOf("photos" to emptyList<Map<String, Any>>(), "errors" to emptyList<String>()))
            return
        }
        val uris = mutableListOf<Uri>()
        data.clipData?.let { clip -> for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri) }
            ?: data.data?.let { uris.add(it) }
        thread {
            val photos = mutableListOf<Map<String, Any>>()
            val errors = mutableListOf<String>()
            for (uri in uris.take(100)) {
                try { photos.add(importPhoto(uri)) }
                catch (e: Exception) { errors.add(e.message ?: "Не удалось добавить файл") }
            }
            if (uris.size > 100) errors.add("За один раз можно выбрать не более 100 файлов")
            runOnUiThread { reply.success(mapOf("photos" to photos, "errors" to errors)) }
        }
    }

    // Returns a bounded, EXIF-oriented bitmap; never decodes a full 80 MP source.
    private fun decodeForAi(file: File): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw Exception("Файл фотографии повреждён или недоступен")
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 1600) sample *= 2
        val input = BitmapFactory.decodeFile(file.absolutePath, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: throw Exception("Не удалось открыть фото")
        val orientation = try { ExifInterface(file.absolutePath).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL) } catch (_: Exception) { ExifInterface.ORIENTATION_NORMAL }
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.postScale(-1f, 1f); matrix.postRotate(270f) }
            ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.postScale(-1f, 1f); matrix.postRotate(90f) }
        }
        val output = if (!matrix.isIdentity) Bitmap.createBitmap(input, 0, 0, input.width, input.height, matrix, true) else input
        if (output !== input) input.recycle()
        return output
    }

    private fun safePhoto(id: String): File {
        if (!id.matches(Regex("[a-f0-9-]{36}\\.(jpg|png|webp|bmp)"))) throw Exception("Некорректный файл фотографии")
        val file = File(photoDir, id)
        if (!file.isFile) throw Exception("Фотография недоступна")
        return file
    }

    private fun segmentPortrait(id: String, backgroundId: String?, color: Int?): Map<String, Any> {
        val source = decodeForAi(safePhoto(id))
        var output: Bitmap? = null
        var background: Bitmap? = null
        var foreground: Bitmap? = null
        val segmenter = Segmentation.getClient(SelfieSegmenterOptions.Builder()
            .setDetectorMode(SelfieSegmenterOptions.SINGLE_IMAGE_MODE).build())
        try {
            if (source.width < 256 || source.height < 256) throw Exception("Для выделения человека нужна фотография не меньше 256 × 256 пикселей")
            val mask = Tasks.await(segmenter.process(InputImage.fromBitmap(source, 0)))
            if (mask.width != source.width || mask.height != source.height) throw Exception("Не удалось сопоставить маску с фото")
            val w = source.width; val h = source.height
            val pixels = IntArray(w * h)
            source.getPixels(pixels, 0, w, 0, 0, w, h)
            val buffer = mask.buffer
            buffer.rewind()
            var confident = 0
            for (i in pixels.indices) {
                val confidence = buffer.float.coerceIn(0f, 1f)
                if (confidence > 0.7f) confident++
                val originalAlpha = pixels[i] ushr 24
                val alpha = ((confidence - .15f) / .7f).coerceIn(0f, 1f)
                pixels[i] = (pixels[i] and 0x00ffffff) or ((originalAlpha * alpha).toInt() shl 24)
            }
            if (confident < maxOf(20, pixels.size / 2000)) throw Exception("Не удалось уверенно найти человека. Попробуйте портрет покрупнее и с хорошим освещением.")
            foreground = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            foreground.setPixels(pixels, 0, w, 0, 0, w, h)
            output = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(output)
            if (backgroundId != null) {
                background = decodeForAi(safePhoto(backgroundId))
                val scale = maxOf(w.toFloat() / background.width, h.toFloat() / background.height)
                val cropW = w / scale; val cropH = h / scale
                val left = ((background.width - cropW) / 2f).toInt()
                val top = ((background.height - cropH) / 2f).toInt()
                canvas.drawBitmap(background, Rect(left, top, (left + cropW).toInt().coerceAtMost(background.width), (top + cropH).toInt().coerceAtMost(background.height)), Rect(0, 0, w, h), Paint(Paint.FILTER_BITMAP_FLAG))
            } else if (color != null) {
                canvas.drawColor(color or Color.BLACK)
            } else {
                canvas.drawColor(Color.TRANSPARENT)
            }
            canvas.drawBitmap(foreground, 0f, 0f, Paint(Paint.FILTER_BITMAP_FLAG))
            val outId = "${UUID.randomUUID()}.png"
            val temp = File(photoDir, "${UUID.randomUUID()}.tmp")
            val target = File(photoDir, outId)
            try {
                val ok = temp.outputStream().use { output.compress(Bitmap.CompressFormat.PNG, 100, it) }
                if (!ok || !temp.renameTo(target)) throw Exception("Не удалось сохранить результат")
                return mapOf("id" to outId, "name" to "ИИ-версия.png", "width" to w, "height" to h, "size" to target.length())
            } finally { if (temp.exists()) temp.delete() }
        } finally {
            segmenter.close(); source.recycle(); output?.recycle(); background?.recycle(); foreground?.recycle()
        }
    }

    private fun importPhoto(uri: Uri): Map<String, Any> {
        val displayName = try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            } ?: "Фото"
        } catch (_: Exception) { "Фото" }
        val temp = File(photoDir, "${UUID.randomUUID()}.tmp")
        try {
            val input = contentResolver.openInputStream(uri) ?: throw Exception("$displayName: файл недоступен")
            var count = 0L
            input.use { source -> temp.outputStream().use { out ->
                val buffer = ByteArray(8192)
                while (true) {
                    val n = source.read(buffer)
                    if (n < 0) break
                    count += n
                    if (count > maxBytes) throw Exception("$displayName: размер больше 20 МБ")
                    out.write(buffer, 0, n)
                }
            } }
            if (count == 0L) throw Exception("$displayName: файл пустой")
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(temp.absolutePath, bounds)
            val mime = bounds.outMimeType
            val ext = when (mime) {
                "image/jpeg" -> "jpg"
                "image/png" -> "png"
                "image/webp" -> "webp"
                "image/bmp", "image/x-ms-bmp" -> "bmp"
                // Android decodes these to a static PNG so Flutter can display them.
                "image/gif", "image/heif", "image/heic", "image/heif-sequence",
                "image/heic-sequence", "image/avif" -> "png"
                else -> throw Exception("$displayName: формат не поддерживается этим устройством или файл повреждён")
            }
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw Exception("$displayName: не удалось прочитать изображение")
            val pixels = bounds.outWidth.toLong() * bounds.outHeight.toLong()
            if (pixels > 80_000_000L) throw Exception("$displayName: изображение больше 80 мегапикселей")
            val convert = mime in setOf("image/gif", "image/heif", "image/heic", "image/heif-sequence", "image/heic-sequence", "image/avif")
            if (convert && pixels > 24_000_000L) throw Exception("$displayName: для этого формата допустимо до 24 мегапикселей")
            var sample = 1
            if (!convert) {
                while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 2048) sample *= 2
            }
            val decoded = try {
                BitmapFactory.decodeFile(temp.absolutePath, BitmapFactory.Options().apply { inSampleSize = sample })
            } catch (_: OutOfMemoryError) {
                throw Exception("$displayName: не хватило памяти для открытия фото")
            } ?: throw Exception("$displayName: не удалось открыть изображение на этом устройстве")
            try {
                if (convert) {
                    val converted = File(photoDir, "${UUID.randomUUID()}.tmp")
                    try {
                        val saved = converted.outputStream().use { decoded.compress(Bitmap.CompressFormat.PNG, 100, it) }
                        if (!saved) throw Exception("$displayName: не удалось преобразовать изображение")
                        val id = "${UUID.randomUUID()}.$ext"
                        if (!converted.renameTo(File(photoDir, id))) throw Exception("$displayName: не удалось сохранить файл")
                        return mapOf("id" to id, "name" to displayName.take(180), "width" to bounds.outWidth, "height" to bounds.outHeight, "size" to count)
                    } finally { if (converted.exists()) converted.delete() }
                }
            } catch (_: OutOfMemoryError) {
                throw Exception("$displayName: не хватило памяти для преобразования фото")
            } finally { decoded.recycle() }
            val id = "${UUID.randomUUID()}.$ext"
            if (!temp.renameTo(File(photoDir, id))) throw Exception("$displayName: не удалось сохранить файл")
            return mapOf("id" to id, "name" to displayName.take(180), "width" to bounds.outWidth, "height" to bounds.outHeight, "size" to count)
        } finally { if (temp.exists()) temp.delete() }
    }
}
