import SwiftUI

public struct TopReadoutBar: View {
    @ObservedObject var cameraEngine: CameraEngine
    
    public init(cameraEngine: CameraEngine) {
        self.cameraEngine = cameraEngine
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Main Top Bar: Status badges & quick toggles
            HStack {
                // Flash / Torch Toggle
                Button(action: {
                    HapticsManager.shared.modeSwitch()
                    toggleFlash()
                }) {
                    Image(systemName: flashIconName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(cameraEngine.flashMode != .off ? .yellow : .white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                
                // Format Badge (RAW / HEIF / JPEG)
                Button(action: {
                    HapticsManager.shared.modeSwitch()
                    cycleCaptureFormat()
                }) {
                    Text(cameraEngine.captureFormat.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(cameraEngine.captureFormat == .rawDNG ? .orange : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            cameraEngine.captureFormat == .rawDNG
                            ? Color.orange.opacity(0.25)
                            : Color.white.opacity(0.12)
                        )
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(cameraEngine.captureFormat == .rawDNG ? Color.orange : Color.clear, lineWidth: 1)
                        )
                }
                
                // Super-Res 90MP Badge
                Button(action: {
                    HapticsManager.shared.modeSwitch()
                    cycleSuperResMode()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                        Text(cameraEngine.superResMode.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(superResBadgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(superResBackgroundColor)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(cameraEngine.superResMode != .off ? superResBadgeColor : Color.clear, lineWidth: 1)
                    )
                }
                
                Spacer()
                
                // Grid Toggle
                Button(action: {
                    HapticsManager.shared.modeSwitch()
                    cameraEngine.showGrid.toggle()
                }) {
                    Image(systemName: cameraEngine.showGrid ? "grid" : "grid.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(cameraEngine.showGrid ? .yellow : .white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                
                // Horizon Level Toggle
                Button(action: {
                    HapticsManager.shared.modeSwitch()
                    cameraEngine.showHorizonLevel.toggle()
                }) {
                    Image(systemName: cameraEngine.showHorizonLevel ? "level.fill" : "level")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(cameraEngine.showHorizonLevel ? .green : .white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            
            // Secondary Telemetry Bar: Live Hardware Exposure Readouts
            HStack(spacing: 12) {
                // ISO
                telemetryItem(
                    title: "ISO",
                    value: String(format: "%d", Int(cameraEngine.currentISO)),
                    isManual: cameraEngine.isManualISO
                )
                
                divider
                
                // Shutter Speed
                telemetryItem(
                    title: "SEC",
                    value: formatShutterSpeed(cameraEngine.currentShutterSpeed),
                    isManual: cameraEngine.isManualShutter
                )
                
                divider
                
                // Aperture
                telemetryItem(
                    title: "APER",
                    value: String(format: "f/%.1f", cameraEngine.currentAperture),
                    isManual: false
                )
                
                divider
                
                // EV
                telemetryItem(
                    title: "EV",
                    value: String(format: "%+.1f", cameraEngine.currentEV),
                    isManual: cameraEngine.isManualEV
                )
                
                divider
                
                // WB
                telemetryItem(
                    title: "WB",
                    value: String(format: "%dK", Int(cameraEngine.currentWhiteBalanceTemp)),
                    isManual: cameraEngine.isManualWB
                )
                
                divider
                
                // Lens
                telemetryItem(
                    title: "LENS",
                    value: cameraEngine.activeLens == .wide ? "26mm" : "13mm",
                    isManual: false
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.65))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Subviews & Helpers
    
    private func telemetryItem(title: String, value: String, isManual: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(isManual ? .orange.opacity(0.85) : .white.opacity(0.45))
            
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(isManual ? .orange : .white)
        }
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 1, height: 18)
    }
    
    private var flashIconName: String {
        switch cameraEngine.flashMode {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.a.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }
    
    private var superResBadgeColor: Color {
        switch cameraEngine.superResMode {
        case .off: return .white.opacity(0.7)
        case .res48MP: return .cyan
        case .res90MP: return Color(red: 1.0, green: 0.35, blue: 0.2) // Tactical Red/Orange
        }
    }
    
    private var superResBackgroundColor: Color {
        switch cameraEngine.superResMode {
        case .off: return Color.white.opacity(0.12)
        case .res48MP: return Color.cyan.opacity(0.2)
        case .res90MP: return Color(red: 1.0, green: 0.35, blue: 0.2).opacity(0.25)
        }
    }
    
    private func toggleFlash() {
        switch cameraEngine.flashMode {
        case .off: cameraEngine.flashMode = .auto
        case .auto: cameraEngine.flashMode = .on
        case .on: cameraEngine.flashMode = .off
        @unknown default: cameraEngine.flashMode = .off
        }
    }
    
    private func cycleCaptureFormat() {
        switch cameraEngine.captureFormat {
        case .heif: cameraEngine.captureFormat = .jpeg
        case .jpeg: cameraEngine.captureFormat = .rawDNG
        case .rawDNG: cameraEngine.captureFormat = .heif
        }
    }
    
    private func cycleSuperResMode() {
        switch cameraEngine.superResMode {
        case .off: cameraEngine.superResMode = .res48MP
        case .res48MP: cameraEngine.superResMode = .res90MP
        case .res90MP: cameraEngine.superResMode = .off
        }
    }
    
    private func formatShutterSpeed(_ seconds: Double) -> String {
        if seconds <= 0 { return "0s" }
        if seconds >= 1.0 {
            return String(format: "%.1fs", seconds)
        } else {
            let denominator = Int(round(1.0 / seconds))
            return "1/\(denominator)s"
        }
    }
}
