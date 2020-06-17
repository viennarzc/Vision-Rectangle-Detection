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

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

  private var requests = [VNRequest]()
  private var lastObservation: VNRectangleObservation?
  private var sequenceHandler = VNSequenceRequestHandler()
  private var maskLayer: CAShapeLayer = CAShapeLayer()

  private let session = AVCaptureSession()
  private var previewLayer: AVCaptureVideoPreviewLayer!
  private let queue = DispatchQueue(label: "com.vision.videoqueue")
  
//  private var maskLayer = CAShapeLayer()

  @IBOutlet weak var captureView: UIView!

  override func viewDidLoad() {
    super.viewDidLoad()

    //Vision rectangle detection request setup
//    self.setupVision()

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

      let input = try AVCaptureDeviceInput(device: AVCaptureDevice.default(for: .video)!)

      let output = AVCaptureVideoDataOutput()
      output.setSampleBufferDelegate(self, queue: queue)
      output.alwaysDiscardsLateVideoFrames = true
      output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

      session.addInput(input)
      session.addOutput(output)
    } catch {
      print(error)
    }
  }

  func startVideoCapture() {
    if session.isRunning {
      print("session already exists")
      return
    }
    session.startRunning()
  }

  //MARK: Vision Setup

  

  //MARK: Vision Completion Handlers

  func handleRectangles(request: VNRequest, error: Error?) {
    
  }

}

