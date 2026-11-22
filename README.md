# GhostCam Pro 📸

A production-grade native iOS Pro Camera application engineered in SwiftUI, tailored specifically for **iPhone 12 (4GB RAM)** and sideloading via **LiveContainer** (unsigned `.ipa` built via GitHub Actions).

GhostCam features zero UI stubs or fake controls. Every slider, badge, and dial directly controls hardware `AVCaptureDevice` properties, real-time `CoreImage` / `Metal` render pipelines, and `Vision` translational image registration.

---

## ⚡ Highlights & Key Features

### 1. Core Camera & Hardware Engine (`CameraEngine.swift`)
- **Full Manual Pro Controls (`AVCaptureDevice`):**
  - **ISO**: Full hardware range (ISO 50 to 3200+) with smooth scroll stops and instant `Auto` release.
  - **Shutter Speed**: Microsecond precision (1/8000s to 1s) with fraction readout and instant `Auto` toggle.
  - **Manual Focus**: 0.00 (Macro) to 1.00 (Infinity) with continuous tactile feedback.
  - **Exposure Bias (EV)**: ±3.0 EV in 0.1 EV increments with live compensation.
  - **White Balance**: Color Temperature (2500K to 9000K) and Tint (-150 to +150) converted directly into clamped hardware RGB gains (`[1.0, maxWhiteBalanceGain]`), avoiding Obj-C driver exceptions.
  - **Hardware Lens Switcher**: Direct hardware selection between iPhone 12 lenses:
    - `0.5x` Ultra-Wide (13mm equivalent, $f/2.4$)
    - `1x` Wide (26mm equivalent, $f/1.6$, OIS)
  - **Apple ProRAW / Bayer RAW (`.dng`) vs HEIF/JPEG**: Instant one-tap format switcher.

### 2. Real-Time 60fps GPU Metal Viewfinder (`MetalPreviewView.swift`)
- Built on `MTKView` and an `MTLDevice`-backed `CIContext`.
- Processes `CMSampleBuffer` pixel buffers delivered from `AVCaptureVideoDataOutput` at 60fps with zero latency.
- Real-time live GPU film simulations applied simultaneously to the viewfinder and captured frames:
  1. **Natural**: Lifelike color fidelity, zero digital over-sharpening, subtle dynamic range protection.
  2. **Cinema 2383**: Kodak 2383 Print Film emulation with rich filmic S-curve and authentic Teal & Orange split toning.
  3. **Portra 400**: Kodak Portra 400 warm pastel highlights, soft highlight roll-off, and subtle organic film grain.
  4. **90s Digicam / VHS**: Highlight halation bloom, horizontal chromatic aberration fringe, CCD sensor grain, and authentic amber digital date stamp.
  5. **Noir 35mm**: High-contrast panchromatic monochrome with deep blacks and silver halide grain.

### 3. Ultra-Res 90MP Multi-Frame Super-Resolution Engine (`SuperResEngine.swift`)
- **90MP ULTRA Mode (`10954 × 8216`) & 48MP Mode (`8000 × 6000`)**:
  1. **Rapid Burst Capture**: Fires a rapid succession of 6–8 uncompressed frames.
  2. **Vision Micro-Shake Alignment**: Aligns each frame to the reference frame using `VNTranslationalImageRegistrationRequest`.
  3. **GPU Multi-Frame Stacking**: Blends aligned frames on the GPU via `CIDissolveTransition` / CoreImage accumulator to cancel sensor noise and increase dynamic range by ~1.5 stops.
  4. **Lanczos Upscaling & Luminance Recovery**: `CILanczosScaleTransform` upscales to 90 Megapixels with `CIUnsharpMask` micro-contrast detail recovery.
  5. **Strict iPhone 12 Memory Safety (4GB RAM)**:
     - All stages wrapped in `autoreleasepool`.
     - Direct-to-disk streaming via `CIContext.writeJPEGRepresentation(of:to:...)`.
     - Never allocates 360MB uncompressed bitmaps in memory, eliminating Jetsam OOM crashes.
     - Saves directly to Photo Library (`PHPhotoLibrary`) and outputs a lightweight 512px preview thumbnail.

