import Cocoa
import FlutterMacOS

// XCTest suite for the macOS Flutter Runner target.
// Extend this class to add native platform tests.
// See Apple’s XCTest documentation for usage guidelines.

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
