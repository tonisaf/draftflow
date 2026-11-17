import Cocoa
import FlutterMacOS

// A decorative material must never become the mouse event target, including
// over transparent Flutter pixels. All input belongs to the Flutter view.
class BackdropView: NSVisualEffectView {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  private var nativeBridge: NativeBridge?
  private var isImageDragHovering = false
  private weak var backdropView: BackdropView?
  private var lastInteractionRefresh: TimeInterval = 0

  override var isOpaque: Bool {
    get { false }
    set { super.isOpaque = false }
  }

  override var title: String {
    get { "" }
    set { }
  }

  override var backgroundColor: NSColor! {
    get { .clear }
    set { super.backgroundColor = .clear }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    DistributedNotificationCenter.default().removeObserver(self)
  }

  override func awakeFromNib() {
    let windowFrame = self.frame
    let flutter = FlutterViewController()
    flutter.backgroundColor = .clear

    self.contentViewController = flutter
    self.setFrame(windowFrame, display: true)
    self.delegate = self
    self.acceptsMouseMovedEvents = true

    super.isOpaque = false
    super.backgroundColor = .clear
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    styleMask.insert(.fullSizeContentView)
    isMovableByWindowBackground = true

    let backdrop = BackdropView(frame: flutter.view.bounds)
    backdrop.material = .sidebar
    backdrop.blendingMode = .behindWindow
    backdrop.state = .active
    backdrop.autoresizingMask = [.width, .height]
    backdrop.wantsLayer = true
    flutter.view.addSubview(backdrop, positioned: .below, relativeTo: nil)
    self.backdropView = backdrop

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(throttledRefresh),
      name: NSWindow.didUpdateNotification,
      object: self
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(refreshBackdrop),
      name: NSWindow.didChangeOcclusionStateNotification,
      object: self
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(refreshBackdrop),
      name: NSApplication.didBecomeActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(refreshBackdrop),
      name: NSApplication.didUnhideNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(refreshBackdrop),
      name: NSWindow.didDeminiaturizeNotification,
      object: self
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(refreshBackdrop),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(refreshBackdrop),
      name: NSWindow.didEnterFullScreenNotification,
      object: self
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(refreshBackdrop),
      name: NSWindow.didExitFullScreenNotification,
      object: self
    )
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(refreshBackdrop),
      name: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil
    )

    // Observe distributed notifications emitted by system UI / Exposé / Mission Control
    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(refreshBackdrop),
      name: NSNotification.Name("com.apple.expose.awake"),
      object: nil,
      suspensionBehavior: .deliverImmediately
    )
    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(refreshBackdrop),
      name: NSNotification.Name("com.apple.expose.front.awake"),
      object: nil,
      suspensionBehavior: .deliverImmediately
    )

    nativeBridge = NativeBridge(messenger: flutter.engine.binaryMessenger, window: self)

    // Route external Finder/image drag-and-drop directly through MainFlutterWindow.
    flutter.view.unregisterDraggedTypes()
    self.registerForDraggedTypes([.fileURL, .png, .tiff])

    RegisterGeneratedPlugins(registry: flutter)

    super.awakeFromNib()
  }

  func restoreTitleBar() {
    super.isOpaque = false
    super.backgroundColor = .clear
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    styleMask.insert(.fullSizeContentView)
    isMovableByWindowBackground = true
  }

  override func becomeKey() {
    super.becomeKey()
    refreshBackdrop()
  }

  override func becomeMain() {
    super.becomeMain()
    refreshBackdrop()
  }

  override func sendEvent(_ event: NSEvent) {
    super.sendEvent(event)
    throttledRefresh()
  }

  @objc func throttledRefresh() {
    let now = ProcessInfo.processInfo.systemUptime
    if now - lastInteractionRefresh > 0.05 {
      lastInteractionRefresh = now
      refreshBackdrop()
    }
  }

  func windowDidEnterFullScreen(_ notification: Notification) {
    refreshBackdrop()
  }

  func windowDidExitFullScreen(_ notification: Notification) {
    refreshBackdrop()
  }

  @objc func refreshBackdrop() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.superIsOpaqueFalse()
      if let flutter = self.contentViewController as? FlutterViewController {
        flutter.backgroundColor = .clear
        flutter.view.layer?.backgroundColor = NSColor.clear.cgColor
        flutter.view.layer?.isOpaque = false
      }
      if let backdrop = self.backdropView {
        backdrop.state = .active
        backdrop.material = .sidebar
        backdrop.blendingMode = .behindWindow
        backdrop.needsDisplay = true
        backdrop.displayIfNeeded()
      }
      self.invalidateShadow()
    }

    // Seamless follow-up to ensure transparency stays active once the space zoom animation settles
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      guard let self = self, let backdrop = self.backdropView else { return }
      self.superIsOpaqueFalse()
      backdrop.state = .active
      backdrop.material = .sidebar
      backdrop.blendingMode = .behindWindow
      backdrop.needsDisplay = true
      backdrop.displayIfNeeded()
      self.invalidateShadow()
    }
  }

  private func superIsOpaqueFalse() {
    super.isOpaque = false
    super.backgroundColor = .clear
  }

  func setSidebarBackdrop(dark: Bool) {
    appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    refreshBackdrop()
  }

  private func setImageDragHovering(_ hovering: Bool) {
    guard isImageDragHovering != hovering else { return }
    isImageDragHovering = hovering
    nativeBridge?.notifyDragHovering(hovering)
  }
}

extension MainFlutterWindow: NSDraggingDestination {
  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard NativeBridge.containsSupportedImages(in: sender.draggingPasteboard) else {
      return []
    }
    setImageDragHovering(true)
    return .copy
  }

  func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard NativeBridge.containsSupportedImages(in: sender.draggingPasteboard) else {
      setImageDragHovering(false)
      return []
    }
    setImageDragHovering(true)
    return .copy
  }

  func draggingExited(_ sender: NSDraggingInfo?) {
    setImageDragHovering(false)
  }

  func draggingEnded(_ sender: NSDraggingInfo) {
    setImageDragHovering(false)
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    setImageDragHovering(false)
    let images = NativeBridge.extractCompressedImages(from: sender.draggingPasteboard)
    guard !images.isEmpty else { return false }
    nativeBridge?.notifyImagesDropped(images)
    return true
  }
}
