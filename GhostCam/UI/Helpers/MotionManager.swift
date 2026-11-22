import Foundation
import CoreMotion
import SwiftUI
import Combine

public final class MotionManager: ObservableObject {
    public static let shared = MotionManager()
    
    private let motionManager = CMMotionManager()
    
    @Published public var rollDegrees: Double = 0.0
    @Published public var pitchDegrees: Double = 0.0
    @Published public var isLevel: Bool = false
    
    private var wasLevel: Bool = false
    
    init() {
        startMotionUpdates()
    }
    
    public func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            
            // Convert radians to degrees
            let roll = motion.attitude.roll * (180.0 / .pi)
            let pitch = motion.attitude.pitch * (180.0 / .pi)
            
            // Adjust roll for portrait orientation
            // Near 0° is level portrait
            let currentRoll = roll
            let levelThreshold = 0.5 // Snaps within ±0.5°
            
            let level = abs(currentRoll) <= levelThreshold
            
            self.rollDegrees = currentRoll
            self.pitchDegrees = pitch
            self.isLevel = level
            
            if level && !self.wasLevel {
                HapticsManager.shared.rigidTick()
            }
            self.wasLevel = level
        }
    }
    
    public func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
}
