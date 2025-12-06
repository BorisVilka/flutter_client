import Cocoa
import FlutterMacOS

// Main macOS window hosting the Flutter interface.
// Initializes a FlutterViewController as the content view and registers
// generated plugins to enable Flutter–native integration.

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
