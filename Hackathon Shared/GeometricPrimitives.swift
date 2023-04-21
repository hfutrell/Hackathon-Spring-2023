//
//  Ray.swift
//  Hackathon
//
//  Created by Holmes Futrell on 4/21/23.
//

import simd

typealias Intersection = (t: Float, normal: SIMD3<Float>)

protocol RayIntersectable {
    func intersect(_ ray: Ray) -> Intersection?
}

struct Ray {
    var origin: SIMD3<Float>
    var direction: SIMD3<Float>
    func point(at t: Float) -> SIMD3<Float> {
        return origin + t * direction
    }
}

struct Cube: RayIntersectable {
    var center: SIMD3<Float>
    var length: Float
    
    func intersect(_ ray: Ray) -> Intersection? {
        var intersection: Intersection? = nil
        for dimension in 0..<3 {
            let d = ray.direction[dimension]
            let o = ray.origin[dimension]
            let temp1: Float = (center[dimension] - o) / d
            let temp2: Float = length / (2 * d)
            let t: Float = temp1 - abs(temp2)
            let test = (0..<3).allSatisfy {
                if $0 == dimension { return true }
                let p = ray.point(at: t)[$0]
                guard p < center[$0] + length / 2, p > center[$0] - length / 2 else { return false }
                return true
            }
            guard test else { continue }
            if intersection == nil || t < intersection!.t {
                var normal = SIMD3<Float>(x: 0, y: 0, z: 0)
                normal[dimension] = temp2 > 0 ? Float(-1.0) : Float(1.0)
                intersection = Intersection(t: t, normal: normal)
            }
        }
        return intersection
    }
}
