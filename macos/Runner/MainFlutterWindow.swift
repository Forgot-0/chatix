import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // A phone-sized window is the smallest the layout is drawn for (one
    // pane, bottom bar) — DesktopSizes.minWindow on the Dart side.
    self.contentMinSize = NSSize(width: 380, height: 560)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
