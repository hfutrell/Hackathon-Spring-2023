//
//  Renderer.swift
//  Hackathon Shared
//
//  Created by Holmes Futrell on 4/19/23.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

let maxBuffersInFlight = 3

enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var dynamicPerInstanceUniformBuffers: [MTLBuffer] = []
    
    let gameWorld = GameWorld()
    
    var camera = Camera(fovRadians: radians_from_degrees(30),
                        nearZ: 1,
                        farZ: 100)
    
    var cursor: Location? = nil
    let maxInstances = 1000000
    
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    var colorMap: MTLTexture
    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    
    var currentFrameBufferIndex = 0
        
    var perInstanceUniformBufferIndex = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>!
    
    var perInstanceUniforms: UnsafeMutablePointer<PerInstanceUniforms>!
        
    var drawableWidth: Float!
    var drawableHeight: Float!
    var aspectRatio: Float { return drawableWidth / drawableHeight }
    
    var rotation: Float = 0
    
    var mesh: MTKMesh
    
    var keyboardControls: KeyboardControls!
    
    init?(metalKitView: MTKView) {
        let device = metalKitView.device!
        self.device = device
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let buffer = self.device.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        dynamicUniformBuffer = buffer
        
        for _ in 0..<maxBuffersInFlight {
            let perInstanceUniformBufferSize = MemoryLayout<Uniforms>.stride * maxInstances
            let buffer = self.device.makeBuffer(length: perInstanceUniformBufferSize, options: [MTLResourceOptions.storageModeShared])!
            dynamicPerInstanceUniformBuffers.append(buffer)
        }
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        
        let sampleCounts = [2, 4, 8]
        let supportedSampleCounts = sampleCounts.filter { device.supportsTextureSampleCount($0) }
        metalKitView.sampleCount = supportedSampleCounts.max() ?? 1
        
        let mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()
        
        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor:depthStateDescriptor) else { return nil }
        depthState = state
        
        do {
            mesh = try Renderer.buildMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to build MetalKit Mesh. Error info: \(error)")
            return nil
        }
        
        do {
            colorMap = try Renderer.loadTexture(device: device, textureName: "ColorMap")
        } catch {
            print("Unable to load texture. Error info: \(error)")
            return nil
        }
        
        let color1 = UIColor(red: 0.5, green: 0.25, blue: 0.05, alpha: 1)
        let color2 = UIColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 1)

        for i in -50...50 {
            for j in -50...50 {
                let even = (j+i+100) % 2 == 0
                
                let y = Int(sin(Float(i) / 10) * 3 + cos(Float(j) / 10) * 2)
                
                gameWorld.insertCube(at: Location(x: i, y: y, z: j), color: even ? color1 : color2)
            }
        }
        
        camera.location = SIMD3(40, 50, 30)
        
        camera.look(at: SIMD3(0, 0, 0))
        
        super.init()
        
    }
    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Create a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
        
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
        
        mtlVertexDescriptor.attributes[VertexAttribute.normal.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.normal.rawValue].offset = 8
        mtlVertexDescriptor.attributes[VertexAttribute.normal.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
        
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 20
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        return mtlVertexDescriptor
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.rasterSampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    class func buildMesh(device: MTLDevice,
                         mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let mdlMesh = MDLMesh.newBox(withDimensions: SIMD3<Float>(1, 1, 1),
                                     segments: SIMD3<UInt32>(2, 2, 2),
                                     geometryType: MDLGeometryType.triangles,
                                     inwardNormals:false,
                                     allocator: metalAllocator)
        
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate
        attributes[VertexAttribute.normal.rawValue].name = MDLVertexAttributeNormal

        mdlMesh.vertexDescriptor = mdlVertexDescriptor
        
        return try MTKMesh(mesh:mdlMesh, device:device)
    }
    
    class func loadTexture(device: MTLDevice,
                           textureName: String) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling
        
        let textureLoader = MTKTextureLoader(device: device)
        
        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]
        
        return try textureLoader.newTexture(name: textureName,
                                            scaleFactor: 1.0,
                                            bundle: nil,
                                            options: textureLoaderOptions)
        
    }
    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        currentFrameBufferIndex = (currentFrameBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * currentFrameBufferIndex
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)
        
        perInstanceUniforms = UnsafeMutableRawPointer(dynamicPerInstanceUniformBuffers[currentFrameBufferIndex].contents()).bindMemory(to:PerInstanceUniforms.self, capacity:maxInstances)
    }
    
    private func updateGameState() {
        /// Update any game state before rendering
        
        uniforms[0].projectionMatrix = camera.projectionMatrix(aspectRatio: aspectRatio)
        
        var objects: [GameObject] = []
        if let cursor {
            let cursorCube = GameObject(kind: .cube, color: SIMD4(x: 1, y: 0, z: 0, w: 1), location: SIMD3<Float>(location: cursor))
            objects.append(cursorCube)
        }
        objects += gameWorld.allObjects.map({ $0.1 })
        
        var i = 0
        for object in objects {
            defer { i += 1 }

            let location = object.location
            let modelMatrix = matrix4x4_translation(location.x, location.y, location.z)
                        
            perInstanceUniforms![i].modelViewMatrix = simd_mul(camera.viewMatrix, modelMatrix)
            
            perInstanceUniforms![i].color = object.color
            
        }
        rotation += 0.01
    }
    
    func handleControls() {
        let movementSpeed: Float = 0.3
        if keyboardControls.isKeyDown(.keyboardLeftArrow) {
            camera.panLeft(amount: movementSpeed)
        }
        if keyboardControls.isKeyDown(.keyboardRightArrow) {
            camera.panRight(amount: movementSpeed)
        }
        if keyboardControls.isKeyDown(.keyboardUpArrow) {
            camera.panFoward(amount: movementSpeed)
        }
        if keyboardControls.isKeyDown(.keyboardDownArrow) {
            camera.panBackward(amount: movementSpeed)
        }
    }
    
    func draw(in view: MTKView) {
        /// Per frame updates hare
        
        handleControls()
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            self.updateDynamicBufferState()
            
            self.updateGameState()
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            let renderPassDescriptor = view.currentRenderPassDescriptor
            
            if let renderPassDescriptor = renderPassDescriptor, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                
                /// Final pass rendering code here
                renderEncoder.label = "Primary Render Encoder"
                
                renderEncoder.pushDebugGroup("Draw Box")
                
                renderEncoder.setCullMode(.back)
                
                renderEncoder.setFrontFacing(.counterClockwise)
                
                renderEncoder.setRenderPipelineState(pipelineState)
                
                renderEncoder.setDepthStencilState(depthState)
                
                renderEncoder.setVertexBuffer(dynamicPerInstanceUniformBuffers[currentFrameBufferIndex],
                                              offset: 0,
                                              index: BufferIndex.perInstanceUniforms.rawValue)
                
                renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                
                for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
                    guard let layout = element as? MDLVertexBufferLayout else {
                        return
                    }
                    
                    if layout.stride != 0 {
                        let buffer = mesh.vertexBuffers[index]
                        renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                    }
                }
                
                renderEncoder.setFragmentTexture(colorMap, index: TextureIndex.color.rawValue)
                
                if gameWorld.allObjects.isEmpty == false {
                    
                    for submesh in mesh.submeshes {
                        renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                            indexCount: submesh.indexCount,
                                                            indexType: submesh.indexType,
                                                            indexBuffer: submesh.indexBuffer.buffer,
                                                            indexBufferOffset: submesh.indexBuffer.offset,
                                                            instanceCount: gameWorld.allObjects.count,
                                                            baseVertex: 0,
                                                            baseInstance: 0)
                    }
                    
                }
                
                renderEncoder.popDebugGroup()
                
                renderEncoder.endEncoding()
                
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }
            
            commandBuffer.commit()
        }
    }
        
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        drawableWidth = Float(size.width)
        drawableHeight = Float(size.height)
    }
}

