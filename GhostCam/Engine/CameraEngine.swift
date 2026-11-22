import Foundation
import AVFoundation
import CoreImage
import Photos
import UIKit
import Combine
import ImageIO

public enum LensType: String, CaseIterable, Identifiable {
    case ultraWide = "0.5x"
    case wide = "1x"
    
    public var id: String { rawValue }
    
    public var focalLengthEquivalent: String {
        switch self {
        case .ultraWide: return "13mm f/2.4"
        case .wide: return "26mm f/1.6"
        }
    }
    
    public var aperture: Float {
        switch self {
        case .ultraWide: return 2.4
        case .wide: return 1.6
        }
    }
}

public enum CaptureFormat: String, CaseIterable, Identifiable {
    case heif = "HEIF"
    case jpeg = "JPEG"
    case rawDNG = "RAW (DNG)"
    
    public var id: String { rawValue }
}

public enum ManualControlMode: String, CaseIterable, Identifiable {
    case auto = "AUTO"
    case ev = "EV"
    case iso = "ISO"
    case shutter = "SHUTTER"
    case focus = "FOCUS"
    case wb = "WB"
    
    public var id: String { rawValue }
}

public struct CapturedPhotoMetadata: Identifiable {
    public let id = UUID()
    public let width: Int
    public let height: Int
    public let megapixelCount: Double
    public let iso: Float
    public let shutterSpeed: Double
    public let aperture: Float
    public let lens: LensType
    public let format: CaptureFormat
    public let filmLook: FilmLook
    public let superResMode: SuperResMode
    public let captureDate: Date
    public let savedAssetId: String?
}

public final class CameraEngine: NSObject, ObservableObject {
    public static let shared = CameraEngine()
    
    // MARK: - Published State for SwiftUI HUD
    @Published public var isSessionRunning: Bool = false
    @Published public var isConfigured: Bool = false
    @Published public var permissionGranted: Bool = false
    
    // Telemetry Readouts
    @Published public var currentISO: Float = 100.0
    @Published public var currentShutterSpeed: Double = 0.01 // 1/100s
    @Published public var currentLensPosition: Float = 0.5
    @Published public var currentEV: Float = 0.0
    @Published public var currentWhiteBalanceTemp: Float = 5200.0
    @Published public var currentWhiteBalanceTint: Float = 0.0
    @Published public var currentAperture: Float = 1.6
    
    // Manual Hardware Overrides
    @Published public var activeManualMode: ManualControlMode = .auto
    @Published public var isManualISO: Bool = false
    @Published public var isManualShutter: Bool = false
    @Published public var isManualFocus: Bool = false
    @Published public var isManualWB: Bool = false
    @Published public var isManualEV: Bool = false
    
    // Hardware Ranges
    @Published public var minISO: Float = 50.0
    @Published public var maxISO: Float = 3200.0
    @Published public var minShutterSpeed: Double = 1.0 / 8000.0
    @Published public var maxShutterSpeed: Double = 1.0
    @Published public var minEV: Float = -3.0
    @Published public var maxEV: Float = 3.0
    
    // Modes and Selections
    @Published public var activeLens: LensType = .wide
    @Published public var captureFormat: CaptureFormat = .heif
    @Published public var superResMode: SuperResMode = .off
    @Published public var selectedFilmLook: FilmLook = .natural
    @Published public var flashMode: AVCaptureDevice.FlashMode = .off
    @Published public var torchMode: AVCaptureDevice.TorchMode = .off
    @Published public var showGrid: Bool = true
    @Published public var showHorizonLevel: Bool = true
    
    // Burst and Processing State
    @Published public var isBurstCapturing: Bool = false
    @Published public var processingProgress: Double = 0.0
    @Published public var processingStatus: String = ""
    
    // Last Capture Quick Inspect
    @Published public var lastCapturedThumbnail: UIImage?
    @Published public var lastCapturedMetadata: CapturedPhotoMetadata?
    
    // Tap to focus state
    @Published public var focusPointOfInterest: CGPoint?
    @Published public var showFocusReticle: Bool = false
    
    // MARK: - AVFoundation Internals
    public let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.ghostcam.sessionQueue", qos: .userInitiated)
    private let videoOutputQueue = DispatchQueue(label: "com.ghostcam.videoOutputQueue", qos: .userInteractive)
    
