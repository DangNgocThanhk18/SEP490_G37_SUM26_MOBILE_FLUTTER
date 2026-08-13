import CryptoKit
import Darwin
import Flutter
import Security
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "ScreenCaptureProtectionPlugin"
    ) {
      ScreenCaptureProtectionPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "OfflineSecurityPlugin"
    ) {
      OfflineSecurityPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "ApplicationBadgePlugin"
    ) {
      ApplicationBadgePlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "ExternalCheckoutPlugin"
    ) {
      ExternalCheckoutPlugin.register(with: registrar)
    }
  }
}

private final class ExternalCheckoutPlugin: NSObject, FlutterPlugin {
  private static let channelName = "comiverse/external_checkout"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(ExternalCheckoutPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "open",
          let arguments = call.arguments as? [String: Any],
          let rawUrl = arguments["url"] as? String,
          let url = URL(string: rawUrl),
          url.scheme?.lowercased() == "https" else {
      result(false)
      return
    }
    DispatchQueue.main.async {
      UIApplication.shared.open(url, options: [:]) { opened in
        result(opened)
      }
    }
  }
}

private final class ApplicationBadgePlugin: NSObject, FlutterPlugin {
  private static let channelName = "comiverse/application_badge"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(ApplicationBadgePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "setCount" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let arguments = call.arguments as? [String: Any],
          let count = arguments["count"] as? Int else {
      result(
        FlutterError(
          code: "invalid_argument",
          message: "setCount expects a non-negative integer.",
          details: nil
        )
      )
      return
    }

    let normalizedCount = max(0, count)
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(normalizedCount) { error in
        DispatchQueue.main.async {
          if let error {
            result(
              FlutterError(
                code: "badge_update_failed",
                message: error.localizedDescription,
                details: nil
              )
            )
          } else {
            result(nil)
          }
        }
      }
    } else {
      DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = normalizedCount
        result(nil)
      }
    }
  }
}

private final class OfflineSecurityPlugin: NSObject, FlutterPlugin {
  private static let channelName = "comiverse/offline_security"
  private static let keyPrefix = "comiverse_offline_rsa_v1_"
  private static let maximumChallengeBytes = 4096
  private static let maximumEncryptedPageBytes = 12 * 1024 * 1024 + 16

  private let cryptoQueue = DispatchQueue(
    label: "comiverse.offline-security",
    qos: .userInitiated,
    attributes: .concurrent
  )
  private let transientKeyLock = NSLock()
  private var transientContentKeys: [String: SymmetricKey] = [:]

