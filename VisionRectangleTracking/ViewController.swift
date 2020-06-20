//
//  ViewController.swift
//  VisionRectangleTracking
//
//  Created by SCI-Viennarz on 6/17/20.
//  Copyright © 2020 VVC. All rights reserved.
//

import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController {

  private var requests = [VNRequest]()
  private var rectangleLastObservation: VNRectangleObservation?
  private var lastObservation: VNDetectedObjectObservation?
  private var sequenceHandler = VNSequenceRequestHandler()
  private var maskLayer: CAShapeLayer = CAShapeLayer()

  private let session = AVCaptureSession()
  private var previewLayer: AVCaptureVideoPreviewLayer!
  private let queue = DispatchQueue(label: "com.vision.videoqueue")

  private var overlayView = UIView()
  private var overlayView2 = UIView()

  private var overlayer = CALayer()

//  private var maskLayer = CAShapeLayer()

  lazy var rectangleDetectionRequest: VNDetectRectanglesRequest = {
    let rectDetectRequest = VNDetectRectanglesRequest(completionHandler: self.handleDetectedRectangles)
    // Customize & configure the request to detect only certain rectangles.
    rectDetectRequest.maximumObservations = 1 // Vision currently supports up to 16.
    rectDetectRequest.minimumConfidence = 0.6 // Be confident.
    rectDetectRequest.minimumAspectRatio = 0.3 // height / width
    return rectDetectRequest
  }()

  @IBOutlet weak var captureView: UIView!

  override func viewDidLoad() {
    overlayView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    overlayView.layer.borderColor = UIColor.red.cgColor
    overlayView.layer.borderWidth = 4
    overlayView.backgroundColor = .clear

    overlayView2.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
    overlayView2.layer.borderColor = UIColor.yellow.cgColor
    overlayView2.layer.borderWidth = 4
    overlayView2.backgroundColor = .clear

    view.addSubview(overlayView)

    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(userTapped))
    self.captureView.addGestureRecognizer(tapGesture)

    super.viewDidLoad()

    //Vision rectangle detection request setup
    self.setupVision()

    //AVVideo Capture setup and starting the capture
    self.setupAvCaptureSession()
    self.startVideoCapture()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    previewLayer.frame = self.captureView.bounds
  }

  //MARK: AVCaptureSession Methods

  func setupAvCaptureSession() {
    do {
      previewLayer = AVCaptureVideoPreviewLayer(session: session)
      captureView.layer.addSublayer(previewLayer)

      let input = try AVCaptureDeviceInput(device: AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)!)

      let output = AVCaptureVideoDataOutput()
      output.setSampleBufferDelegate(self, queue: queue)
//      output.alwaysDiscardsLateVideoFrames = true
//      output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
//      previewLayer.videoGravity = .resizeAspectFill


      session.addInput(input)
      session.addOutput(output)
    } catch {
      print(error)
    }
  }


  @objc private func userTapped(_ sender: UITapGestureRecognizer) {
    // get the center of the tap

    self.overlayView.frame.size = CGSize(width: 300, height: 300)
    self.overlayView.center = sender.location(in: self.view)

    // convert the rect for the initial observation
    let originalRect = self.overlayView.frame
    var convertedRect = self.previewLayer.metadataOutputRectConverted(fromLayerRect: originalRect)
    convertedRect.origin.y = 1 - convertedRect.origin.y

    let newObservation = VNRectangleObservation(boundingBox: convertedRect)
    self.lastObservation = newObservation
  }

  func startVideoCapture() {
    if session.isRunning {
      print("session already exists")
      return
    }
    session.startRunning()
  }

  func handle(buffer: CMSampleBuffer) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }

    let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

