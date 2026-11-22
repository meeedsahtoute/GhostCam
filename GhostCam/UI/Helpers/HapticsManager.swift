import UIKit

public final class HapticsManager {
    public static let shared = HapticsManager()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    public func shutterPress() {
        heavyImpact.impactOccurred()
    }
    
    public func dialTick() {
        selectionFeedback.selectionChanged()
    }
    
    public func modeSwitch() {
        lightImpact.impactOccurred()
    }
    
    public func rigidTick() {
        rigidImpact.impactOccurred()
    }
    
    public func success() {
        notificationFeedback.notificationOccurred(.success)
    }
    
    public func error() {
        notificationFeedback.notificationOccurred(.error)
    }
}