  static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger,
      codec: FlutterStandardMethodCodec.sharedInstance(),
      taskQueue: messenger.makeBackgroundTaskQueue?()
    )
    registrar.addMethodCallDelegate(OfflineSecurityPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "isSupported" {
      result(true)
      return
    }

    cryptoQueue.async { [weak self] in
      guard let self else { return }
      do {
        let value: Any?
        switch call.method {
        case "getOrCreateIdentity":
          let scope = try self.requiredText(call, key: "accountScope")
          let privateKey = try self.getOrCreatePrivateKey(accountScope: scope)
          guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw OfflineSecurityError("The iOS Keychain did not return a public key.")
          }
          let publicKeyData = try self.subjectPublicKeyInfo(publicKey)
          value = [
            "publicKey": publicKeyData.base64EncodedString(),
            "publicKeySha256": self.sha256Hex(publicKeyData),
            "deviceName": "iPhone",
          ]

        case "signEnrollmentChallenge":
          let scope = try self.requiredText(call, key: "accountScope")
          let challenge = try self.requiredData(call, key: "challenge")
          guard !challenge.isEmpty,
                challenge.count <= Self.maximumChallengeBytes else {
            throw OfflineSecurityError("The enrollment challenge has an invalid size.")
          }
          let privateKey = try self.getOrCreatePrivateKey(accountScope: scope)
          let algorithm = SecKeyAlgorithm.rsaSignatureMessagePSSSHA256
          guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
            throw OfflineSecurityError("RSA-PSS signing is unavailable on this iPhone.")
          }
          var error: Unmanaged<CFError>?
          guard let signature = SecKeyCreateSignature(
            privateKey,
            algorithm,
            challenge as CFData,
            &error
          ) as Data? else {
            throw OfflineSecurityError(
              error?.takeRetainedValue().localizedDescription
                ?? "The iOS Keychain could not sign the enrollment challenge."
            )
          }
          value = FlutterStandardTypedData(bytes: signature)

        case "decryptPage":
          let scope = try self.requiredText(call, key: "accountScope")
          let wrappedContentKey = try self.requiredText(call, key: "wrappedContentKey")
          let keyAlgorithm = try self.requiredText(call, key: "keyAlgorithm")
          guard keyAlgorithm == "RSA-OAEP-SHA256-MGF1SHA1" else {
            throw OfflineSecurityError("The offline package uses an unsupported key algorithm.")
          }
          let nonce = try self.requiredData(call, key: "nonce")
          let encryptedPage = try self.requiredData(call, key: "encryptedPage")
          let aad = try self.requiredData(call, key: "aad")
          guard nonce.count == 12 else {
            throw OfflineSecurityError("The AES-GCM nonce must contain 12 bytes.")
          }
          guard encryptedPage.count > 16,
                encryptedPage.count <= Self.maximumEncryptedPageBytes else {
            throw OfflineSecurityError("The encrypted page has an invalid size.")
          }
          let contentKey = try self.cachedContentKey(
            accountScope: scope,
            wrappedContentKey
          )
          let ciphertext = encryptedPage.dropLast(16)
          let tag = encryptedPage.suffix(16)
          let sealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: nonce),
            ciphertext: ciphertext,
            tag: tag
          )
          let plaintext = try AES.GCM.open(
            sealedBox,
            using: contentKey,
            authenticating: aad
          )
          value = FlutterStandardTypedData(bytes: plaintext)

        case "clearTransientKeys":
          self.clearTransientContentKeys()
          value = nil

        case "readClock":
          value = [
            "elapsedRealtimeMillis": Int64(ProcessInfo.processInfo.systemUptime * 1000),
            "bootCount": self.bootIdentifier(),
          ]

        case "deleteIdentity":
          let scope = try self.requiredText(call, key: "accountScope")
          self.clearTransientContentKeys()
          try self.deletePrivateKey(accountScope: scope)
          value = nil

        default:
          result(FlutterMethodNotImplemented)
          return
        }
        result(value)
      } catch {
        result(
          FlutterError(
            code: "offline_security_error",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  private func getOrCreatePrivateKey(accountScope: String) throws -> SecKey {
    let tag = keyTag(accountScope)
    if let existing = loadPrivateKey(tag: tag) {
      return existing
    }

    let privateAttributes: [CFString: Any] = [
      kSecAttrIsPermanent: true,
      kSecAttrApplicationTag: tag,
      kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    ]
    let attributes: [CFString: Any] = [
      kSecAttrKeyType: kSecAttrKeyTypeRSA,
      kSecAttrKeySizeInBits: 3072,
      kSecPrivateKeyAttrs: privateAttributes as CFDictionary,
    ]
    var error: Unmanaged<CFError>?
    if let created = SecKeyCreateRandomKey(attributes as CFDictionary, &error) {
      return created
    }
    // Another concurrent page request may have created the same permanent key.
    if let existing = loadPrivateKey(tag: tag) {
      return existing
    }
    throw OfflineSecurityError(
      error?.takeRetainedValue().localizedDescription
        ?? "The iOS Keychain could not create the offline identity."
    )
  }

  private func loadPrivateKey(tag: Data) -> SecKey? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassKey,
      kSecAttrKeyType: kSecAttrKeyTypeRSA,
      kSecAttrApplicationTag: tag,
      kSecReturnRef: true,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else {
      return nil
    }
    return (item as! SecKey)
  }

  private func deletePrivateKey(accountScope: String) throws {
    let query: [CFString: Any] = [
      kSecClass: kSecClassKey,
      kSecAttrKeyType: kSecAttrKeyTypeRSA,
      kSecAttrApplicationTag: keyTag(accountScope),
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw OfflineSecurityError("The iOS Keychain could not remove the offline identity.")
    }
  }

  private func subjectPublicKeyInfo(_ publicKey: SecKey) throws -> Data {
    var error: Unmanaged<CFError>?
    guard let external = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
      throw OfflineSecurityError(
        error?.takeRetainedValue().localizedDescription
          ?? "The iOS Keychain could not export the public key."
      )
    }
    // SecKey exports an RSA public key as PKCS#1. The backend accepts the
    // standard X.509 SubjectPublicKeyInfo representation.
    let rsaAlgorithmIdentifier = Data([
      0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
      0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00,
    ])
    var bitStringContent = Data([0x00])
    bitStringContent.append(external)
    var body = Data()
    body.append(rsaAlgorithmIdentifier)
    body.append(derValue(tag: 0x03, content: bitStringContent))
    return derValue(tag: 0x30, content: body)
  }

  private func unwrapContentKey(_ encoded: String, privateKey: SecKey) throws -> Data {
    let ciphertext = try decodeBase64Url(encoded)
    guard ciphertext.count == SecKeyGetBlockSize(privateKey) else {
      throw OfflineSecurityError("The wrapped content key has an invalid size.")
    }
    let algorithm = SecKeyAlgorithm.rsaEncryptionRaw
    guard SecKeyIsAlgorithmSupported(privateKey, .decrypt, algorithm) else {
      throw OfflineSecurityError("Raw RSA decryption is unavailable on this iPhone.")
    }
    var error: Unmanaged<CFError>?
    guard var encodedMessage = SecKeyCreateDecryptedData(
      privateKey,
      algorithm,
      ciphertext as CFData,
      &error
    ) as Data? else {
      throw OfflineSecurityError(
        error?.takeRetainedValue().localizedDescription
          ?? "The iOS Keychain could not unwrap the content key."
      )
    }
    let blockSize = SecKeyGetBlockSize(privateKey)
    if encodedMessage.count < blockSize {
      encodedMessage.insert(
        contentsOf: [UInt8](
          repeating: 0,
          count: blockSize - encodedMessage.count
        ),
        at: 0
      )
    }
    return try decodeOaepSha256Mgf1Sha1(encodedMessage)
  }

  private func cachedContentKey(
    accountScope: String,
    _ wrappedContentKey: String
  ) throws -> SymmetricKey {
    let cacheKey = sha256Hex(Data(accountScope.utf8)) + ":"
      + sha256Hex(try decodeBase64Url(wrappedContentKey))
    transientKeyLock.lock()
    if let cached = transientContentKeys[cacheKey] {
      transientKeyLock.unlock()
      return cached
    }
    transientKeyLock.unlock()

    let privateKey = try getOrCreatePrivateKey(accountScope: accountScope)
    var rawKey = try unwrapContentKey(wrappedContentKey, privateKey: privateKey)
    defer { rawKey.resetBytes(in: 0..<rawKey.count) }
    guard rawKey.count == 32 else {
      throw OfflineSecurityError("The content key is not AES-256.")
    }
    let candidate = SymmetricKey(data: rawKey)

    transientKeyLock.lock()
    defer { transientKeyLock.unlock() }
    if let cached = transientContentKeys[cacheKey] {
      return cached
    }
    transientContentKeys[cacheKey] = candidate
    return candidate
  }

  private func clearTransientContentKeys() {
    transientKeyLock.lock()
    transientContentKeys.removeAll(keepingCapacity: false)
    transientKeyLock.unlock()
  }

  private func decodeOaepSha256Mgf1Sha1(_ encodedMessage: Data) throws -> Data {
    let hashLength = 32
    guard encodedMessage.count >= (2 * hashLength) + 2,
          encodedMessage.first == 0 else {
      throw OfflineSecurityError("The wrapped content key has invalid OAEP padding.")
    }
    let maskedSeed = Data(encodedMessage[1..<(1 + hashLength)])
    let maskedDatabase = Data(encodedMessage[(1 + hashLength)...])
    let seed = xor(maskedSeed, mgf1Sha1(seed: maskedDatabase, length: hashLength))
    let database = xor(
      maskedDatabase,
      mgf1Sha1(seed: seed, length: maskedDatabase.count)
    )
    let expectedLabelHash = Data(SHA256.hash(data: Data()))
    guard constantTimeEqual(Data(database.prefix(hashLength)), expectedLabelHash) else {
      throw OfflineSecurityError("The wrapped content key failed OAEP verification.")
    }
    var delimiterIndex = hashLength
    while delimiterIndex < database.count && database[delimiterIndex] == 0 {
      delimiterIndex += 1
    }
    guard delimiterIndex < database.count,
          database[delimiterIndex] == 1 else {
      throw OfflineSecurityError("The wrapped content key has invalid OAEP padding.")
    }
    let messageStart = database.index(after: delimiterIndex)
    return Data(database[messageStart...])
  }

  private func mgf1Sha1(seed: Data, length: Int) -> Data {
    var output = Data()
    var counter: UInt32 = 0
    while output.count < length {
      var bigEndianCounter = counter.bigEndian
      var block = seed
      Swift.withUnsafeBytes(of: &bigEndianCounter) { block.append(contentsOf: $0) }
      output.append(contentsOf: Insecure.SHA1.hash(data: block))
      counter += 1
    }
    return Data(output.prefix(length))
  }

  private func xor(_ left: Data, _ right: Data) -> Data {
    precondition(left.count == right.count)
    return Data(zip(left, right).map { $0 ^ $1 })
  }

  private func constantTimeEqual(_ left: Data, _ right: Data) -> Bool {
    guard left.count == right.count else { return false }
    var difference: UInt8 = 0
    for (lhs, rhs) in zip(left, right) {
      difference |= lhs ^ rhs
    }
    return difference == 0
  }

  private func derValue(tag: UInt8, content: Data) -> Data {
    var output = Data([tag])
    output.append(derLength(content.count))
    output.append(content)
    return output
  }

  private func derLength(_ length: Int) -> Data {
    if length < 128 {
      return Data([UInt8(length)])
    }
    var value = length
    var bytes = [UInt8]()
    while value > 0 {
      bytes.insert(UInt8(value & 0xff), at: 0)
      value >>= 8
    }
    return Data([0x80 | UInt8(bytes.count)] + bytes)
  }

  private func keyTag(_ accountScope: String) -> Data {
    let digest = SHA256.hash(data: Data(accountScope.utf8))
    let suffix = digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    return Data((Self.keyPrefix + suffix).utf8)
  }

  private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private func decodeBase64Url(_ value: String) throws -> Data {
    var normalized = value.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    normalized += String(repeating: "=", count: (4 - normalized.count % 4) % 4)
    guard let data = Data(base64Encoded: normalized) else {
      throw OfflineSecurityError("The wrapped content key is not valid Base64URL.")
    }
    return data
  }

  private func requiredText(_ call: FlutterMethodCall, key: String) throws -> String {
    guard let arguments = call.arguments as? [String: Any],
          let value = arguments[key] as? String,
          !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw OfflineSecurityError("\(key) is required.")
    }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func requiredData(_ call: FlutterMethodCall, key: String) throws -> Data {
    guard let arguments = call.arguments as? [String: Any],
          let value = arguments[key] as? FlutterStandardTypedData else {
      throw OfflineSecurityError("\(key) is required.")
    }
    return value.data
  }

  private func bootIdentifier() -> Int64 {
    var bootTime = timeval()
    var size = MemoryLayout<timeval>.size
    let status = sysctlbyname("kern.boottime", &bootTime, &size, nil, 0)
    if status == 0 {
      return Int64(bootTime.tv_sec)
    }
    return Int64(Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime)
  }
}