extension Renderer: MouseControlsDelegate {
    
    func mouseMoved(to viewPoint: CGPoint?, in view: UIView) {
        guard let viewPoint else {
            cursor = nil
            return
        }
        
        let viewWidth = Float(view.bounds.size.width)
        let viewHeight = Float(view.bounds.size.height)
        
        let clipX: Float = 2.0 * Float(viewPoint.x) / viewWidth - 1.0
        let clipY: Float = 2.0 * (viewHeight - Float(viewPoint.y)) / viewHeight - 1.0
        let clipZ: Float = 1.0
        let clipW: Float = 1.0
        
        let clipCoordinates = SIMD4<Float>(x: clipX, y: clipY, z: clipZ, w: clipW)
        
        
        let cameraSpaceVector: SIMD3<Float> = {
            let temp = simd_mul(camera.projectionMatrix(aspectRatio: aspectRatio).inverse, clipCoordinates)
            return normalize(1.0 / temp.w * SIMD3<Float>(x: temp.x, y: temp.y, z: temp.z))
        }()
                
        let rayDirection: SIMD3<Float> = {
            let temp = simd_mul(camera.viewMatrix.inverse, SIMD4<Float>(cameraSpaceVector, 0.0))
            return normalize(SIMD3<Float>(x: temp.x, y: temp.y, z: temp.z))
        }()

        let ray = Ray(origin: camera.location, direction: rayDirection)
        
        var nearestIntersection: Float? = nil
        for (location, object) in gameWorld.allObjects {
            if let (t, normal) = object.intersect(ray) {
                guard nearestIntersection == nil || t < nearestIntersection! else { continue }
                let point = SIMD3<Float>(location: location) + normal
                let location = Location(x: Int(point.x.rounded()),
                                        y: Int(point.y.rounded()),
                                        z: Int(point.z.rounded()))
                nearestIntersection = t
                cursor = location
            }
        }
    }
}

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}
