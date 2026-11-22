import SwiftUI
import MetalKit
import CoreImage
import AVFoundation

public final class MetalPreviewRenderer: NSObject, MTKViewDelegate {
    public static let shared = MetalPreviewRenderer()
    
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let ciContext: CIContext?
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    private let bufferLock = NSLock()
    private var currentPixelBuffer: CVPixelBuffer?
    
    public var selectedFilmLook: FilmLook = .natural
    
    override init() {
        self.device = MTLCreateSystemDefaultDevice()
        self.commandQueue = self.device?.makeCommandQueue()
        
        if let metalDevice = self.device {
            self.ciContext = CIContext(
                mtlDevice: metalDevice,
                options: [
                    .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
                    .cacheIntermediates: false,
                    .priorityRequestLow: true
                ]
            )
        } else {
            self.ciContext = nil
        }
        super.init()
    }
    
    public func updatePixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        bufferLock.lock()
        self.currentPixelBuffer = pixelBuffer
        bufferLock.unlock()
    }
    
    // MARK: - MTKViewDelegate
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize if necessary
    }
    
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue?.makeCommandBuffer(),
              let ciContext = self.ciContext else {
            return
        }
        
        var pixelBufferToDraw: CVPixelBuffer?
        bufferLock.lock()
        pixelBufferToDraw = self.currentPixelBuffer
        bufferLock.unlock()
        
        guard let pixelBuffer = pixelBufferToDraw else {
            // Nothing to draw yet, clear texture to OLED black
            let renderPass = view.currentRenderPassDescriptor
            if let renderPass = renderPass, let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) {
                encoder.endEncoding()
            }
            commandBuffer.present(drawable)
            commandBuffer.commit()
            return
        }
        
        autoreleasepool {
            var inputImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            // Camera sensor buffer arrives in landscape-right; orient to portrait
            inputImage = inputImage.oriented(.right)
            
            // Apply live real-time GPU Film Look
            let filteredImage = FilmSimulationEngine.shared.apply(
                filter: selectedFilmLook,
                to: inputImage,
                addDateStamp: false // Live preview does not need static burned date stamp
            )
            
            // Calculate aspect-fill scale and translation to fill the MTKView drawable
            let drawableSize = view.drawableSize
            let imageExtent = filteredImage.extent
            
            guard imageExtent.width > 0, imageExtent.height > 0 else {
                commandBuffer.commit()
                return
            }
            
            let scaleX = drawableSize.width / imageExtent.width
            let scaleY = drawableSize.height / imageExtent.height
            let scale = max(scaleX, scaleY)
            
            let scaledWidth = imageExtent.width * scale
            let scaledHeight = imageExtent.height * scale
            
            let originX = (drawableSize.width - scaledWidth) * 0.5
            let originY = (drawableSize.height - scaledHeight) * 0.5
            
            let transform = CGAffineTransform(scaleX: scale, y: scale)
                .concatenating(CGAffineTransform(translationX: originX, y: originY))
            
            let finalImage = filteredImage.transformed(by: transform)
            let destinationBounds = CGRect(origin: .zero, size: drawableSize)
            
            ciContext.render(
                finalImage,
                to: drawable.texture,
                commandBuffer: commandBuffer,
                bounds: destinationBounds,
                colorSpace: colorSpace
            )
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

public struct MetalPreviewView: UIViewRepresentable {
    @ObservedObject var cameraEngine: CameraEngine
    
    public init(cameraEngine: CameraEngine) {
        self.cameraEngine = cameraEngine
    }
    
    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("[GhostCam MetalPreviewView] Metal is not supported on this device.")
            return mtkView
        }
        
        mtkView.device = defaultDevice
        mtkView.backgroundColor = .black
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false // Required for CIContext rendering
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.delegate = MetalPreviewRenderer.shared
        mtkView.contentMode = .scaleAspectFill
        
        return mtkView
    }
    
    public func updateUIView(_ uiView: MTKView, context: Context) {
        MetalPreviewRenderer.shared.selectedFilmLook = cameraEngine.selectedFilmLook
    }
}
