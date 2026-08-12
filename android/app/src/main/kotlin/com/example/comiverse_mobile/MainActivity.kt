package com.example.comiverse_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.charset.StandardCharsets
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
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
        private const val NOTIFICATION_CHANNEL = "comiverse_activity"
        private const val OFFLINE_KEY_PREFIX = "comiverse_offline_rsa_v1_"
        private val transientContentKeys = ConcurrentHashMap<String, ByteArray>()
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
                    "clearTransientKeys" -> {
                        clearTransientContentKeys()
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
                        clearTransientContentKeys()
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
