import SwiftUI
import Photos

public struct QuickPreviewModal: View {
    let metadata: CapturedPhotoMetadata?
    let image: UIImage?
    @Binding var isPresented: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showShareSheet: Bool = false
    
    public init(metadata: CapturedPhotoMetadata?, image: UIImage?, isPresented: Binding<Bool>) {
        self.metadata = metadata
        self.image = image
        self._isPresented = isPresented
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Interactive Zoomable Image
            if let displayImage = image {
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1.0), 6.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                if scale < 1.0 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        offset = .zero
                                    }
                                }
                            }
                            .simultaneously(
                                with: DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 3.0
                            }
                        }
                    }
            } else {
                Text("No Image Available")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Top Action Bar
            VStack {
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    if image != nil {
                        Button(action: {
                            showShareSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
                
                // Bottom Metadata Card
                if let meta = metadata {
                    VStack(alignment: .leading, spacing: 10) {
                        // Title row: Megapixels and dimensions
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(String(format: "%.1f MP", meta.megapixelCount))
                                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                                        .foregroundColor(meta.superResMode != .off ? .orange : .white)
                                    
                                    if meta.superResMode != .off {
                                        Text(meta.superResMode.rawValue)
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Text("\(meta.width) × \(meta.height) PIXELS")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            // Film Look Badge
                            Text(meta.filmLook.rawValue.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(6)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.2))
                        
                        // Technical specs grid
                        HStack(spacing: 20) {
                            specItem(label: "ISO", value: "\(Int(meta.iso))")
                            specItem(label: "SHUTTER", value: formatShutter(meta.shutterSpeed))
                            specItem(label: "LENS", value: "\(meta.lens.rawValue) (\(String(format: "f/%.1f", meta.aperture)))")
                            specItem(label: "FORMAT", value: meta.format.rawValue)
                        }
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let imageToShare = image {
                ActivityView(activityItems: [imageToShare])
            }
        }
    }
    
    private func specItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
    
    private func formatShutter(_ seconds: Double) -> String {
        if seconds <= 0 { return "0s" }
        if seconds >= 1.0 {
            return String(format: "%.1fs", seconds)
        } else {
            let den = Int(round(1.0 / seconds))
            return "1/\(den)s"
        }
    }
}

public struct ActivityView: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]? = nil
    
    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
