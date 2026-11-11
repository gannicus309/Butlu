import AVFoundation
import Flutter
import UIKit
import Vision

/// On-device text recognition with Apple's Vision framework, for reading
/// best-before dates off packaging. Nothing leaves the phone.
///
/// Dart calls `butlu/text_recognition` → `recognizeText(path)` with an image
/// file and gets back the recognised lines, best guesses first.
final class TextRecognizer: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "butlu/text_recognition",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(TextRecognizer(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // The simulator claims a camera (to image_picker and to
    // UIImagePickerController) but has no capture device behind it.
    if call.method == "hasCamera" {
      result(AVCaptureDevice.default(for: .video) != nil)
      return
    }
    guard call.method == "recognizeText",
          let path = call.arguments as? String
    else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
      result(FlutterError(code: "bad_image", message: "Couldn't read the photo", details: nil))
      return
    }

    let request = VNRecognizeTextRequest { request, error in
      if let error {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision", message: error.localizedDescription, details: nil))
        }
        return
      }
      // Best reading of each line in order (date keywords and the date
      // usually sit on neighbouring lines), then the runner-up readings:
      // inkjet dates on cartons are often misread on the first guess.
      let observations = request.results as? [VNRecognizedTextObservation] ?? []
      let best = observations.compactMap { $0.topCandidates(1).first?.string }
      let alternates = observations.flatMap { $0.topCandidates(3).dropFirst().map(\.string) }
      let lines = best + alternates.filter { !best.contains($0) }
      DispatchQueue.main.async { result(lines) }
    }
    request.recognitionLevel = .accurate
    // Dates are mostly digits and dots; autocorrect would "fix" them into
    // words.
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["de-DE", "en-US"]

    let orientation = CGImagePropertyOrientation(image.imageOrientation)
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
          .perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
}

private extension CGImagePropertyOrientation {
  /// Camera photos are stored sideways with a rotation flag; Vision needs
  /// that flag to read the text the right way up.
  init(_ o: UIImage.Orientation) {
    switch o {
    case .up: self = .up
    case .down: self = .down
    case .left: self = .left
    case .right: self = .right
    case .upMirrored: self = .upMirrored
    case .downMirrored: self = .downMirrored
    case .leftMirrored: self = .leftMirrored
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}
