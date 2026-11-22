import SwiftUI

public struct FilmLookSelectorView: View {
    @ObservedObject var cameraEngine: CameraEngine
    
    public init(cameraEngine: CameraEngine) {
        self.cameraEngine = cameraEngine
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilmLook.allCases) { look in
                    let isSelected = cameraEngine.selectedFilmLook == look
                    let rgb = look.badgeColor
                    let color = Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
                    
                    Button(action: {
                        HapticsManager.shared.modeSwitch()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            cameraEngine.selectedFilmLook = look
                        }
                    }) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(color)
                                .frame(width: 6, height: 6)
                            
                            Text(look.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .monospaced))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            isSelected
                            ? Color.white.opacity(0.2)
                            : Color.white.opacity(0.06)
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
