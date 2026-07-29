import Flutter
import UIKit

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
    ScreenCaptureProtectionPlugin.register(
      with: engineBridge.pluginRegistry.registrar(
        forPlugin: "ScreenCaptureProtectionPlugin"
      )
    )
  }
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
