//
//  WaterfallView.swift
//  Somnode
//
//  Created by Jeff Moss on 3/27/18.
//  Copyright © 2018 Jeff Moss. All rights reserved.
//

import UIKit
import MetalKit

import Accelerate

let bitmapWidth  = 256
let bitmapHeight = 256

var spectrumArray = [Float](repeating: 0, count: bitmapWidth)
var enable = true

class WaterfallView: MTKView {
    var frameCount = 0
    private var queue:           MTLCommandQueue!
    private var cps:             MTLComputePipelineState!
    private var uniform_buffer:  MTLBuffer!
    
    required public init(coder: NSCoder) {
        super.init(coder: coder)
        initCommon()
    }
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        initCommon()
    }
    private func initCommon() {
        if device == nil {
            device = MTLCreateSystemDefaultDevice()
        }
        framebufferOnly = false
        self.preferredFramesPerSecond = 60
        createUniformBuffer()
        registerComputeShader()
    }
    
    func createUniformBuffer() {
        let bytesPerPixel = 4 * MemoryLayout<Float>.size
        let bytes = bitmapWidth * (1 + 2 * bitmapHeight) * bytesPerPixel
        let options = MTLResourceOptions()
        uniform_buffer = device!.makeBuffer(length: bytes * MemoryLayout<Float>.size,
                                            options: options)
        let bufferPointer = uniform_buffer.contents()
        memset(bufferPointer, 0, bytes * MemoryLayout<Float>.size)
    }
    
    func registerComputeShader() {
        queue = device!.makeCommandQueue()
        let library = device!.newDefaultLibrary()!
        let kernel = library.makeFunction(name: "compute_func_1")!
        do {
            try cps = device!.makeComputePipelineState(function: kernel)
        } catch {
            // perhaps handle error
        }
    }
    
    func computeShader() {
        if let drawable = currentDrawable {
            let commandBuffer = queue.makeCommandBuffer()
            let commandEncoder = commandBuffer.makeComputeCommandEncoder()
            commandEncoder.setComputePipelineState(cps)
            commandEncoder.setTexture(drawable.texture, at: 0)
            commandEncoder.setBuffer(uniform_buffer, offset: 0, at: 1)
            let threadGroupCount = MTLSizeMake(8, 8, 1)
            let threadGroups = MTLSizeMake(drawable.texture.width  / threadGroupCount.width,
                                           drawable.texture.height / threadGroupCount.height, 1)
            commandEncoder.dispatchThreadgroups(threadGroups,
                                                threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    @objc func updateBitmap() {
        
        let buffer2Pointer = uniform_buffer.contents()
        let bytesPerPixel = 4 * MemoryLayout<Float>.size
        
        let array = spectrumArray
        
        // for j in 0 ..< bitmapHeight { }
        if true {
            let j = frameCount % bitmapHeight
            for i in 0 ..< bitmapWidth {
                var r : Float, g : Float, b : Float  //  RGB color components
                
                // these are just some changing RGB colors to show bitmap animation
                let v = (frameCount/2 + i) % bitmapWidth
                let u = (frameCount   + j) % bitmapHeight
                r = Float(v) / Float(bitmapWidth)
                g = Float(u) / Float(bitmapHeight)
                b = Float((bitmapWidth - i) + (bitmapWidth - u)) / Float(bitmapWidth + bitmapHeight)
                
                //
                r = 0; b = 0; g = 0;
                if i < spectrumArray.count {
                    let y = array[i]
                    r = y
                    g = y
                    b = y
                }
                //
                var row = bitmapHeight - j
                var pixel : [Float] = [ r, g, b, 1.0 ]
                let offset0 = (row * bitmapWidth + i) * bytesPerPixel      // * 16 bytes
                memcpy(buffer2Pointer + offset0, &pixel, bytesPerPixel)  // write 16 bytes
                row += bitmapHeight
                let offset1 = (row * bitmapWidth + i) * bytesPerPixel      // * 16 bytes
                memcpy(buffer2Pointer + offset1, &pixel, bytesPerPixel)  // write 16 bytes
                
            }
            var pixel : [Float] = [Float(j), 0.0, 0.0, 0.0]
            let top = ((2 * bitmapHeight) * bitmapWidth) * bytesPerPixel
            memcpy(buffer2Pointer + top, &pixel, bytesPerPixel)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        enable = !enable
    }
    
    public override func draw(_ rect: CGRect) {
        if enable {
            computeShader()
            frameCount += 1
            performSelector(onMainThread: #selector(updateBitmap), with: nil, waitUntilDone: false)
        }
    }

}