private struct OfflineSecurityError: LocalizedError {
  init(_ message: String) {
    self.message = message
  }

  let message: String

  var errorDescription: String? { message }
}

private final class ScreenCaptureProtectionPlugin: NSObject, FlutterPlugin {
  private static let channelName = "comiverse/screen_capture_protection"
  private static let overlayTag = 0x434F4D49

  private var isProtected = false
  private var isAppInactive = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = ScreenCaptureProtectionPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  override init() {
    super.init()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(captureStateDidChange),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "setProtected" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let enabled = call.arguments as? Bool else {
      result(
        FlutterError(
          code: "invalid_argument",
          message: "setProtected expects a Boolean value.",
          details: nil
        )
      )
      return
    }
    DispatchQueue.main.async { [weak self] in
      self?.isProtected = enabled
      self?.updateOverlay()
      result(nil)
    }
  }

  @objc private func captureStateDidChange() {
    updateOverlay()
  }

  @objc private func appWillResignActive() {
    isAppInactive = true
    updateOverlay()
  }

  @objc private func appDidBecomeActive() {
    isAppInactive = false
    updateOverlay()
  }

  private func updateOverlay() {
    if !Thread.isMainThread {
      DispatchQueue.main.async { [weak self] in self?.updateOverlay() }
      return
    }

    let shouldCover = isProtected && (isAppInactive || UIScreen.main.isCaptured)
    for window in applicationWindows() {
      updateOverlay(in: window, shouldCover: shouldCover)
    }
  }

  private func updateOverlay(in window: UIWindow, shouldCover: Bool) {
    if shouldCover {
      guard window.viewWithTag(Self.overlayTag) == nil else { return }
      let overlay = UIView(frame: window.bounds)
      overlay.tag = Self.overlayTag
      overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      overlay.backgroundColor = .black
      overlay.isUserInteractionEnabled = false

      let label = UILabel()
      label.translatesAutoresizingMaskIntoConstraints = false
      label.text = "Screen capture is disabled for copyrighted content."
      label.textColor = .white
      label.textAlignment = .center
      label.numberOfLines = 0
      label.font = .preferredFont(forTextStyle: .headline)
      overlay.addSubview(label)
      NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        label.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 32),
        label.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -32),
      ])
      window.addSubview(overlay)
    } else {
      window.viewWithTag(Self.overlayTag)?.removeFromSuperview()
    }
  }

  private func applicationWindows() -> [UIWindow] {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
  }
}
