//
//  Shaders.metal
//  Hackathon Shared
//
//  Created by Holmes Futrell on 4/19/23.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

typedef struct
{
    float3 position [[attribute(VertexAttributePosition)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
    float3 normal   [[attribute(VertexAttributeNormal)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
    float3 color;
} ColorInOut;

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               constant PerInstanceUniforms *perInstanceUniforms [[ buffer(BufferIndexPerInstanceUniforms) ]],
                               ushort iid [[instance_id]])
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * perInstanceUniforms[iid].modelViewMatrix * position;
    out.texCoord = in.texCoord;

    float3 light = { 0.4, 0.8, 1.0 };
    
    out.color = max(dot(in.normal, light), 0.0) * float3(1.0, 1.0, 1.0) + float3(0.4, 0.1, 0.0);
    
    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    return float4(in.color, 1.0);
}
