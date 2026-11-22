import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

public enum FilmLook: String, CaseIterable, Identifiable {
    case natural = "Natural"
    case cinema2383 = "Cinema 2383"
    case portra400 = "Portra 400"
    case digicam90s = "90s Digicam"
    case noir35mm = "Noir 35mm"
    
    public var id: String { rawValue }
    
    public var subtitle: String {
        switch self {
        case .natural: return "True Color • Clean"
        case .cinema2383: return "Teal & Orange • Print Stock"
        case .portra400: return "Warm Pastel • Soft Roll-off"
        case .digicam90s: return "Halation • CCD Grain • Stamp"
        case .noir35mm: return "Monochrome • Silver Grain"
        }
    }
    
    public var badgeColor: (red: Double, green: Double, blue: Double) {
        switch self {
        case .natural: return (0.8, 0.8, 0.8)
        case .cinema2383: return (0.1, 0.8, 0.9)
        case .portra400: return (0.95, 0.65, 0.35)
        case .digicam90s: return (1.0, 0.45, 0.1)
        case .noir35mm: return (0.9, 0.9, 0.9)
        }
    }
}

public final class FilmSimulationEngine {
    public static let shared = FilmSimulationEngine()
    
    private let grainGenerator: CIFilter?
    
    private init() {
        self.grainGenerator = CIFilter(name: "CIRandomGenerator")
    }
    
    /// Applies the selected film simulation filter pipeline to a CIImage.
    /// - Parameters:
    ///   - filter: Selected film look
    ///   - image: Source CIImage
    ///   - addDateStamp: Whether to burn in the 90s digicam date stamp (for captured photos)
    /// - Returns: Processed CIImage
    public func apply(filter: FilmLook, to image: CIImage, addDateStamp: Bool = false) -> CIImage {
        switch filter {
        case .natural:
            return applyNatural(to: image)
        case .cinema2383:
            return applyCinema2383(to: image)
        case .portra400:
            return applyPortra400(to: image)
        case .digicam90s:
            return applyDigicam90s(to: image, addDateStamp: addDateStamp)
        case .noir35mm:
            return applyNoir35mm(to: image)
        }
    }
    
    // MARK: - 1. Natural
    private func applyNatural(to image: CIImage) -> CIImage {
        // Faithful color rendition, zero artificial sharpening, subtle dynamic range expansion
        let extent = image.extent
        guard let vibranceFilter = CIFilter(name: "CIVibrance") else { return image }
        vibranceFilter.setValue(image, forKey: kCIInputImageKey)
        vibranceFilter.setValue(0.08, forKey: "inputAmount")
        
        guard let vibranceOut = vibranceFilter.outputImage else { return image }
        
        guard let controlsFilter = CIFilter(name: "CIColorControls") else { return vibranceOut }
        controlsFilter.setValue(vibranceOut, forKey: kCIInputImageKey)
        controlsFilter.setValue(1.02, forKey: kCIInputContrastKey)
        controlsFilter.setValue(1.0, forKey: kCIInputSaturationKey)
        controlsFilter.setValue(0.0, forKey: kCIInputBrightnessKey)
        
        return controlsFilter.outputImage?.cropped(to: extent) ?? image
    }
    
    // MARK: - 2. Cinema 2383 (Teal & Orange Filmic S-Curve)
    private func applyCinema2383(to image: CIImage) -> CIImage {
        let extent = image.extent
        
        // Step 1: Tone curve for cinematic S-curve (rich shadows, smooth highlights)
        guard let toneCurve = CIFilter(name: "CIToneCurve") else { return image }
        toneCurve.setValue(image, forKey: kCIInputImageKey)
        toneCurve.setValue(CIVector(x: 0.0, y: 0.0), forKey: "inputPoint0")
        toneCurve.setValue(CIVector(x: 0.25, y: 0.18), forKey: "inputPoint1")
        toneCurve.setValue(CIVector(x: 0.5, y: 0.50), forKey: "inputPoint2")
        toneCurve.setValue(CIVector(x: 0.75, y: 0.82), forKey: "inputPoint3")
        toneCurve.setValue(CIVector(x: 1.0, y: 0.96), forKey: "inputPoint4")
        
        let curved = toneCurve.outputImage ?? image
        
        // Step 2: Color Matrix for Kodak 2383 Teal & Orange shift
        // Warm highlights (red/green boosted slightly), cyan/teal shadows (blue/green in shadows)
        guard let colorMatrix = CIFilter(name: "CIColorMatrix") else { return curved }
        colorMatrix.setValue(curved, forKey: kCIInputImageKey)
        colorMatrix.setValue(CIVector(x: 1.12, y: -0.05, z: -0.05, w: 0.0), forKey: "inputRVector")
        colorMatrix.setValue(CIVector(x: -0.02, y: 1.05, z: 0.04, w: 0.0), forKey: "inputGVector")
        colorMatrix.setValue(CIVector(x: -0.08, y: 0.05, z: 1.15, w: 0.0), forKey: "inputBVector")
        colorMatrix.setValue(CIVector(x: -0.02, y: 0.01, z: 0.04, w: 0.0), forKey: "inputBiasVector")
        
        let colorMatrixOut = colorMatrix.outputImage ?? curved
        
        // Step 3: Color controls for punchy cinematic density
        guard let controls = CIFilter(name: "CIColorControls") else { return colorMatrixOut }
        controls.setValue(colorMatrixOut, forKey: kCIInputImageKey)
        controls.setValue(1.10, forKey: kCIInputContrastKey)
        controls.setValue(1.12, forKey: kCIInputSaturationKey)
        
        return controls.outputImage?.cropped(to: extent) ?? image
    }
    
