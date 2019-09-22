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

    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageJointView: DrawingJointView!
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var jointView: DrawingJointView!
    var capturedJointView: DrawingJointView!
    var capturedPoints: [CapturedPoint?] = []
    var capturedPointsModel: [CapturedPoint?] = []
    
    var videoCapture: VideoCapture!

    typealias EstimationModel = model_cpm

    var request: VNCoreMLRequest?
    var requestModel: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?

    var postProcessor: HeatmapPostProcessor = HeatmapPostProcessor()
    var mvfilters: [MovingAverageFilter] = []

    var postProcessorModel: HeatmapPostProcessor = HeatmapPostProcessor()
    var mvfiltersModel: [MovingAverageFilter] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpCapturedJointView()

        // お手本の画像を読み込む
        let image = UIImage(named: "pose01")
        imageView.image = image

        // お手本画像
        visionModel = try? VNCoreMLModel(for: EstimationModel().model)
        requestModel = VNCoreMLRequest(model: visionModel!, completionHandler: visionRequestDidCompleteForImage)
        requestModel!.imageCropAndScaleOption = .scaleFill
        // お手本の画像からポーズを取得
        predictUsingVisionForImage(uiImage: image!)
        // モデルロード
        setUpModel()
        // カメラセットアップ
        setUpCamera()
    }

    @IBAction func unwindToRootViewController(segue: UIStoryboardSegue) {
        print("unwind")
    }
 
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stop()
    }

    // MARK: - Setup Captured Joint View
    func setUpCapturedJointView() {
//        imageJointView = jointView

        capturedPointsModel = capturedPoints
        imageJointView.bodyPoints = capturedPoints.map { capturedPoint in
            if let capturedPoint = capturedPoint { return PredictedPoint(capturedPoint: capturedPoint) }
            else { return nil }
        }
    }
    
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
//    func tapCapture() {
//        let predictedPoints = jointView.bodyPoints
//        imageJointView.bodyPoints = predictedPoints
//        let capturedPoints: [CapturedPoint?] = predictedPoints.map { predictedPoint in
//            guard let predictedPoint = predictedPoint else { return nil }
//            return CapturedPoint(predictedPoint: predictedPoint)
//        }
//        self.capturedPoints = capturedPoints
//    }
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
    
    func predictUsingVisionForImage(uiImage: UIImage) {
        guard let requestModel = requestModel, let cgImage = uiImage.cgImage else { fatalError() }
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: uiImage.convertImageOrientation())
        try? handler.perform([requestModel])
    }

    func visionRequestDidCompleteForImage(request: VNRequest, error: Error?) {
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue {
            var predictedPoints = postProcessorModel.convertToPredictedPoints(from: heatmaps)

            /* --------------------- moving average filter ----------------------- */
            if predictedPoints.count != mvfiltersModel.count {
                mvfiltersModel = predictedPoints.map { _ in MovingAverageFilter(limit: 3) }
            }
            for (predictedPoint, filter) in zip(predictedPoints, mvfiltersModel) {
                filter.add(element: predictedPoint)
            }
            predictedPoints = mvfiltersModel.map { $0.averagedValue() }
            /* =================================================================== */
            
            imageJointView.bodyPoints = predictedPoints
        }
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
        
        let matchingRatio = capturedPointsModel.matchVector(with: predictedPoints)
        print(matchingRatio)
        /* =================================================================== */
        /* ======================= display the results ======================= */
        DispatchQueue.main.sync { [weak self] in
            guard let self = self else { return }
            // draw line
            self.jointView.bodyPoints = predictedPoints
            resultLabel.text = String(format: "%.2f%", matchingRatio*100)
        }
        /* =================================================================== */
    }
}

extension UIImage {
    func convertImageOrientation() -> CGImagePropertyOrientation {
        let cgiOrientations : [ CGImagePropertyOrientation ] = [
            .up, .down, .left, .right, .upMirrored, .downMirrored, .leftMirrored, .rightMirrored
        ]
        return cgiOrientations[imageOrientation.rawValue]
    }
}
