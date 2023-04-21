//
//  Camera.swift
//  Hackathon
//
//  Created by Holmes Futrell on 4/19/23.
//

import Foundation

import simd

struct Camera {
    
    init(fovRadians: Float, nearZ: Float, farZ: Float) {
        self.fovRadians = fovRadians
        self.nearZ = nearZ
        self.farZ = farZ
    }
    
    /// the location of the camera in world-space
    var location: SIMD3<Float> = .zero
   
    /// the x, y, and z axis of the camera in world-space
    var axis: simd_float3x3 = simd_float3x3(1.0)
    
    /// the rotation matrix of the camera
    var rotation: simd_float3x3 { axis.transpose }
    
    func projectionMatrix(aspectRatio: Float) -> simd_float4x4 {
        return Camera.matrixPerspectiveRightHand(fovyRadians: fovRadians,
                                                 aspectRatio: aspectRatio,
                                                 nearZ: nearZ,
                                                 farZ: farZ)
    }
    
    var fovRadians: Float
    var nearZ, farZ: Float
    
    /// the view matrix of the camera
    var matrix: simd_float4x3 {
        return simd_float4x3(rotation.columns.0,
                             rotation.columns.1,
                             rotation.columns.2,
                             -rotation * location)
    }
    
    var viewMatrix: matrix_float4x4 {
        let matrix = self.matrix
        return matrix_float4x4(SIMD4<Float>(matrix.columns.0, 0.0),
                               SIMD4<Float>(matrix.columns.1, 0.0),
                               SIMD4<Float>(matrix.columns.2, 0.0),
                               SIMD4<Float>(matrix.columns.3, 1.0)
        )
    }

    
    private let up = SIMD3<Float>(0, 1, 0)
    
    mutating func look(at location: SIMD3<Float>) {

        var zaxis = normalize(location - self.location)
        let xaxis = normalize(cross(zaxis, up))
        let yaxis = cross(xaxis, zaxis)
        zaxis *= -1

        axis = matrix_float3x3(xaxis, yaxis, zaxis)
    }
            
    private var panForwardDirection: SIMD3<Float> { return -cross(rotation.transpose.columns.0, up) }
    private var panRightDirection: SIMD3<Float> { return rotation.transpose.columns.0 }

    mutating func panFoward(amount: Float) { location += amount * panForwardDirection }
    mutating func panBackward(amount: Float) { location -= amount * panForwardDirection }
    mutating func panLeft(amount: Float) { location -= amount * panRightDirection }
    mutating func panRight(amount: Float) { location += amount * panRightDirection }
    
    private static func matrixPerspectiveRightHand(fovyRadians fovy: Float,
                                                   aspectRatio: Float,
                                                   nearZ: Float,
                                                   farZ: Float) -> matrix_float4x4 {
        let ys = 1 / tanf(fovy * 0.5)
        let xs = ys / aspectRatio
        let zs = farZ / (nearZ - farZ)
        return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                             vector_float4( 0, ys, 0,   0),
                                             vector_float4( 0,  0, zs, -1),
                                             vector_float4( 0,  0, zs * nearZ, 0)))
    }
}
