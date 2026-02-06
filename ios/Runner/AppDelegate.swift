import UIKit
import workmanager
import Flutter
//import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      GeneratedPluginRegistrant.register(with: self)
      print("new updated!")
      WorkmanagerPlugin.setPluginRegistrantCallback { registry in
                  GeneratedPluginRegistrant.register(with: registry)
              }
      WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "com.example.face_time_keeping.syncCheckInOut1",frequency: NSNumber(value: 15 * 60))
//      WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "com.example.face_time_keeping.syncCheckInOut2",frequency: NSNumber(value: 20 * 60))
      WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "com.example.face_time_keeping.syncCheckFace1",frequency: NSNumber(value: 15 * 60))
//      WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "com.example.face_time_keeping.syncCheckFace2",frequency: NSNumber(value: 20 * 60))
      let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
      let METHOD_CHANNEL_NAME="thuan/battery"
      let batteryChannel = FlutterMethodChannel(
        name:METHOD_CHANNEL_NAME,
        binaryMessenger: controller.binaryMessenger
      );
      batteryChannel.setMethodCallHandler { [weak self] (call, result) in
        guard let self = self else { return }

        switch call.method {
        case "getBatteryLevel":
          self.getBatteryLevel(result: result)

        case "isCharging":
          self.isCharging(result: result)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
    private func getBatteryLevel(result: FlutterResult) {
       let device = UIDevice.current
       device.isBatteryMonitoringEnabled = true

       if device.batteryState == .unknown {
         result(FlutterError(code: "UNAVAILABLE",
                             message: "Battery info unavailable",
                             details: nil))
       } else {
         result("Battery level: \(Int(device.batteryLevel * 100))%")
       }
     }

     private func isCharging(result: FlutterResult) {
       let device = UIDevice.current
       device.isBatteryMonitoringEnabled = true

       let status: String
       switch device.batteryState {
       case .charging:
         status = "Device is charging"
       case .full:
         status = "Device is fully charged"
       case .unplugged:
         status = "Device is not charging"
       default:
         status = "Battery state unknown"
       }

       result(status)
     }
}