### 4. Tactical Pro HUD (`ContentView.swift`)
- **Leica & Halide Inspired Aesthetic**: Deep OLED blacks, monospaced telemetry, and subtle tactile accents.
- **Live Rule-of-Thirds Grid**: Toggleable 3x3 golden composition overlay.
- **CoreMotion Horizon Level Indicator**: Real-time crosshair indicator that turns vibrant fluorescent green (`#00FF66`) and triggers rigid haptic feedback when level within $\pm 0.5^\circ$.
- **Real-Time Top Readout Bar**: Dynamic readouts for ISO, Shutter, $f$-number, EV, WB Kelvin, and active lens.
- **Smooth Horizontal Dial Wheel**: Calibrated stops with `UISelectionFeedbackGenerator` haptic ticks.
- **Quick Thumbnail Inspector Modal**: Pinch-to-zoom (up to 6x) photo inspector with technical metadata card displaying output dimensions, megapixel count, lens, aperture, and film profile.

---

## 🛠 Project Structure

```
GhostCam/
├── App/
│   ├── GhostCamApp.swift          # Main SwiftUI app entry point
│   └── Info.plist                 # Permissions (Camera, Microphone, Photos)
├── Engine/
│   ├── CameraEngine.swift         # Hardware AVCaptureDevice & session engine
│   ├── SuperResEngine.swift       # 90MP multi-frame registration & upscaling
│   ├── FilmSimulationEngine.swift # GPU CoreImage/Metal film simulation looks
│   └── MetalPreviewView.swift     # 60fps MTKView live camera viewfinder
├── UI/
│   ├── ContentView.swift          # Main HUD layout
│   ├── Components/
│   │   ├── TopReadoutBar.swift    # Live hardware telemetry bar
│   │   ├── ManualControlsWheel.swift # Horizontal manual control dials
│   │   ├── HorizonLevelView.swift # CoreMotion level crosshairs
│   │   ├── GridOverlayView.swift  # Rule-of-thirds grid
│   │   ├── QuickPreviewModal.swift# Interactive zoomable photo inspector
│   │   └── FilmLookSelectorView.swift # Film stock selector pills
│   └── Helpers/
│       ├── MotionManager.swift    # CMMotionManager roll/pitch monitor
│       └── HapticsManager.swift   # UIImpactFeedbackGenerator haptic engine
└── Resources/
    └── Assets.xcassets            # Icons and color assets

GhostCamTests/
└── GhostCamTests.swift            # SuperRes dimensions, filters, and parameter tests

.github/workflows/
└── build-ipa.yml                  # Automated CI unsigned .ipa packaging
```

---

## 🚀 Building & Sideloading via LiveContainer

### Sideloading without a Paid Developer Account
GhostCam is packaged as an **unsigned `.ipa`** designed to run seamlessly in **LiveContainer**, **TrollStore**, **AltStore**, or **SideStore**.

1. **GitHub Actions Artifact:**
   - Every push to `main` automatically triggers `.github/workflows/build-ipa.yml`.
   - Download `GhostCam-LiveContainer-unsigned.zip` from the Actions tab.
2. **Import into LiveContainer:**
   - Open LiveContainer on your iPhone 12.
   - Tap `+` and select `GhostCam.ipa`.
   - Launch and enjoy full manual camera control and 90MP Super-Resolution!

### Building Locally via Command Line (macOS)
```bash
# Clone the repository
git clone https://github.com/your-username/GhostCam.git
cd GhostCam

# Run Unit Tests on Simulator
xcodebuild test \
  -project GhostCam.xcodeproj \
  -scheme GhostCamTests \
  -destination "platform=iOS Simulator,name=iPhone 15,OS=latest" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

# Build Unsigned IPA
xcodebuild build \
  -project GhostCam.xcodeproj \
  -scheme GhostCam \
  -destination "generic/platform=iOS" \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

# Package into .ipa
mkdir -p build/ipa/Payload
cp -r build/DerivedData/Build/Products/Release-iphoneos/GhostCam.app build/ipa/Payload/
cd build/ipa && zip -qr GhostCam.ipa Payload
```

---

## 🧪 Code Quality & Self-Tests
- **Zero `try!`**: Every throwing call is safely wrapped with contextual error recovery.
- **Zero force unwraps (`!`)**: All optionals are safely unwrapped using `guard let` or `if let`.
- **Zero Dead Buttons**: Every single toggle, dial, and badge is connected to active hardware pipelines.
- **Strict Memory Safety**: High-resolution 90MP bitmap buffers stream directly to disk without exhausting system RAM.
