import 'dart:isolate';
import 'dart:ui' as ui;

class IsolateListenUtil {
  static const bgToUiPortName = 'bg_to_ui_port';

  static late final ReceivePort bgToUiPort;
  static void listen(Function(dynamic) onReceive) {
    // Đảm bảo không bị trùng khi hot restart
    ui.IsolateNameServer.removePortNameMapping(bgToUiPortName);

    bgToUiPort = ReceivePort();
    ui.IsolateNameServer.registerPortWithName(
      bgToUiPort.sendPort,
      bgToUiPortName,
    );
    bgToUiPort.listen((dynamic msg) {
      onReceive(msg);
    });
  }
}