    private var videoInput: AVCaptureDeviceInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    
    private var wideDevice: AVCaptureDevice?
    private var ultraWideDevice: AVCaptureDevice?
    private var activeDevice: AVCaptureDevice?
    
    // Burst Accumulator
    private var burstExpectedCount: Int = 0
    private var burstCapturedFrames: [CIImage] = []
    private var burstLock = NSLock()
    
    private var telemetryTimer: AnyCancellable?
    
    override init() {
        super.init()
        discoverHardwareDevices()
    }
    
    // MARK: - Hardware Device Discovery
    
    private func discoverHardwareDevices() {
        // iPhone 12 Dual-Camera System
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .builtInUltraWideCamera
            ],
            mediaType: .video,
            position: .back
        )
        
        for device in discovery.devices {
            switch device.deviceType {
            case .builtInWideAngleCamera:
                self.wideDevice = device
            case .builtInUltraWideCamera:
                self.ultraWideDevice = device
            default:
                break
            }
        }
        
        // Fallback for simulator or other devices
        if wideDevice == nil {
            wideDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video)
        }
        
        self.activeDevice = wideDevice
        updateHardwareRanges()
    }
    
    private func updateHardwareRanges() {
        guard let device = activeDevice else { return }
        
        let format = device.activeFormat
        self.minISO = format.minISO
        self.maxISO = format.maxISO
        self.minShutterSpeed = CMTimeGetSeconds(format.minExposureDuration)
        self.maxShutterSpeed = min(1.0, CMTimeGetSeconds(format.maxExposureDuration))
        self.minEV = device.minExposureTargetBias
        self.maxEV = device.maxExposureTargetBias
        self.currentAperture = activeLens.aperture
    }
    
    // MARK: - Session Setup & Lifecycle
    
    public func startSession() {
        checkPermissions { [weak self] granted in
            guard let self = self, granted else { return }
            self.sessionQueue.async {
                self.configureSession()
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = self.captureSession.isRunning
                    self.startTelemetryMonitor()
                }
            }
        }
    }
    
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
                self.stopTelemetryMonitor()
            }
        }
    }
    
    private func checkPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.permissionGranted = true
                completion(true)
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.permissionGranted = granted
                    completion(granted)
                }
            }
        default:
            DispatchQueue.main.async {
                self.permissionGranted = false
                completion(false)
            }
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        guard let device = activeDevice else {
            captureSession.commitConfiguration()
            return
        }
        
        // Remove existing inputs
        if let currentInput = videoInput {
            captureSession.removeInput(currentInput)
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                self.videoInput = input
            }
        } catch {
            print("[GhostCam CameraEngine] Failed to create device input: \(error.localizedDescription)")
        }
        
        // Video Data Output for 60fps Metal preview
        if !captureSession.outputs.contains(videoDataOutput) {
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
            if captureSession.canAddOutput(videoDataOutput) {
                captureSession.addOutput(videoDataOutput)
            }
        }
        
        // High-Resolution Photo Output
        if !captureSession.outputs.contains(photoOutput) {
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }
        }
        
        captureSession.commitConfiguration()
        
        DispatchQueue.main.async {
            self.isConfigured = true
            self.updateHardwareRanges()
        }
    }
    
    // MARK: - Lens Switching (0.5x Ultra-Wide & 1x Wide)
    
    public func switchLens(to lens: LensType) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let targetDevice: AVCaptureDevice?
            switch lens {
            case .ultraWide:
                targetDevice = self.ultraWideDevice ?? self.wideDevice
            case .wide:
                targetDevice = self.wideDevice
            }
            
            guard let device = targetDevice, device != self.activeDevice else { return }
            
            self.captureSession.beginConfiguration()
            
            if let currentInput = self.videoInput {
                self.captureSession.removeInput(currentInput)
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.videoInput = newInput
                    self.activeDevice = device
                }
            } catch {
                print("[GhostCam CameraEngine] Lens switch failed: \(error.localizedDescription)")
            }
            
            self.captureSession.commitConfiguration()
            
            DispatchQueue.main.async {
                self.activeLens = lens
                self.updateHardwareRanges()
                // Reset manual locks when switching physical sensor
                self.resetAllToAuto()
            }
        }
    }
    
    // MARK: - Real-Time Manual Pro Controls
    
    /// Set ISO manually (ISO slider)
    public func setManualISO(_ iso: Float) {
        guard let device = activeDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                let clampedISO = min(max(iso, device.activeFormat.minISO), device.activeFormat.maxISO)
                let currentDuration = device.exposureDuration
                
                device.setExposureModeCustom(duration: currentDuration, iso: clampedISO, completionHandler: nil)
                
                DispatchQueue.main.async {
                    self.isManualISO = true
                    self.currentISO = clampedISO
                }
            } catch {
                print("[GhostCam CameraEngine] ISO lock error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Set Shutter Speed manually (Exposure Duration slider)
    public func setManualShutterSpeed(_ seconds: Double) {
        guard let device = activeDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                let minSec = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
                let maxSec = CMTimeGetSeconds(device.activeFormat.maxExposureDuration)
                let clampedSec = min(max(seconds, minSec), maxSec)
                let clampedDuration = CMTimeMakeWithSeconds(clampedSec, preferredTimescale: 1_000_000)
                let currentISO = device.iso
                
                device.setExposureModeCustom(duration: clampedDuration, iso: currentISO, completionHandler: nil)
                
                DispatchQueue.main.async {
                    self.isManualShutter = true
                    self.currentShutterSpeed = clampedSec
                }
            } catch {
                print("[GhostCam CameraEngine] Shutter lock error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Set Manual Focus (Lens Position 0.0 - 1.0)
    public func setManualFocus(lensPosition: Float) {
        guard let device = activeDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                let clampedPos = min(max(lensPosition, 0.0), 1.0)
                device.setFocusModeLocked(lensPosition: clampedPos, completionHandler: nil)
                
                DispatchQueue.main.async {
                    self.isManualFocus = true
                    self.currentLensPosition = clampedPos
                }
            } catch {
                print("[GhostCam CameraEngine] Focus lock error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Set Exposure Bias (EV)
    public func setExposureBias(_ bias: Float) {
        guard let device = activeDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                let clampedBias = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
                device.setExposureTargetBias(clampedBias, completionHandler: nil)
                
                DispatchQueue.main.async {
                    self.isManualEV = (bias != 0.0)
                    self.currentEV = clampedBias
                }
            } catch {
                print("[GhostCam CameraEngine] EV error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Set Manual White Balance (Temperature in Kelvin: 2500K - 9000K, Tint: -150 to +150)
    public func setManualWhiteBalance(temperature: Float, tint: Float) {
        guard let device = activeDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                let tempAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                    temperature: temperature,
                    tint: tint
                )
                var gains = device.deviceWhiteBalanceGains(for: tempAndTint)
                
                // Vital: Gains must be clamped to [1.0, maxWhiteBalanceGain] to prevent Obj-C exceptions
                let maxGain = device.maxWhiteBalanceGain
                gains.redGain = min(max(gains.redGain, 1.0), maxGain)
                gains.greenGain = min(max(gains.greenGain, 1.0), maxGain)
                gains.blueGain = min(max(gains.blueGain, 1.0), maxGain)
                
                device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
                
                DispatchQueue.main.async {
                    self.isManualWB = true
                    self.currentWhiteBalanceTemp = temperature
                    self.currentWhiteBalanceTint = tint
                }
            } catch {
                print("[GhostCam CameraEngine] White Balance lock error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Auto Reset Toggles
    
    public func resetExposureToAuto() {
        guard let device = activeDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.setExposureTargetBias(0.0, completionHandler: nil)
                
                DispatchQueue.main.async {
                    self.isManualISO = false
                    self.isManualShutter = false
                    self.isManualEV = false
                    self.currentEV = 0.0
                }
            } catch {
                print("[GhostCam CameraEngine] Reset exposure error: \(error.localizedDescription)")
            }
        }
    }
    
    public func resetFocusToAuto() {
        guard let device = activeDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                
                DispatchQueue.main.async {
                    self.isManualFocus = false
                }
            } catch {
                print("[GhostCam CameraEngine] Reset focus error: \(error.localizedDescription)")
            }
        }
    }
    
    public func resetWhiteBalanceToAuto() {
        guard let device = activeDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                
                DispatchQueue.main.async {
                    self.isManualWB = false
                }
            } catch {
                print("[GhostCam CameraEngine] Reset WB error: \(error.localizedDescription)")
            }
        }
    }
    
    public func resetAllToAuto() {
        resetExposureToAuto()
        resetFocusToAuto()
        resetWhiteBalanceToAuto()
    }
    
    // MARK: - Tap To Focus & Expose
    
    public func setFocusAndExposurePoint(at viewPoint: CGPoint, viewSize: CGSize) {
        guard let device = activeDevice, viewSize.width > 0, viewSize.height > 0 else { return }
        
        let focusPoint = CGPoint(
            x: viewPoint.y / viewSize.height,
            y: 1.0 - (viewPoint.x / viewSize.width)
        )
        
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = .continuousAutoExposure
                }
                
                DispatchQueue.main.async {
                    self.focusPointOfInterest = viewPoint
                    self.showFocusReticle = true
                    self.isManualFocus = false
                    
                    // Auto-hide reticle after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.showFocusReticle = false
                    }
                }
            } catch {
                print("[GhostCam CameraEngine] Focus point error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Telemetry Polling Monitor
    
    private func startTelemetryMonitor() {
        telemetryTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollHardwareTelemetry()
            }
    }
    
    private func stopTelemetryMonitor() {
        telemetryTimer?.cancel()
        telemetryTimer = nil
    }
    
    private func pollHardwareTelemetry() {
        guard let device = activeDevice else { return }
        
        if !isManualISO {
            self.currentISO = device.iso
        }
        if !isManualShutter {
            self.currentShutterSpeed = CMTimeGetSeconds(device.exposureDuration)
        }
        if !isManualFocus {
            self.currentLensPosition = device.lensPosition
        }
        if !isManualWB {
            let gains = device.deviceWhiteBalanceGains
            let tempAndTint = device.temperatureAndTintValues(for: gains)
            self.currentWhiteBalanceTemp = tempAndTint.temperature
            self.currentWhiteBalanceTint = tempAndTint.tint
        }
        self.currentEV = device.exposureTargetBias
    }
    
    // MARK: - Capture Execution
    
    public func capturePhoto() {
        if superResMode != .off {
            captureSuperResBurst()
        } else {
            captureSinglePhoto()
        }
    }
    
    private func captureSinglePhoto() {
        var photoSettings: AVCapturePhotoSettings
        
        // Handle RAW capture vs HEIF/JPEG
        if captureFormat == .rawDNG {
            if let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first {
                let processedFormat: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.jpeg.rawValue
                ]
                photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat, processedFormat: processedFormat)
            } else {
                photoSettings = AVCapturePhotoSettings()
            }
        } else if captureFormat == .heif && photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc.rawValue])
        } else {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg.rawValue])
        }
        
        if activeDevice?.hasFlash == true && flashMode != .off {
            photoSettings.flashMode = flashMode
        }
        
        photoSettings.isHighResolutionPhotoEnabled = true
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    private func captureSuperResBurst() {
        guard !isBurstCapturing else { return }
        
        burstLock.lock()
        burstCapturedFrames.removeAll()
        burstExpectedCount = superResMode.frameBurstCount
        burstLock.unlock()
        
        DispatchQueue.main.async {
            self.isBurstCapturing = true
            self.processingProgress = 0.05
            self.processingStatus = "Capturing \(self.superResMode.frameBurstCount) Rapid Burst Frames..."
        }
        
        // Trigger rapid burst sequence
        captureNextBurstFrame()
    }
    
    private func captureNextBurstFrame() {
        burstLock.lock()
        let count = burstCapturedFrames.count
        burstLock.unlock()
        
        if count >= burstExpectedCount {
            processCompletedBurst()
            return
        }
        
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        settings.isHighResolutionPhotoEnabled = true
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func processCompletedBurst() {
        burstLock.lock()
        let frames = self.burstCapturedFrames
        burstLock.unlock()
        
        SuperResEngine.shared.processBurst(
            frames: frames,
            mode: superResMode,
            filmLook: selectedFilmLook,
            progressHandler: { [weak self] progress, status in
                self?.processingProgress = progress
                self?.processingStatus = status
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                self.isBurstCapturing = false
                self.processingProgress = 0.0
                self.processingStatus = ""
                
                switch result {
                case .success(let superResResult):
                    self.lastCapturedThumbnail = superResResult.thumbnail
                    self.lastCapturedMetadata = CapturedPhotoMetadata(
                        width: superResResult.width,
                        height: superResResult.height,
                        megapixelCount: superResResult.megapixelCount,
                        iso: self.currentISO,
                        shutterSpeed: self.currentShutterSpeed,
                        aperture: self.currentAperture,
                        lens: self.activeLens,
                        format: self.captureFormat,
                        filmLook: self.selectedFilmLook,
                        superResMode: self.superResMode,
                        captureDate: Date(),
                        savedAssetId: superResResult.savedAssetId
                    )
                case .failure(let error):
                    print("[GhostCam CameraEngine] SuperRes processing error: \(error.localizedDescription)")
                }
            }
        )
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (60fps GPU Preview)

extension CameraEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        MetalPreviewRenderer.shared.updatePixelBuffer(pixelBuffer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraEngine: AVCapturePhotoCaptureDelegate {
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            print("[GhostCam CameraEngine] Photo capture error: \(error.localizedDescription)")
            return
        }
        
        guard let photoData = photo.fileDataRepresentation() else { return }
        
        // Burst Mode Accumulation for Super-Resolution
        if isBurstCapturing {
            if let ciImage = CIImage(data: photoData) {
                burstLock.lock()
                burstCapturedFrames.append(ciImage)
                let currentCount = burstCapturedFrames.count
                burstLock.unlock()
                
                DispatchQueue.main.async {
                    self.processingProgress = 0.05 + 0.10 * (Double(currentCount) / Double(self.burstExpectedCount))
                }
                
                // Immediately queue next burst frame with zero shutter lag
                if currentCount < burstExpectedCount {
                    self.captureNextBurstFrame()
                } else {
                    self.processCompletedBurst()
                }
            }
            return
        }
        
        // Single Photo Processing
        processSingleCapturedPhoto(photoData: photoData, photo: photo)
    }
    
    private func processSingleCapturedPhoto(photoData: Data, photo: AVCapturePhoto) {
        guard var ciImage = CIImage(data: photoData) else { return }
        
        // Apply Film Look if not RAW
        if captureFormat != .rawDNG {
            ciImage = FilmSimulationEngine.shared.apply(
                filter: selectedFilmLook,
                to: ciImage,
                addDateStamp: (selectedFilmLook == .digicam90s)
            )
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ciContext = CIContext(options: [.cacheIntermediates: false])
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GhostCam_Photo_\(UUID().uuidString).jpg")
        
        do {
            try ciContext.writeJPEGRepresentation(
                of: ciImage,
                to: tempURL,
                colorSpace: colorSpace,
                options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.95]
            )
            
            // Save to Photos
            var assetId: String?
            let semaphore = DispatchSemaphore(value: 0)
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)
                assetId = request?.placeholderForCreatedAsset?.localIdentifier
            }, completionHandler: { _, _ in
                semaphore.signal()
            })
            semaphore.wait()
            
            try? FileManager.default.removeItem(at: tempURL)
            
            // Update UI
            let extent = ciImage.extent
            let thumbImage = UIImage(data: photoData) ?? UIImage()
            
            DispatchQueue.main.async {
                self.lastCapturedThumbnail = thumbImage
                self.lastCapturedMetadata = CapturedPhotoMetadata(
                    width: Int(extent.width),
                    height: Int(extent.height),
                    megapixelCount: (extent.width * extent.height) / 1_000_000.0,
                    iso: self.currentISO,
                    shutterSpeed: self.currentShutterSpeed,
                    aperture: self.currentAperture,
                    lens: self.activeLens,
                    format: self.captureFormat,
                    filmLook: self.selectedFilmLook,
                    superResMode: .off,
                    captureDate: Date(),
                    savedAssetId: assetId
                )
            }
        } catch {
            print("[GhostCam CameraEngine] Failed to save single capture: \(error.localizedDescription)")
        }
    }
}
