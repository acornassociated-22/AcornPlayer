import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerFolderPicker(controller: flutterViewController)

    super.awakeFromNib()
  }

  /// Opens a real NSOpenPanel instead of file_picker's sheet, which fails on
  /// unsigned DMG builds when entitlements are missing from the signature.
  private func registerFolderPicker(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.acorn.acorn_player/folder_picker",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "pickFolder" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let panel = NSOpenPanel()
      panel.canChooseDirectories = true
      panel.canChooseFiles = false
      panel.allowsMultipleSelection = false
      panel.canCreateDirectories = false
      panel.message = "Choose your music folder"
      panel.prompt = "Choose"

      let response = panel.runModal()
      if response == .OK, let url = panel.url {
        result(url.path)
      } else {
        result(nil)
      }
    }
  }
}