    // MARK: - 3. Portra 400 (Warm Highlights, Soft Contrast, Fine Grain)
    private func applyPortra400(to image: CIImage) -> CIImage {
        let extent = image.extent
        
        // Step 1: Soft contrast tone curve with warm lifted blacks
        guard let toneCurve = CIFilter(name: "CIToneCurve") else { return image }
        toneCurve.setValue(image, forKey: kCIInputImageKey)
        toneCurve.setValue(CIVector(x: 0.0, y: 0.04), forKey: "inputPoint0") // Lifted blacks
        toneCurve.setValue(CIVector(x: 0.25, y: 0.23), forKey: "inputPoint1")
        toneCurve.setValue(CIVector(x: 0.5, y: 0.49), forKey: "inputPoint2")
        toneCurve.setValue(CIVector(x: 0.75, y: 0.76), forKey: "inputPoint3")
        toneCurve.setValue(CIVector(x: 1.0, y: 0.98), forKey: "inputPoint4") // Soft highlight roll-off
        
        let curved = toneCurve.outputImage ?? image
        
        // Step 2: Warm color temperature shift (Kodak golden warmth)
        guard let tempFilter = CIFilter(name: "CITemperatureAndTint") else { return curved }
        tempFilter.setValue(curved, forKey: kCIInputImageKey)
        tempFilter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
        tempFilter.setValue(CIVector(x: 5800, y: 15), forKey: "inputTargetNeutral")
        
        let warmed = tempFilter.outputImage ?? curved
        
        // Step 3: Subtle grain overlay
        let grained = addFilmGrain(to: warmed, extent: extent, intensity: 0.045)
        
        return grained.cropped(to: extent)
    }
    
    // MARK: - 4. 90s Digicam / VHS (Halation, Chromatic Aberration, CCD Grain, Date Stamp)
    private func applyDigicam90s(to image: CIImage, addDateStamp: Bool) -> CIImage {
        let extent = image.extent
        
        // Step 1: Chromatic aberration (subtle horizontal displacement between R and B channels)
        let caImage = applyChromaticAberration(to: image, displacement: 1.5)
        
        // Step 2: Highlight halation (dreamy glow on bright regions)
        let halated = applyHalation(to: caImage, extent: extent, intensity: 0.22)
        
        // Step 3: CCD Color profile (punchy 90s saturation + slight warmth)
        guard let controls = CIFilter(name: "CIColorControls") else { return halated }
        controls.setValue(halated, forKey: kCIInputImageKey)
        controls.setValue(1.15, forKey: kCIInputSaturationKey)
        controls.setValue(1.08, forKey: kCIInputContrastKey)
        controls.setValue(-0.01, forKey: kCIInputBrightnessKey)
        
        let ccdLook = controls.outputImage ?? halated
        
        // Step 4: Authentic CCD sensor grain
        let grained = addFilmGrain(to: ccdLook, extent: extent, intensity: 0.065)
        
        // Step 5: Optional 90s retro date stamp overlay on captured photos
        if addDateStamp {
            return applyRetroDateStamp(to: grained, extent: extent)
        }
        
        return grained.cropped(to: extent)
    }
    
