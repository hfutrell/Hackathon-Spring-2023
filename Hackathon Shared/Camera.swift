//
//  Camera.swift
//  Hackathon
//
//  Created by Holmes Futrell on 4/19/23.
//

import Foundation

import simd

struct Camera {
    var matrix: simd_float4x3 = simd_float4x3(1.0)
    mutating func move(to location: SIMD3<Float>) {
        matrix.columns.3 = -location
    }
    var location: SIMD3<Float> { return -matrix.columns.3 }
    mutating func look(at location: SIMD3<Float>) {

        let up = SIMD3<Float>(0, 1, 0)
        
        var zaxis = normalize(location - self.location)
        let xaxis = normalize(cross(zaxis, up))
        let yaxis = cross(xaxis, zaxis)
        zaxis *= -1

        let rotationMatrix = matrix_float3x3(xaxis, yaxis, zaxis).transpose

        matrix = matrix_float4x3(rotationMatrix.columns.0,
                                 rotationMatrix.columns.1,
                                 rotationMatrix.columns.2,
                                 matrix.columns.3)
    }
}
