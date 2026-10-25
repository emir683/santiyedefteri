import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CAD_CHANNEL = "com.emircf.santiyeyonetim/cad_intent"
  private var cadMethodChannel: FlutterMethodChannel?
  private var pendingCadFile: [String: String]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: CAD_CHANNEL, binaryMessenger: controller.binaryMessenger)
    cadMethodChannel = channel
    channel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "getInitialCadFile" {
        let file = self?.pendingCadFile
        self?.pendingCadFile = nil
        result(file)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    if let url = launchOptions?[.url] as? URL {
      processIncomingUrl(url)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    processIncomingUrl(url)
    return super.application(app, open: url, options: options)
  }

  private func processIncomingUrl(_ url: URL) {
    let hasAccess = url.startAccessingSecurityScopedResource()
    defer {
      if hasAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let fileName = url.lastPathComponent
    let lower = fileName.lowercased()
    guard lower.hasSuffix(".dwg") || lower.hasSuffix(".dxf") else {
      return
    }

    let fileManager = FileManager.default
    let tempDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
    let destDir = tempDir.appendingPathComponent("cad_inbox", isDirectory: true)
    try? fileManager.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)

    let destUrl = destDir.appendingPathComponent(fileName)
    try? fileManager.removeItem(at: destUrl)

    var finalPath = url.path
    do {
      try fileManager.copyItem(at: url, to: destUrl)
      finalPath = destUrl.path
    } catch {
      finalPath = url.path
    }

    let payload: [String: String] = [
      "filePath": finalPath,
      "fileName": fileName
    ]
    self.pendingCadFile = payload
    self.cadMethodChannel?.invokeMethod("onCadFileReceived", arguments: payload)
  }
}

