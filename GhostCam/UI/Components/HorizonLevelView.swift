import SwiftUI

public struct HorizonLevelView: View {
    @ObservedObject var motionManager = MotionManager.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Center Reference Dot
            Circle()
                .fill(indicatorColor.opacity(0.8))
                .frame(width: 4, height: 4)
            
            // Left fixed reference mark
            Rectangle()
                .fill(indicatorColor.opacity(0.7))
                .frame(width: 24, height: 1.5)
                .offset(x: -55)
            
            // Right fixed reference mark
            Rectangle()
                .fill(indicatorColor.opacity(0.7))
                .frame(width: 24, height: 1.5)
                .offset(x: 55)
            
            // Rotating Artificial Horizon Bar
            HStack(spacing: 40) {
                Rectangle()
                    .fill(indicatorColor)
                    .frame(width: 36, height: 2)
                
                Rectangle()
                    .fill(indicatorColor)
                    .frame(width: 36, height: 2)
            }
            .rotationEffect(.degrees(-motionManager.rollDegrees))
            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: motionManager.rollDegrees)
            
            // Degree readout badge
            VStack {
                Spacer()
                Text(degreeString)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(indicatorColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .offset(y: 40)
            }
        }
        .frame(width: 140, height: 140)
        .allowsHitTesting(false)
    }
    
    private var indicatorColor: Color {
        if motionManager.isLevel {
            return Color(red: 0.0, green: 1.0, blue: 0.4) // Vibrant fluorescent level green
        } else {
            return Color.white.opacity(0.65)
        }
    }
    
    private var degreeString: String {
        if motionManager.isLevel {
            return "0.0° LEVEL"
        } else {
            return String(format: "%+.1f°", -motionManager.rollDegrees)
        }
    }
}
