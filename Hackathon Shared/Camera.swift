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
        
        var zaxis: SIMD3<Float> = normalize(location - self.location)
        let xaxis: SIMD3<Float> = normalize(cross(zaxis, up))
        let yaxis: SIMD3<Float> = cross(xaxis, zaxis)
       
        zaxis *= -1

        matrix.columns.0 = SIMD3(xaxis.x, yaxis.x, zaxis.x)
        matrix.columns.1 = SIMD3(xaxis.y, yaxis.y, zaxis.y)
        matrix.columns.2 = SIMD3(xaxis.z, yaxis.z, zaxis.z)
    }
}
