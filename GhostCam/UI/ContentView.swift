import SwiftUI
import AVFoundation

public struct ContentView: View {
    @StateObject private var cameraEngine = CameraEngine.shared
    @StateObject private var motionManager = MotionManager.shared
    
    @State private var showPreviewModal: Bool = false
    @State private var shutterButtonScale: CGFloat = 1.0
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // OLED Pure Black Canvas
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - 1. Top Readout & Status Bar
                TopReadoutBar(cameraEngine: cameraEngine)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    .zIndex(10)
                
                // MARK: - 2. Live Metal GPU Viewfinder
                GeometryReader { geometry in
                    ZStack {
                        // Real-Time 60fps Metal GPU Preview
                        MetalPreviewView(cameraEngine: cameraEngine)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                HapticsManager.shared.modeSwitch()
                                cameraEngine.setFocusAndExposurePoint(at: location, viewSize: geometry.size)
                            }
                        
                        // Rule of Thirds Grid Overlay
                        if cameraEngine.showGrid {
                            GridOverlayView()
                        }
                        
                        // CoreMotion Horizon Level Indicator
                        if cameraEngine.showHorizonLevel {
                            HorizonLevelView()
                        }
                        
                        // Tap to Focus Reticle
                        if cameraEngine.showFocusReticle, let point = cameraEngine.focusPointOfInterest {
                            FocusReticleView()
                                .position(point)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Processing & Burst Overlay
                        if cameraEngine.isBurstCapturing {
                            ProcessingProgressOverlay(
                                progress: cameraEngine.processingProgress,
                                status: cameraEngine.processingStatus
                            )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 10)
                .frame(maxHeight: .infinity)
                
                // MARK: - 3. Hardware Lens Switcher (0.5x Ultra-Wide & 1x Wide)
                HStack(spacing: 12) {
                    ForEach(LensType.allCases) { lens in
                        let isSelected = cameraEngine.activeLens == lens
                        Button(action: {
                            HapticsManager.shared.modeSwitch()
                            cameraEngine.switchLens(to: lens)
                        }) {
                            Text(lens.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(isSelected ? .black : .white)
                                .frame(width: 44, height: 44)
                                .background(isSelected ? Color.white : Color.white.opacity(0.15))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 6)
                
                // MARK: - 4. Film Look Selector Carousel
                FilmLookSelectorView(cameraEngine: cameraEngine)
                    .padding(.bottom, 6)
                
                // MARK: - 5. Smooth Manual Controls Dial Wheel
                ManualControlsWheel(cameraEngine: cameraEngine)
                    .padding(.bottom, 12)
                
                // MARK: - 6. Tactical Shutter & Bottom Action Bar
                HStack(alignment: .center) {
                    // Quick Thumbnail Preview Button (Bottom Left)
                    Button(action: {
                        if cameraEngine.lastCapturedThumbnail != nil {
                            HapticsManager.shared.modeSwitch()
                            showPreviewModal = true
                        }
                    }) {
                        ZStack {
                            if let thumb = cameraEngine.lastCapturedThumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 52, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white.opacity(0.4))
                                    )
                            }
                        }
                    }
                    .frame(width: 70, alignment: .leading)
                    .padding(.leading, 24)
                    
                    Spacer()
                    
                    // Tactile Shutter Button (Center)
                    Button(action: {
                        triggerShutter()
                    }) {
                        ZStack {
                            // Outer ring
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 76, height: 76)
                            
                            // Progress spinner during 90MP burst capture
                            if cameraEngine.isBurstCapturing {
                                Circle()
                                    .trim(from: 0.0, to: CGFloat(cameraEngine.processingProgress))
                                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                    .frame(width: 76, height: 76)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.linear, value: cameraEngine.processingProgress)
                            }
                            
                            // Inner tactile trigger
                            Circle()
                                .fill(shutterInnerColor)
                                .frame(width: 62, height: 62)
                                .scaleEffect(shutterButtonScale)
                        }
                    }
                    .disabled(cameraEngine.isBurstCapturing)
                    
                    Spacer()
                    
                    // Quick Reset / Auto Lock Toggle (Bottom Right)
                    Button(action: {
                        HapticsManager.shared.modeSwitch()
                        cameraEngine.resetAllToAuto()
                    }) {
                        VStack(spacing: 3) {
                            Image(systemName: "camera.aperture")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Text("ALL AUTO")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(width: 52, height: 52)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .frame(width: 70, alignment: .trailing)
                    .padding(.trailing, 24)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            cameraEngine.startSession()
        }
        .onDisappear {
            cameraEngine.stopSession()
        }
        .fullScreenCover(isPresented: $showPreviewModal) {
            QuickPreviewModal(
                metadata: cameraEngine.lastCapturedMetadata,
                image: cameraEngine.lastCapturedThumbnail,
                isPresented: $showPreviewModal
            )
        }
    }
    
    // MARK: - Shutter Action & Animation
    
    private func triggerShutter() {
        HapticsManager.shared.shutterPress()
        
        withAnimation(.easeInOut(duration: 0.08)) {
            shutterButtonScale = 0.88
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                self.shutterButtonScale = 1.0
            }
        }
        
        cameraEngine.capturePhoto()
    }
    
    private var shutterInnerColor: Color {
        if cameraEngine.superResMode == .res90MP {
            return Color(red: 1.0, green: 0.35, blue: 0.2) // Tactical Red/Orange for 90MP Ultra
        } else if cameraEngine.superResMode == .res48MP {
            return Color.cyan
        } else {
            return Color.white
        }
    }
}

// MARK: - Focus Reticle View

struct FocusReticleView: View {
    @State private var isPulsing: Bool = false
    
    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.yellow, lineWidth: 1.5)
                .frame(width: 60, height: 60)
            
            Circle()
                .fill(Color.yellow)
                .frame(width: 4, height: 4)
        }
        .scaleEffect(isPulsing ? 0.95 : 1.1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Processing Overlay View

struct ProcessingProgressOverlay: View {
    let progress: Double
    let status: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
            
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                    .scaleEffect(1.5)
                
                Text(status)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                // Linear progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(Color.orange)
                            .frame(width: geo.size.width * CGFloat(progress), height: 6)
                            .animation(.linear(duration: 0.2), value: progress)
                    }
                }
                .frame(width: 220, height: 6)
                
                Text(String(format: "%d%%", Int(progress * 100)))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
            }
            .padding(24)
            .background(Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.95))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .allowsHitTesting(true)
    }
}
