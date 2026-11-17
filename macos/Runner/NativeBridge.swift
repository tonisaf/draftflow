import Cocoa
import FlutterMacOS

/// Owns the Dart/native message contract for the desktop window, clipboard
/// rich data (HTML & compressed images), and Finder file drag-and-drop.
final class NativeBridge {
  private static weak var currentInstance: NativeBridge?
  private let channel: FlutterMethodChannel

  private static let supportedImageExtensions: Set<String> = [
    "png",
    "jpg",
    "jpeg",
    "webp",
    "gif",
    "heic",
    "tiff",
    "tif",
    "bmp",
  ]

  init(messenger: FlutterBinaryMessenger, window: MainFlutterWindow) {
    channel = FlutterMethodChannel(
      name: "notes_here/macos_window", binaryMessenger: messenger)
    NativeBridge.currentInstance = self

    channel.setMethodCallHandler { [weak window] call, result in
      switch call.method {
      case "restoreTitleBar":
        window?.restoreTitleBar()
        result(nil)
      case "setSidebarBackdrop":
        guard let args = call.arguments as? [String: Any],
              let dark = args["dark"] as? Bool else {
          result(FlutterMethodNotImplemented)
          return
        }
        window?.setSidebarBackdrop(dark: dark)
        result(true)
      case "getClipboardHtml":
        let pasteboard = NSPasteboard.general
        let html = pasteboard.string(forType: .html)
          ?? pasteboard.string(forType: NSPasteboard.PasteboardType("public.html"))
        result(html)
      case "getClipboardImages":
        let images = NativeBridge.extractCompressedImages(from: NSPasteboard.general)
        result(images.map { FlutterStandardTypedData(bytes: $0) })
      case "setClipboardData":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterMethodNotImplemented)
          return
        }
        let text = args["text"] as? String
        let html = args["html"] as? String
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        var wrote = false
        if let text = text, !text.isEmpty {
          wrote = pasteboard.setString(text, forType: .string) || wrote
        }
        if let html = html, !html.isEmpty {
          wrote = pasteboard.setString(html, forType: .html) || wrote
        }
        result(wrote)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func notifyDragHovering(_ hovering: Bool) {
    channel.invokeMethod("onImageDragState", arguments: ["hovering": hovering])
  }

  func notifyImagesDropped(_ images: [Data]) {
    guard !images.isEmpty else { return }
    channel.invokeMethod(
      "onImagesDropped",
      arguments: ["images": images.map { FlutterStandardTypedData(bytes: $0) }]
    )
  }

  static func containsSupportedImages(in pasteboard: NSPasteboard) -> Bool {
    if let urls = pasteboard.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    ) as? [URL] {
      if urls.contains(where: { supportedImageExtensions.contains($0.pathExtension.lowercased()) }) {
        return true
      }
    }
    if pasteboard.canReadItem(withDataConformingToTypes: [
      NSPasteboard.PasteboardType.png.rawValue,
      NSPasteboard.PasteboardType.tiff.rawValue,
    ]) {
      return true
    }
    return false
  }

  static func extractCompressedImages(from pasteboard: NSPasteboard) -> [Data] {
    var results: [Data] = []
    if let urls = pasteboard.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    ) as? [URL] {
      for url in urls where supportedImageExtensions.contains(url.pathExtension.lowercased()) {
        if let raw = try? Data(contentsOf: url),
           let compressed = compressImageData(raw) {
          results.append(compressed)
        }
      }
      if !results.isEmpty {
        return results
      }
    }

    if let pngData = pasteboard.data(forType: .png),
       let compressed = compressImageData(pngData) {
      return [compressed]
    }
    if let tiffData = pasteboard.data(forType: .tiff),
       let compressed = compressImageData(tiffData) {
      return [compressed]
    }
    return results
  }

  static func compressImageData(_ rawData: Data, maxDimension: CGFloat = 1600) -> Data? {
    guard let image = NSImage(data: rawData) else { return nil }

    var pixelWidth = Int(image.size.width)
    var pixelHeight = Int(image.size.height)
    for rep in image.representations {
      if rep.pixelsWide > pixelWidth { pixelWidth = rep.pixelsWide }
      if rep.pixelsHigh > pixelHeight { pixelHeight = rep.pixelsHigh }
    }
    guard pixelWidth > 0, pixelHeight > 0 else { return nil }

    let scale = min(1.0, maxDimension / CGFloat(max(pixelWidth, pixelHeight)))
    let targetWidth = max(1, Int((CGFloat(pixelWidth) * scale).rounded()))
    let targetHeight = max(1, Int((CGFloat(pixelHeight) * scale).rounded()))

    guard let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: targetWidth,
      pixelsHigh: targetHeight,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ) else { return nil }

    bitmap.size = NSSize(width: targetWidth, height: targetHeight)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(
      in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
      from: .zero,
      operation: .copy,
      fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    // Keep compact PNG for screenshots/diagrams <= 350 KB, otherwise encode JPEG.
    if let png = bitmap.representation(using: .png, properties: [:]),
       png.count <= 350_000 {
      return png
    }

    // Flatten onto white before JPEG encoding so transparent regions stay clean.
    guard let opaqueBitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: targetWidth,
      pixelsHigh: targetHeight,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ) else {
      return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.80])
    }
    opaqueBitmap.size = NSSize(width: targetWidth, height: targetHeight)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: opaqueBitmap)
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight).fill()
    bitmap.draw(in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
    NSGraphicsContext.restoreGraphicsState()

    if let jpeg = opaqueBitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.80]) {
      return jpeg
    }
    return bitmap.representation(using: .png, properties: [:])
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }
}
