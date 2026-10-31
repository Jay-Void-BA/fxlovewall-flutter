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
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FXLiquidGlass")
    registrar?.register(LiquidGlassFactory(), withId: "me.fxlove/liquid_glass")
  }
}

/// A single system material surface underneath the Flutter tab controls.
/// Xcode 26 uses the genuine UIKit Liquid Glass effect on iOS 26 and later.
/// Earlier SDKs and devices use the supported system material fallback.
final class LiquidGlassFactory: NSObject, FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    return LiquidGlassView(frame: frame)
  }
}

final class LiquidGlassView: NSObject, FlutterPlatformView {
  private let surface: UIVisualEffectView

  init(frame: CGRect) {
    let effect: UIVisualEffect
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect(style: .regular)
      glass.isInteractive = true
      effect = glass
    } else {
      effect = UIBlurEffect(style: .systemUltraThinMaterial)
    }
    #else
    effect = UIBlurEffect(style: .systemUltraThinMaterial)
    #endif
    surface = UIVisualEffectView(effect: effect)
    super.init()
    surface.frame = frame
    surface.clipsToBounds = true
    surface.layer.cornerRadius = 30
    surface.isUserInteractionEnabled = false
    surface.accessibilityElementsHidden = true
  }

  func view() -> UIView { return surface }
}
