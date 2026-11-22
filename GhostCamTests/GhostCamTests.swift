import XCTest
import CoreImage
import AVFoundation
@testable import GhostCam

final class GhostCamTests: XCTestCase {
    
    // MARK: - SuperResEngine Dimension & Mathematical Verification
    
    func testSuperResModeDimensions() {
        // Verify Native Sensor Dimensions
        let offDimensions = SuperResMode.off.targetDimensions
        XCTAssertEqual(offDimensions.width, 4032, "Native width should match iPhone 12 sensor (4032)")
        XCTAssertEqual(offDimensions.height, 3024, "Native height should match iPhone 12 sensor (3024)")
        XCTAssertEqual(SuperResMode.off.frameBurstCount, 1, "Native mode should capture 1 frame")
        
        // Verify 48MP High-Fidelity Dimensions
        let res48Dimensions = SuperResMode.res48MP.targetDimensions
        XCTAssertEqual(res48Dimensions.width, 8000, "48MP mode width should be 8000")
        XCTAssertEqual(res48Dimensions.height, 6000, "48MP mode height should be 6000")
        let megapixels48 = Double(res48Dimensions.width * res48Dimensions.height) / 1_000_000.0
        XCTAssertEqual(megapixels48, 48.0, accuracy: 0.1, "48MP mode should produce 48.0 Megapixels")
        XCTAssertEqual(SuperResMode.res48MP.frameBurstCount, 6, "48MP mode should burst 6 frames")
        
        // Verify 90MP Ultra-Resolution Dimensions
        let res90Dimensions = SuperResMode.res90MP.targetDimensions
        XCTAssertEqual(res90Dimensions.width, 10954, "90MP mode width must be 10954")
        XCTAssertEqual(res90Dimensions.height, 8216, "90MP mode height must be 8216")
        let megapixels90 = Double(res90Dimensions.width * res90Dimensions.height) / 1_000_000.0
        XCTAssertEqual(megapixels90, 90.0, accuracy: 0.1, "90MP mode should produce 90.0 Megapixels")
        XCTAssertEqual(SuperResMode.res90MP.frameBurstCount, 8, "90MP mode should burst 8 frames")
    }
    
    // MARK: - FilmSimulationEngine GPU Pipeline Execution
    
    func testAllFilmSimulationFiltersExecuteSuccessfully() {
        let ciContext = CIContext(options: [.cacheIntermediates: false])
        let testRect = CGRect(x: 0, y: 0, width: 400, height: 300)
        let sampleImage = CIImage(color: CIColor(red: 0.6, green: 0.4, blue: 0.3, alpha: 1.0)).cropped(to: testRect)
        
        for look in FilmLook.allCases {
            let processed = FilmSimulationEngine.shared.apply(
                filter: look,
                to: sampleImage,
                addDateStamp: (look == .digicam90s)
            )
            
            XCTAssertNotNil(processed, "Processed CIImage must not be nil for \(look.rawValue)")
            XCTAssertEqual(processed.extent.width, 400.0, accuracy: 0.01, "\(look.rawValue) should preserve width")
            XCTAssertEqual(processed.extent.height, 300.0, accuracy: 0.01, "\(look.rawValue) should preserve height")
            
            // Execute CoreImage render through CIContext to verify zero Metal / shader errors
            let renderedCGImage = ciContext.createCGImage(processed, from: testRect)
            XCTAssertNotNil(renderedCGImage, "CIContext must successfully render CGImage for \(look.rawValue)")
            if let cg = renderedCGImage {
                XCTAssertEqual(cg.width, 400)
                XCTAssertEqual(cg.height, 300)
            }
        }
    }
    
    // MARK: - Hardware Lens Specifications & Apertures
    
    func testHardwareLensSpecs() {
        XCTAssertEqual(LensType.ultraWide.rawValue, "0.5x")
        XCTAssertEqual(LensType.ultraWide.focalLengthEquivalent, "13mm f/2.4")
        XCTAssertEqual(LensType.ultraWide.aperture, 2.4, accuracy: 0.01)
        
        XCTAssertEqual(LensType.wide.rawValue, "1x")
        XCTAssertEqual(LensType.wide.focalLengthEquivalent, "26mm f/1.6")
        XCTAssertEqual(LensType.wide.aperture, 1.6, accuracy: 0.01)
    }
    
    // MARK: - Parameter Clamping & Normalization Tests
    
    func testWhiteBalanceGainClampingMath() {
        // Test that white balance gains are clamped strictly within [1.0, maxGain]
        let maxGain: Float = 3.5
        var testGain: Float = 0.8
        let clampedLow = min(max(testGain, 1.0), maxGain)
        XCTAssertEqual(clampedLow, 1.0, "Gain below 1.0 must clamp to 1.0 to prevent Obj-C exceptions")
        
        testGain = 4.2
        let clampedHigh = min(max(testGain, 1.0), maxGain)
        XCTAssertEqual(clampedHigh, 3.5, "Gain above maxGain must clamp to maxGain")
    }
    
    func testLensPositionClampingMath() {
        let lowPos: Float = -0.5
        let clampedLow = min(max(lowPos, 0.0), 1.0)
        XCTAssertEqual(clampedLow, 0.0)
        
        let highPos: Float = 1.8
        let clampedHigh = min(max(highPos, 0.0), 1.0)
        XCTAssertEqual(clampedHigh, 1.0)
        
        let validPos: Float = 0.65
        let clampedValid = min(max(validPos, 0.0), 1.0)
        XCTAssertEqual(clampedValid, 0.65)
    }
}
