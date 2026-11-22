import SwiftUI

public struct ManualControlsWheel: View {
    @ObservedObject var cameraEngine: CameraEngine
    
    // Standard ISO stops
    private let isoStops: [Float] = [
        50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200
    ]
    
    // Standard shutter speeds
    private let shutterStops: [Double] = [
        1.0/8000.0, 1.0/4000.0, 1.0/2000.0, 1.0/1000.0, 1.0/500.0, 1.0/250.0,
        1.0/125.0, 1.0/60.0, 1.0/30.0, 1.0/15.0, 1.0/8.0, 1.0/4.0, 1.0/2.0, 1.0
    ]
    
    // EV stops
    private let evStops: [Float] = [
        -3.0, -2.7, -2.3, -2.0, -1.7, -1.3, -1.0, -0.7, -0.3, 0.0,
        +0.3, +0.7, +1.0, +1.3, +1.7, +2.0, +2.3, +2.7, +3.0
    ]
    
    public init(cameraEngine: CameraEngine) {
        self.cameraEngine = cameraEngine
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Active parameter dial/slider (visible when not AUTO mode)
            if cameraEngine.activeManualMode != .auto {
                VStack(spacing: 4) {
                    HStack {
                        // Current mode & value label
                        HStack(spacing: 6) {
                            Text(cameraEngine.activeManualMode.rawValue)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                            
                            Text(currentActiveValueString)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // Instant Auto Reset Button
                        Button(action: {
                            HapticsManager.shared.modeSwitch()
                            resetCurrentModeToAuto()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 10, weight: .bold))
                                Text("AUTO")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(isCurrentModeManual ? .orange : .white.opacity(0.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // The smooth horizontal scroll wheel
                    activeDialWheel
                        .frame(height: 48)
                }
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.75))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .padding(.horizontal, 12)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Mode Selector Bar [AUTO, EV, ISO, SHUTTER, FOCUS, WB]
            HStack(spacing: 4) {
                ForEach(ManualControlMode.allCases) { mode in
                    Button(action: {
                        HapticsManager.shared.modeSwitch()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            cameraEngine.activeManualMode = mode
                        }
                    }) {
                        VStack(spacing: 2) {
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(modeButtonColor(for: mode))
                            
                            // Indicator dot showing if this parameter is manually locked
                            Circle()
                                .fill(isModeActiveAndManual(mode) ? Color.orange : Color.clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            cameraEngine.activeManualMode == mode
                            ? Color.white.opacity(0.18)
                            : Color.white.opacity(0.06)
                        )
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
    
    // MARK: - Active Dial Wheels
    
    @ViewBuilder
    private var activeDialWheel: some View {
        switch cameraEngine.activeManualMode {
        case .auto:
            EmptyView()
        case .ev:
            evSlider
        case .iso:
            isoWheel
        case .shutter:
            shutterWheel
        case .focus:
            focusSlider
        case .wb:
            wbSlider
        }
    }
    
    // MARK: - ISO Wheel
    private var isoWheel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(isoStops, id: \.self) { stop in
                    let isSelected = abs(cameraEngine.currentISO - stop) < 1.0
                    Button(action: {
                        HapticsManager.shared.dialTick()
                        cameraEngine.setManualISO(stop)
                    }) {
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(isSelected ? Color.orange : Color.white.opacity(0.4))
                                .frame(width: isSelected ? 3 : 1.5, height: isSelected ? 20 : 12)
                            
                            Text("\(Int(stop))")
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .monospaced))
                                .foregroundColor(isSelected ? .orange : .white.opacity(0.6))
                        }
                        .frame(width: 40)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Shutter Wheel
    private var shutterWheel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(shutterStops, id: \.self) { stop in
                    let isSelected = abs(cameraEngine.currentShutterSpeed - stop) < 0.0001
                    Button(action: {
                        HapticsManager.shared.dialTick()
                        cameraEngine.setManualShutterSpeed(stop)
                    }) {
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(isSelected ? Color.orange : Color.white.opacity(0.4))
                                .frame(width: isSelected ? 3 : 1.5, height: isSelected ? 20 : 12)
                            
                            Text(formatShutter(stop))
                                .font(.system(size: 9, weight: isSelected ? .bold : .medium, design: .monospaced))
                                .foregroundColor(isSelected ? .orange : .white.opacity(0.6))
                        }
                        .frame(width: 44)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - EV Slider
    private var evSlider: some View {
        HStack(spacing: 12) {
            Text("-3")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            
            Slider(
                value: Binding(
                    get: { Double(cameraEngine.currentEV) },
                    set: { val in
                        HapticsManager.shared.dialTick()
                        cameraEngine.setExposureBias(Float(val))
                    }
                ),
                in: Double(cameraEngine.minEV)...Double(cameraEngine.maxEV),
                step: 0.1
            )
            .accentColor(.orange)
            
            Text("+3")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Focus Slider
    private var focusSlider: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "camera.macro")
                    .font(.system(size: 10))
                Text("MACRO")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white.opacity(0.6))
            
            Slider(
                value: Binding(
                    get: { Double(cameraEngine.currentLensPosition) },
                    set: { val in
                        HapticsManager.shared.dialTick()
                        cameraEngine.setManualFocus(lensPosition: Float(val))
                    }
                ),
                in: 0.0...1.0,
                step: 0.02
            )
            .accentColor(.orange)
            
            HStack(spacing: 4) {
                Image(systemName: "infinity")
                    .font(.system(size: 10))
                Text("INF")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - White Balance Slider
    private var wbSlider: some View {
        HStack(spacing: 12) {
            Text("2500K")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            
            Slider(
                value: Binding(
                    get: { Double(cameraEngine.currentWhiteBalanceTemp) },
                    set: { val in
                        HapticsManager.shared.dialTick()
                        cameraEngine.setManualWhiteBalance(temperature: Float(val), tint: cameraEngine.currentWhiteBalanceTint)
                    }
                ),
                in: 2500.0...9000.0,
                step: 100.0
            )
            .accentColor(.orange)
            
            Text("9000K")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helpers
    
    private var currentActiveValueString: String {
        switch cameraEngine.activeManualMode {
        case .auto: return "Continuous"
        case .ev: return String(format: "%+.1f EV", cameraEngine.currentEV)
        case .iso: return "\(Int(cameraEngine.currentISO))"
        case .shutter: return formatShutter(cameraEngine.currentShutterSpeed)
        case .focus: return String(format: "%.2f", cameraEngine.currentLensPosition)
        case .wb: return "\(Int(cameraEngine.currentWhiteBalanceTemp))K"
        }
    }
    
    private var isCurrentModeManual: Bool {
        switch cameraEngine.activeManualMode {
        case .auto: return false
        case .ev: return cameraEngine.isManualEV
        case .iso: return cameraEngine.isManualISO
        case .shutter: return cameraEngine.isManualShutter
        case .focus: return cameraEngine.isManualFocus
        case .wb: return cameraEngine.isManualWB
        }
    }
    
    private func resetCurrentModeToAuto() {
        switch cameraEngine.activeManualMode {
        case .auto:
            cameraEngine.resetAllToAuto()
        case .ev:
            cameraEngine.setExposureBias(0.0)
        case .iso, .shutter:
            cameraEngine.resetExposureToAuto()
        case .focus:
            cameraEngine.resetFocusToAuto()
        case .wb:
            cameraEngine.resetWhiteBalanceToAuto()
        }
    }
    
    private func isModeActiveAndManual(_ mode: ManualControlMode) -> Bool {
        switch mode {
        case .auto: return false
        case .ev: return cameraEngine.isManualEV
        case .iso: return cameraEngine.isManualISO
        case .shutter: return cameraEngine.isManualShutter
        case .focus: return cameraEngine.isManualFocus
        case .wb: return cameraEngine.isManualWB
        }
    }
    
    private func modeButtonColor(for mode: ManualControlMode) -> Color {
        if cameraEngine.activeManualMode == mode {
            return .orange
        } else if isModeActiveAndManual(mode) {
            return .orange.opacity(0.8)
        } else {
            return .white.opacity(0.7)
        }
    }
    
    private func formatShutter(_ seconds: Double) -> String {
        if seconds <= 0 { return "0s" }
        if seconds >= 1.0 {
            return String(format: "%.1fs", seconds)
        } else {
            let den = Int(round(1.0 / seconds))
            return "1/\(den)"
        }
    }
}
