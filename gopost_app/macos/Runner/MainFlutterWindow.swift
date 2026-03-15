import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // Workaround for "Failed to foreground app; open returned 1" (Flutter macOS regression).
    // Ensure window is shown and can receive focus so the runner stays connected.
    self.orderFrontRegardless()
    self.makeKey()
  }
}
