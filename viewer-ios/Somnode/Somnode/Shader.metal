//
//  Shader.metal
//  Somnode
//
//  Created by Jeff Moss on 3/27/18.
//  Copyright © 2018 Jeff Moss. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#define bmapWidth  (256)
#define bmapHeight (256)

struct Uniforms {
    float    array[bmapHeight*bmapWidth*4];
};

kernel void compute_func_1(texture2d<half, access::write> output [[texture(0)]],
                           constant Uniforms &uniforms [[buffer(1)]],
                           uint2 gid [[thread_position_in_grid]])
{
    float w   = output.get_width() ;
    float h   = output.get_height();
    int x   = float(bmapWidth ) * (gid.x / w);
    int y   = float(bmapHeight) * (gid.y / h);
    int top = bmapWidth * (2 * bmapHeight) * 4;
    int row = uniforms.array[top];
    y += (bmapHeight - row);
    int j   = (y * bmapWidth + x) * 4;  // 4 floats per pixel
    
    half r  = uniforms.array[j + 0];
    half g  = uniforms.array[j + 1];
    half b  = uniforms.array[j + 2];
    
    output.write(half4(r, g, b, 1.0), gid);
}