//    do {
//      try imageRequestHandler.perform([rectangleDetectionRequest])
//    } catch(let error) {
//      print(error)
//    }


    // 3
    do {
      try sequenceHandler.perform(
        [rectangleDetectionRequest],
        on: pixelBuffer,
        orientation: .left)
    } catch {
      print(error.localizedDescription)
    }


  }

  func handleLastObservation(buffer sampleBuffer: CMSampleBuffer) {
    guard
    // get the CVPixelBuffer out of the CMSampleBuffer
    let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
      // make sure that there is a previous observation we can feed into the request
    let lastObservation = self.lastObservation
      else { return }

    // create the request
    let request = VNTrackObjectRequest(detectedObjectObservation: lastObservation, completionHandler: self.handleVisionRequestUpdate)

    // set the accuracy to high
    // this is slower, but it works a lot better
    request.trackingLevel = .accurate

    // perform the request
    do {
      try self.sequenceHandler.perform([request], on: pixelBuffer)
    } catch {
      print("Throws: \(error)")
    }

  }

  private func handleVisionRequestUpdate(_ request: VNRequest, error: Error?) {
    // Dispatch to the main queue because we are touching non-atomic, non-thread safe properties of the view controller
    DispatchQueue.main.async {
      // make sure we have an actual result
      guard let newObservation = request.results?.first as? VNDetectedObjectObservation else { return }

      // prepare for next loop
      self.lastObservation = newObservation

      // check the confidence level before updating the UI
      guard newObservation.confidence >= 0.3 else {
        // hide the rectangle when we lose accuracy so the user knows something is wrong
        self.overlayView.frame = .zero
        return
      }

      // calculate view rect
      var transformedRect = newObservation.boundingBox
      transformedRect.origin.y = 1 - transformedRect.origin.y
      let convertedRect = self.previewLayer.layerRectConverted(fromMetadataOutputRect: transformedRect)
      // move the highlight view
      self.overlayView.frame = convertedRect

    }
  }

  //MARK:  - Vision Setup


  func setupVision() {

  }


  //MARK: Vision Completion Handlers

  func handleDetectedRectangles(request: VNRequest, error: Error?) {
    guard let results = request.results as? [VNRectangleObservation] else { return }

    print("results", results)
    for observation in results {
      print("rectangle observation", observation)
      makeOverlay(from: observation)
      self.rectangleLastObservation = observation

    }
  }

  func reqeustHandler(request: VNRequest?, error: Error?) {
    if let error = error {
      print("Error in tracking request \(error.localizedDescription)")
      return
    }


    guard let request = request,
      let results = request.results,
      let ob = results as? [VNRectangleObservation]
      else { return }

    print("obs \(ob)")

  }


  func makeOverlay(from observation: VNRectangleObservation) {
    DispatchQueue.main.async {
      let boundingBoxOnScreen = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observation.boundingBox)
      let path = CGPath(rect: boundingBoxOnScreen, transform: nil)
      self.maskLayer.path = path
      
      
      print(observation.boundingBox)
      let x = self.previewLayer.frame.width * observation.boundingBox.origin.x
      let height = self.previewLayer.frame.height * observation.boundingBox.height
      let y = (self.previewLayer.frame.height) * (observation.boundingBox.origin.y) + 50
      let width = self.previewLayer.frame.width * observation.boundingBox.width


      let bounds = CGRect(
        x: x,
        y: y,
        width: width,
        height: height)

      self.overlayView.frame = bounds
      
      let points = [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft]
      let convertedPoints = points.map { self.convertFromCamera($0) }

      let bezierPath = UIBezierPath()
      bezierPath.move(to: .zero)
      bezierPath.addLine(to: convertedPoints[0])
      bezierPath.addLine(to: convertedPoints[1])
      bezierPath.addLine(to: convertedPoints[2])
      bezierPath.addLine(to: convertedPoints[3])
      bezierPath.addLine(to: .zero)
//      bezierPath.move(to: .zero)
//      bezierPath.addLine(to: CGPoint(x: 50, y: 50))
//      bezierPath.addLine(to: CGPoint(x: 50, y: 150))
//      bezierPath.addLine(to: CGPoint(x: 150, y: 50))
//      bezierPath.addLine(to: .zero)
      
      
//      self.maskLayer.path = bezierPath.cgPath
      self.maskLayer.strokeColor = UIColor.blue.cgColor
      self.maskLayer.fillColor = UIColor.clear.cgColor
      self.maskLayer.cornerRadius = 15
      self.maskLayer.lineWidth = 1.0
      self.maskLayer.position = CGPoint(x: 10, y: 10)
      
//      self.previewLayer.addSublayer(self.maskLayer)

    }

  }
  
  func convert(rect: CGRect) -> CGRect {
    // 1
    let origin = previewLayer.layerPointConverted(fromCaptureDevicePoint: rect.origin)

    // 2
    let size = previewLayer.layerPointConverted(fromCaptureDevicePoint: rect.size.cgPoint)

    // 3
    return CGRect(origin: origin, size: size.cgSize)
  }

  func handleTrackingRequest() {

  }

}

//MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_
    output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection) {

//    guard (lastObservation != nil) else {
//      handle(buffer: sampleBuffer)
//      return
//    }

//    handleLastObservation(buffer: sampleBuffer)
    handle(buffer: sampleBuffer)


  }
  
    func convertFromCamera(_ point: CGPoint) -> CGPoint {
  //    let orientation = UIApplication.shared.supportedInterfaceOrientations(for: UIApplication.shared.windows.first)
      let orientation = UIDevice.current.orientation

      switch orientation {
      case .portrait:
        return CGPoint(x: point.y * self.previewLayer.frame.width, y: point.x * self.previewLayer.frame.height)
      case .landscapeLeft:
        return CGPoint(x: (1 - point.x) * self.previewLayer.frame.width, y: point.y * self.previewLayer.frame.height)
      case .landscapeRight:
        return CGPoint(x: point.x * self.previewLayer.frame.width, y: (1 - point.y) * self.previewLayer.frame.height)
      case .portraitUpsideDown:
        return CGPoint(x: (1 - point.y) * self.previewLayer.frame.width, y: (1 - point.x) * self.previewLayer.frame.height)
      default:
        return CGPoint(x: point.y * self.previewLayer.frame.width, y: point.x * self.previewLayer.frame.height)
      }
    }



}


extension CIImage {
  func toUIImage() -> UIImage? {
    let context: CIContext = CIContext.init(options: nil)

    if let cgImage: CGImage = context.createCGImage(self, from: self.extent) {
      return UIImage(cgImage: cgImage)
    } else {
      return nil
    }
  }
}

// Convert UIImageOrientation to CGImageOrientation for use in Vision analysis.
extension CGImagePropertyOrientation {
  init(_ uiImageOrientation: UIImage.Orientation) {
    switch uiImageOrientation {
    case .up: self = .up
    case .down: self = .down
    case .left: self = .left
    case .right: self = .right
    case .upMirrored: self = .upMirrored
    case .downMirrored: self = .downMirrored
    case .leftMirrored: self = .leftMirrored
    case .rightMirrored: self = .rightMirrored
    }
  }
}