    // MARK: - 5. Noir 35mm (High-Contrast B&W with Organic Silver Halide Grain)
    private func applyNoir35mm(to image: CIImage) -> CIImage {
        let extent = image.extent
        
        // Step 1: Panchromatic Black & White conversion with enhanced red sensitivity
        guard let matrix = CIFilter(name: "CIColorMatrix") else { return image }
        matrix.setValue(image, forKey: kCIInputImageKey)
        // Kodak Tri-X 400 panchromatic spectral weighting:
        let rWeight: CGFloat = 0.45
        let gWeight: CGFloat = 0.40
        let bWeight: CGFloat = 0.15
        matrix.setValue(CIVector(x: rWeight, y: gWeight, z: bWeight, w: 0.0), forKey: "inputRVector")
        matrix.setValue(CIVector(x: rWeight, y: gWeight, z: bWeight, w: 0.0), forKey: "inputGVector")
        matrix.setValue(CIVector(x: rWeight, y: gWeight, z: bWeight, w: 0.0), forKey: "inputBVector")
        matrix.setValue(CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0), forKey: "inputAVector")
        
        let mono = matrix.outputImage ?? image
        
        // Step 2: Deep blacks and punchy filmic contrast curve
        guard let toneCurve = CIFilter(name: "CIToneCurve") else { return mono }
        toneCurve.setValue(mono, forKey: kCIInputImageKey)
        toneCurve.setValue(CIVector(x: 0.0, y: 0.0), forKey: "inputPoint0")
        toneCurve.setValue(CIVector(x: 0.22, y: 0.12), forKey: "inputPoint1") // Crushed rich blacks
        toneCurve.setValue(CIVector(x: 0.5, y: 0.48), forKey: "inputPoint2")
        toneCurve.setValue(CIVector(x: 0.78, y: 0.86), forKey: "inputPoint3")
        toneCurve.setValue(CIVector(x: 1.0, y: 1.0), forKey: "inputPoint4")
        
        let highContrast = toneCurve.outputImage ?? mono
        
        // Step 3: Silver halide organic grain
        let grained = addFilmGrain(to: highContrast, extent: extent, intensity: 0.075)
        
