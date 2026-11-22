import SwiftUI

public struct GridOverlayView: View {
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            Path { path in
                // Vertical lines (1/3 and 2/3)
                path.move(to: CGPoint(x: width / 3.0, y: 0))
                path.addLine(to: CGPoint(x: width / 3.0, y: height))
                
                path.move(to: CGPoint(x: (2.0 * width) / 3.0, y: 0))
                path.addLine(to: CGPoint(x: (2.0 * width) / 3.0, y: height))
                
                // Horizontal lines (1/3 and 2/3)
                path.move(to: CGPoint(x: 0, y: height / 3.0))
                path.addLine(to: CGPoint(x: width, y: height / 3.0))
                
                path.move(to: CGPoint(x: 0, y: (2.0 * height) / 3.0))
                path.addLine(to: CGPoint(x: width, y: (2.0 * height) / 3.0))
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}
