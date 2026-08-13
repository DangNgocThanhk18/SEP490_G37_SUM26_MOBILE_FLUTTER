package com.example.comiverse_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.system.Os
import android.util.Base64
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.charset.StandardCharsets
import java.io.File
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.Signature
import java.security.spec.MGF1ParameterSpec
import java.security.spec.PSSParameterSpec
import java.util.concurrent.ConcurrentHashMap
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource
import javax.crypto.spec.SecretKeySpec

class MainActivity : FlutterActivity() {
    companion object {
        private const val SCREEN_CAPTURE_CHANNEL = "comiverse/screen_capture_protection"
        private const val OFFLINE_SECURITY_CHANNEL = "comiverse/offline_security"
        private const val EXTERNAL_CHECKOUT_CHANNEL = "comiverse/external_checkout"
        private const val NOTIFICATION_CHANNEL = "comiverse_activity"
        private const val OFFLINE_KEY_PREFIX = "comiverse_offline_rsa_v1_"
        private val TRANSIENT_CACHE_MAGIC = "CVSC1".toByteArray(StandardCharsets.US_ASCII)
        private const val GCM_NONCE_BYTES = 12
        private const val GCM_TAG_BYTES = 16
        private const val MAXIMUM_PLAINTEXT_PAGE_BYTES = 12 * 1024 * 1024
        private val transientContentKeys = ConcurrentHashMap<String, ByteArray>()
        private val transientCacheKeyLock = Any()
        private var transientPageCacheKey: ByteArray? = null
        private val secureRandom = SecureRandom()
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL,
                "ComiVerse activity",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Replies, forum activity, and ComiVerse announcements"
                enableVibration(true)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREEN_CAPTURE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "setProtected") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val isProtected = call.arguments as? Boolean ?: false
            runOnUiThread {
                if (isProtected) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EXTERNAL_CHECKOUT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "open") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val rawUrl = call.argument<String>("url")
            val uri = rawUrl?.let(Uri::parse)
            if (uri == null || uri.scheme?.lowercase() != "https") {
                result.success(false)
                return@setMethodCallHandler
            }
            try {
                startActivity(Intent(Intent.ACTION_VIEW, uri))
                result.success(true)
            } catch (_: Exception) {
                result.success(false)
            }
        }

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val offlineTaskQueue = messenger.makeBackgroundTaskQueue()
        MethodChannel(
            messenger,
            OFFLINE_SECURITY_CHANNEL,
            StandardMethodCodec.INSTANCE,
            offlineTaskQueue,
        ).setMethodCallHandler { call, result ->
            if (call.method == "isSupported") {
                result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                return@setMethodCallHandler
            }
            try {
                when (call.method) {
                    "getOrCreateIdentity" -> {
                        val scope = requiredText(call.argument<String>("accountScope"), "accountScope")
                        val keyPair = getOrCreateOfflineKeyPair(scope)
                        val encoded = keyPair.public.encoded
                        val response = mapOf(
                            "publicKey" to Base64.encodeToString(encoded, Base64.NO_WRAP),
                            "publicKeySha256" to sha256Hex(encoded),
                            "deviceName" to listOf(Build.MANUFACTURER, Build.MODEL)
                                .filter { it.isNotBlank() }
                                .joinToString(" ")
                                .ifBlank { "Android device" },
                        )
                        result.success(response)
                    }
                    "signEnrollmentChallenge" -> {
                        val scope = requiredText(call.argument<String>("accountScope"), "accountScope")
                        val challenge = call.argument<ByteArray>("challenge")
                            ?: throw IllegalArgumentException("challenge is required")
                        require(challenge.isNotEmpty() && challenge.size <= 4096) {
                            "challenge has an invalid size"
                        }
                        val privateKey = getOrCreateOfflineKeyPair(scope).private
                        val signature = Signature.getInstance("SHA256withRSA/PSS")
                        signature.setParameter(
                            PSSParameterSpec(
                                "SHA-256",
                                "MGF1",
                                MGF1ParameterSpec.SHA256,
                                32,
                                1,
                            ),
                        )
                        signature.initSign(privateKey)
                        signature.update(challenge)
                        val bytes = signature.sign()
                        result.success(bytes)
                    }
                    "decryptPage" -> {
                        val scope = requiredText(call.argument<String>("accountScope"), "accountScope")
                        val wrappedContentKey = requiredText(
                            call.argument<String>("wrappedContentKey"),
                            "wrappedContentKey",
                        )
                        val algorithm = requiredText(
                            call.argument<String>("keyAlgorithm"),
                            "keyAlgorithm",
                        )
                        require(
                            algorithm == "RSA-OAEP-SHA256-MGF1SHA1",
                        ) { "Unsupported key wrapping algorithm" }
                        val nonce = call.argument<ByteArray>("nonce")
                            ?: throw IllegalArgumentException("nonce is required")
                        val encryptedPage = call.argument<ByteArray>("encryptedPage")
                            ?: throw IllegalArgumentException("encryptedPage is required")
                        val aad = call.argument<ByteArray>("aad")
                            ?: throw IllegalArgumentException("aad is required")
                        require(nonce.size == 12) { "AES-GCM nonce must contain 12 bytes" }
                        require(encryptedPage.size > 16 && encryptedPage.size <= 12 * 1024 * 1024 + 16) {
                            "Encrypted page has an invalid size"
                        }
                        val wrappedKeyBytes = decodeBase64Url(wrappedContentKey)
                        val cacheKey = transientKeyCacheKey(scope, wrappedKeyBytes)
                        val contentKey = transientContentKeys[cacheKey] ?: synchronized(transientContentKeys) {
                            transientContentKeys[cacheKey] ?: unwrapContentKey(
                                scope,
                                wrappedKeyBytes,
                            ).also { transientContentKeys[cacheKey] = it }
                        }
                        require(contentKey.size == 32) { "Content key must be AES-256" }
                        val pageCipher = Cipher.getInstance("AES/GCM/NoPadding")
                        pageCipher.init(
                            Cipher.DECRYPT_MODE,
                            SecretKeySpec(contentKey, "AES"),
                            GCMParameterSpec(128, nonce),
                        )
                        pageCipher.updateAAD(aad)
                        val decryptedPage = pageCipher.doFinal(encryptedPage)
                        result.success(decryptedPage)
                    }
                    "sealTransientPage" -> {
                        val plaintext = call.argument<ByteArray>("plaintext")
                            ?: throw IllegalArgumentException("plaintext is required")
                        val aad = call.argument<ByteArray>("aad")
                            ?: throw IllegalArgumentException("aad is required")
                        require(plaintext.isNotEmpty() && plaintext.size <= MAXIMUM_PLAINTEXT_PAGE_BYTES) {
                            "Plaintext page has an invalid size"
                        }
                        require(aad.isNotEmpty() && aad.size <= 4096) { "Cache AAD has an invalid size" }

                        val cacheKey = transientPageCacheKey(create = true)
                        val nonce = ByteArray(GCM_NONCE_BYTES).also(secureRandom::nextBytes)
                        try {
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(
                                Cipher.ENCRYPT_MODE,
                                SecretKeySpec(cacheKey, "AES"),
                                GCMParameterSpec(128, nonce),
                            )
                            cipher.updateAAD(aad)
                            val ciphertext = cipher.doFinal(plaintext)
                            val frame = ByteArray(TRANSIENT_CACHE_MAGIC.size + nonce.size + ciphertext.size)
                            TRANSIENT_CACHE_MAGIC.copyInto(frame)
                            nonce.copyInto(frame, destinationOffset = TRANSIENT_CACHE_MAGIC.size)
                            ciphertext.copyInto(
                                frame,
                                destinationOffset = TRANSIENT_CACHE_MAGIC.size + nonce.size,
                            )
                            result.success(frame)
                        } finally {
                            cacheKey.fill(0)
                            nonce.fill(0)
                        }
                    }
                    "openTransientPage" -> {
                        val frame = call.argument<ByteArray>("sealedPage")
                            ?: throw IllegalArgumentException("sealedPage is required")
                        val aad = call.argument<ByteArray>("aad")
                            ?: throw IllegalArgumentException("aad is required")
                        require(
                            frame.size > TRANSIENT_CACHE_MAGIC.size + GCM_NONCE_BYTES + GCM_TAG_BYTES &&
                                frame.size <= MAXIMUM_PLAINTEXT_PAGE_BYTES + TRANSIENT_CACHE_MAGIC.size +
                                GCM_NONCE_BYTES + GCM_TAG_BYTES,
                        ) { "Sealed cache page has an invalid size" }
                        require(
                            frame.copyOfRange(0, TRANSIENT_CACHE_MAGIC.size)
                                .contentEquals(TRANSIENT_CACHE_MAGIC),
                        ) {
                            "Sealed cache page version is unsupported"
                        }
                        require(aad.isNotEmpty() && aad.size <= 4096) { "Cache AAD has an invalid size" }

                        val cacheKey = transientPageCacheKey(create = false)
                        val nonceStart = TRANSIENT_CACHE_MAGIC.size
                        val nonce = frame.copyOfRange(nonceStart, nonceStart + GCM_NONCE_BYTES)
                        val ciphertext = frame.copyOfRange(nonceStart + GCM_NONCE_BYTES, frame.size)
                        try {
                            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                            cipher.init(
                                Cipher.DECRYPT_MODE,
                                SecretKeySpec(cacheKey, "AES"),
                                GCMParameterSpec(128, nonce),
                            )
                            cipher.updateAAD(aad)
                            result.success(cipher.doFinal(ciphertext))
                        } finally {
                            cacheKey.fill(0)
                            nonce.fill(0)
                        }
                    }
                    "clearTransientKeys" -> {
                        clearTransientSecrets()
                        result.success(null)
                    }
                    "protectOfflineFile" -> {
                        val rawPath = requiredText(call.argument<String>("path"), "path")
                        val file = File(rawPath).canonicalFile
                        val privateRoot = filesDir.canonicalFile
                        require(file.toPath().startsWith(privateRoot.toPath()) && file.isFile) {
                            "Offline package path is outside app-private storage"
                        }
                        Os.chmod(file.path, 0x180) // Owner read/write only (0600).
                        result.success(null)
                    }
                    "readClock" -> {
                        val clockData = mapOf(
                            "elapsedRealtimeMillis" to SystemClock.elapsedRealtime(),
                            "bootCount" to Settings.Global.getInt(
                                contentResolver,
                                Settings.Global.BOOT_COUNT,
                                -1,
                            ),
                        )
                        result.success(clockData)
                    }
                    "deleteIdentity" -> {
                        val scope = requiredText(call.argument<String>("accountScope"), "accountScope")
                        clearTransientSecrets()
                        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                        val alias = offlineKeyAlias(scope)
                        if (keyStore.containsAlias(alias)) keyStore.deleteEntry(alias)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error(
                    "offline_security_error",
                    error.message ?: "Offline security operation failed",
                    null,
                )
            }
        }
    }

    private fun getOrCreateOfflineKeyPair(accountScope: String): java.security.KeyPair {
        val alias = offlineKeyAlias(accountScope)
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val certificate = keyStore.getCertificate(alias)
        val privateKey = keyStore.getKey(alias, null) as? java.security.PrivateKey
        if (certificate != null && privateKey != null) {
            return java.security.KeyPair(certificate.publicKey, privateKey)
        }

        val generator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_RSA,
            "AndroidKeyStore",
        )
        val purposes = KeyProperties.PURPOSE_DECRYPT or KeyProperties.PURPOSE_SIGN
        val specification = KeyGenParameterSpec.Builder(alias, purposes)
            .setKeySize(3072)
            .setDigests(
                KeyProperties.DIGEST_SHA256,
                KeyProperties.DIGEST_SHA512,
                KeyProperties.DIGEST_SHA1,
            )
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PSS)
            .setRandomizedEncryptionRequired(true)
            .setUserAuthenticationRequired(false)
            .build()
        generator.initialize(specification)
        return generator.generateKeyPair()
    }

    private fun unwrapContentKey(accountScope: String, wrappedKey: ByteArray): ByteArray {
        val privateKey = getOrCreateOfflineKeyPair(accountScope).private
        val unwrapCipher = Cipher.getInstance("RSA/ECB/OAEPPadding")
        val oaep = OAEPParameterSpec(
            "SHA-256",
            "MGF1",
            MGF1ParameterSpec.SHA1,
            PSource.PSpecified.DEFAULT,
        )
        unwrapCipher.init(Cipher.DECRYPT_MODE, privateKey, oaep)
        return unwrapCipher.doFinal(wrappedKey)
    }

    private fun transientKeyCacheKey(accountScope: String, wrappedKey: ByteArray): String =
        sha256Hex(accountScope.toByteArray(StandardCharsets.UTF_8)) + ":" + sha256Hex(wrappedKey)

    private fun clearTransientContentKeys() {
        transientContentKeys.values.forEach { it.fill(0) }
        transientContentKeys.clear()
    }

    private fun transientPageCacheKey(create: Boolean): ByteArray = synchronized(transientCacheKeyLock) {
        var key = transientPageCacheKey
        if (key == null && create) {
            key = ByteArray(32).also(secureRandom::nextBytes)
            transientPageCacheKey = key
        }
        require(key != null) { "The transient cache key is no longer available" }
        key.copyOf()
    }

    private fun clearTransientSecrets() {
        clearTransientContentKeys()
        synchronized(transientCacheKeyLock) {
            transientPageCacheKey?.fill(0)
            transientPageCacheKey = null
        }
    }

    override fun onDestroy() {
        clearTransientSecrets()
        super.onDestroy()
    }

    private fun offlineKeyAlias(accountScope: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(
            accountScope.toByteArray(StandardCharsets.UTF_8),
        )
        return OFFLINE_KEY_PREFIX + digest.take(16).joinToString("") { "%02x".format(it) }
    }

    private fun sha256Hex(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") {
            "%02x".format(it)
        }

    private fun decodeBase64Url(value: String): ByteArray {
        val padded = value + "=".repeat((4 - value.length % 4) % 4)
        return Base64.decode(padded, Base64.URL_SAFE or Base64.NO_WRAP)
    }

    private fun requiredText(value: String?, field: String): String {
        val trimmed = value?.trim().orEmpty()
        require(trimmed.isNotEmpty()) { "$field is required" }
        return trimmed
    }
}
