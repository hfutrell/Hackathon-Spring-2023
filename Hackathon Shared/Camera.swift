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
}
