//
//  PoseEstimationViewController.swift
//  PosingAlarmClock
//
//  Created by 甲斐翔也 on 2019/09/22.
//  Copyright © 2019 甲斐翔也. All rights reserved.
//

import UIKit
import CoreMedia
import Vision

class PoseEstimationViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var jointView: DrawingJointView!
    var capturedJointView: DrawingJointView!
    var capturedPoints: [CapturedPoint?] = []
    
    var videoCapture: VideoCapture!

    typealias EstimationModel = model_cpm

    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?

    var postProcessor: HeatmapPostProcessor = HeatmapPostProcessor()
    var mvfilters: [MovingAverageFilter] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = UIImage(named: "pose01")

        setUpModel()

        setUpCamera()
    }

    @IBAction func unwindToRootViewController(segue: UIStoryboardSegue) {
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stop()
    }

//    // MARK: - Setup Captured Joint View
//    func setUpCapturedJointView() {
//        for capturedJointView in capturedJointViews {
//            capturedJointView.layer.borderWidth = 2
//            capturedJointView.layer.borderColor = UIColor.gray.cgColor
//        }
//
//        capturedPointsArray = capturedJointViews.map { _ in return nil }
//
//        for currentIndex in 0..<capturedPointsArray.count {
//            // retrieving a value for a key
//            if let data = UserDefaults.standard.data(forKey: "points-\(currentIndex)"),
//                let capturedPoints = NSKeyedUnarchiver.unarchiveObject(with: data) as? [CapturedPoint?] {
//                capturedPointsArray[currentIndex] = capturedPoints
//                capturedJointViews[currentIndex].bodyPoints = capturedPoints.map { capturedPoint in
//                    if let capturedPoint = capturedPoint { return PredictedPoint(capturedPoint: capturedPoint) }
//                    else { return nil }
//                }
//            }
//        }
//    }
    
    // MARK: - Setup Core ML
    func setUpModel() {
        if let visionModel = try? VNCoreMLModel(for: EstimationModel().model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .centerCrop
        } else {
            fatalError("cannot load the ml model")
        }
    }
    
    // MARK: - SetUp Video
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480, cameraPosition: .back) { success in
//        videoCapture.setUp(sessionPreset: .vga640x480, cameraPosition: .front) { success in
            
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                // start video preview when setup is done
                self.videoCapture.start()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    
    // CAPTURE THE CURRENT POSE
    @IBAction func tapCapture(_ sender: Any) {
//        let currentIndex = capturedIndex % capturedJointViews.count
        let currentIndex = 0
        
        let predictedPoints = jointView.bodyPoints
        capturedJointView.bodyPoints = predictedPoints
        let capturedPoints: [CapturedPoint?] = predictedPoints.map { predictedPoint in
            guard let predictedPoint = predictedPoint else { return nil }
            return CapturedPoint(predictedPoint: predictedPoint)
        }
        self.capturedPoints = capturedPoints
        
        let encodedData = NSKeyedArchiver.archivedData(withRootObject: capturedPoints)
        UserDefaults.standard.set(encodedData, forKey: "points-\(currentIndex)")
        print(UserDefaults.standard.synchronize())
    }
}

// MARK: - VideoCaptureDelegate
extension PoseEstimationViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        // the captured image from camera is contained on pixelBuffer
        if let pixelBuffer = pixelBuffer {
            predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
}

extension PoseEstimationViewController {
    // MARK: - Inferencing
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }
        // vision framework configures the input size of image following our model's input configuration automatically
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    
    // MARK: - Postprocessing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue else { return }
        
        /* =================================================================== */
        /* ========================= post-processing ========================= */
        
        /* ------------------ convert heatmap to point array ----------------- */
//        var predictedPoints = postProcessor.convertToPredictedPoints(from: heatmaps, isFlipped: true)
        var predictedPoints = postProcessor.convertToPredictedPoints(from: heatmaps)
        
        /* --------------------- moving average filter ----------------------- */
        if predictedPoints.count != mvfilters.count {
            mvfilters = predictedPoints.map { _ in MovingAverageFilter(limit: 3) }
        }
        for (predictedPoint, filter) in zip(predictedPoints, mvfilters) {
            filter.add(element: predictedPoint)
        }
        predictedPoints = mvfilters.map { $0.averagedValue() }
        /* =================================================================== */
        
        let matchingRatios = capturedPoints.matchVector(with: predictedPoints)
        
        /* =================================================================== */
        /* ======================= display the results ======================= */
        DispatchQueue.main.sync { [weak self] in
            guard let self = self else { return }
            // draw line
            self.jointView.bodyPoints = predictedPoints
            
//            var topCapturedJointBGView: UIView?
//            var maxMatchingRatio: CGFloat = 0
//            for (matchingRatio, (capturedJointBGView, capturedJointConfidenceLabel)) in zip(matchingRatios, zip(self.capturedJointBGViews, self.capturedJointConfidenceLabels)) {
//                let text = String(format: "%.2f%", matchingRatio*100)
//                capturedJointConfidenceLabel.text = text
//                capturedJointBGView.backgroundColor = .clear
//                if matchingRatio > 0.80 && maxMatchingRatio < matchingRatio {
//                    maxMatchingRatio = matchingRatio
//                    topCapturedJointBGView = capturedJointBGView
//                }
//            }
//            topCapturedJointBGView?.backgroundColor = UIColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 0.4)
        }
        /* =================================================================== */
    }
}