        return grained.cropped(to: extent)
    }
    
    // MARK: - Helper Filter Pipelines
    
    /// Generates high-frequency grain and composites it over the input image
    private func addFilmGrain(to image: CIImage, extent: CGRect, intensity: Float) -> CIImage {
        guard let random = grainGenerator?.outputImage else { return image }
        
        // Convert white noise to grayscale
        guard let monoFilter = CIFilter(name: "CIColorMonochrome") else { return image }
        monoFilter.setValue(random, forKey: kCIInputImageKey)
        monoFilter.setValue(CIColor(red: 0.5, green: 0.5, blue: 0.5), forKey: kCIInputColorKey)
        monoFilter.setValue(1.0, forKey: kCIInputIntensityKey)
        guard let monoGrain = monoFilter.outputImage else { return image }
        
        // Crop grain to image extent
        let croppedGrain = monoGrain.cropped(to: extent)
        
        // Adjust grain contrast and opacity
        guard let grainControls = CIFilter(name: "CIColorControls") else { return image }
        grainControls.setValue(croppedGrain, forKey: kCIInputImageKey)
        grainControls.setValue(2.0, forKey: kCIInputContrastKey)
        grainControls.setValue(0.0, forKey: kCIInputBrightnessKey)
        guard let highContrastGrain = grainControls.outputImage else { return image }
        
        // Blend grain with soft light mode
        guard let blend = CIFilter(name: "CISoftLightBlendMode") else { return image }
        blend.setValue(highContrastGrain, forKey: kCIInputImageKey)
        blend.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        guard let blended = blend.outputImage else { return image }
        
        // Mix between original and grained image according to intensity
        guard let mixFilter = CIFilter(name: "CIColorMatrix") else { return blended }
        mixFilter.setValue(blended, forKey: kCIInputImageKey)
        
        // Cross fade original and blended
        guard let dissolve = CIFilter(name: "CIDissolveTransition") else { return blended }
        dissolve.setValue(image, forKey: kCIInputImageKey)
        dissolve.setValue(blended, forKey: kCIInputTargetImageKey)
        dissolve.setValue(NSNumber(value: intensity * 8.0), forKey: kCIInputTimeKey)
        
        return dissolve.outputImage?.cropped(to: extent) ?? blended.cropped(to: extent)
    }
    
    /// Chromatic aberration: shifts Red channel horizontally relative to Green and Blue
    private func applyChromaticAberration(to image: CIImage, displacement: CGFloat) -> CIImage {
        let extent = image.extent
        
        // Extract Red channel
        guard let rMatrix = CIFilter(name: "CIColorMatrix") else { return image }
        rMatrix.setValue(image, forKey: kCIInputImageKey)
        rMatrix.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
        rMatrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        rMatrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
        rMatrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        guard let rChannel = rMatrix.outputImage else { return image }
        
        // Displace Red channel
        let shiftedR = rChannel.transformed(by: CGAffineTransform(translationX: displacement, y: 0)).cropped(to: extent)
        
        // Extract Green & Blue channels
        guard let gbMatrix = CIFilter(name: "CIColorMatrix") else { return image }
        gbMatrix.setValue(image, forKey: kCIInputImageKey)
        gbMatrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
        gbMatrix.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
        gbMatrix.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
        gbMatrix.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        guard let gbChannel = gbMatrix.outputImage else { return image }
        
        // Screen or Add Red back with Green & Blue
        guard let addFilter = CIFilter(name: "CIAdditionCompositing") else { return image }
        addFilter.setValue(shiftedR, forKey: kCIInputImageKey)
        addFilter.setValue(gbChannel, forKey: kCIInputBackgroundImageKey)
        
        return addFilter.outputImage?.cropped(to: extent) ?? image
    }
    
    /// Halation: creates a warm blooming halo on high-luminance elements
    private func applyHalation(to image: CIImage, extent: CGRect, intensity: Double) -> CIImage {
        // High-pass threshold for highlights
        guard let threshold = CIFilter(name: "CIColorMatrix") else { return image }
        threshold.setValue(image, forKey: kCIInputImageKey)
        threshold.setValue(CIVector(x: 2.0, y: 0, z: 0, w: 0), forKey: "inputRVector")
        threshold.setValue(CIVector(x: 0, y: 1.5, z: 0, w: 0), forKey: "inputGVector")
        threshold.setValue(CIVector(x: 0, y: 0, z: 0.8, w: 0), forKey: "inputBVector")
        threshold.setValue(CIVector(x: -0.6, y: -0.6, z: -0.6, w: 0), forKey: "inputBiasVector")
        guard let highlights = threshold.outputImage else { return image }
        
        // Soft bloom blur
        guard let blur = CIFilter(name: "CIGaussianBlur") else { return image }
        blur.setValue(highlights.cropped(to: extent), forKey: kCIInputImageKey)
        blur.setValue(18.0, forKey: kCIInputRadiusKey)
        guard let blurredHighlights = blur.outputImage?.cropped(to: extent) else { return image }
        
        // Screen blend back over image
        guard let screen = CIFilter(name: "CIScreenBlendMode") else { return image }
        screen.setValue(blurredHighlights, forKey: kCIInputImageKey)
        screen.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        return screen.outputImage?.cropped(to: extent) ?? image
    }
    
    /// Burns in an authentic 1990s digital camera date stamp in glowing amber-orange digital font
    private func applyRetroDateStamp(to image: CIImage, extent: CGRect) -> CIImage {
        let calendar = Calendar.current
        let date = Date()
        let year = calendar.component(.year, from: date) % 100
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let dateString = String(format: "’%02d %02d %02d", year, month, day)
        
        // Scale font size according to image resolution
        let baseScale = max(extent.width, extent.height) / 1000.0
        let fontSize = max(24.0, 36.0 * baseScale)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 0.95), // Vintage LED amber
            .strokeColor: UIColor(red: 0.2, green: 0.05, blue: 0.0, alpha: 0.6),
            .strokeWidth: -1.5
        ]
        
        let attrString = NSAttributedString(string: dateString, attributes: attributes)
        let textSize = attrString.size()
        
        // Render text to UIImage then convert to CIImage
        let renderer = UIGraphicsImageRenderer(size: extent.size)
        let textOverlayImage = renderer.image { _ in
            let padding: CGFloat = 40.0 * baseScale
            let textRect = CGRect(
                x: extent.width - textSize.width - padding,
                y: extent.height - textSize.height - padding,
                width: textSize.width,
                height: textSize.height
            )
            attrString.draw(in: textRect)
        }
        
        guard let textCI = CIImage(image: textOverlayImage) else { return image }
        
        // Composite text on top of photo
        guard let composite = CIFilter(name: "CISourceOverCompositing") else { return image }
        composite.setValue(textCI, forKey: kCIInputImageKey)
        composite.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        return composite.outputImage?.cropped(to: extent) ?? image
    }
}
