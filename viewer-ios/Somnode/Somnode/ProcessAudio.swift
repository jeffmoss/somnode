//
//  ProcessAudio.swift
//  Somnode
//
//  Created by Jeff Moss on 3/28/18.
//  Copyright © 2018 Jeff Moss. All rights reserved.
//

import Foundation
import Accelerate

let fftLen = 8 * bitmapWidth
fileprivate var fftSetup : FFTSetup? = nil
fileprivate var auBWindow = [Float](repeating: 1.0, count: 32768)

var minx : Float =  1.0e12
var maxx : Float = -1.0e12

@objc public class ProcessAudio: NSObject {
    static func doFFT_OnAudioBuffer(_ audioObject : RecordAudio) -> ([Float]) {
        
        let log2N = UInt(round(log2f(Float(fftLen))))
        var output = [Float](repeating: 0.0, count: fftLen)
        
    //    guard let myAudio = globalAudioRecorder
    //        else { return output }
    //
        if fftSetup == nil {
            fftSetup = vDSP_create_fftsetup(log2N, FFTRadix(kFFTRadix2))
            vDSP_blkman_window(&auBWindow, vDSP_Length(fftLen), 0)
        }
        
        var fcAudioU0 = [Float](repeating: 0.0, count: fftLen)
        var fcAudioV0 = [Float](repeating: 0.0, count: fftLen)
    //    var i = myAudio.circInIdx - 2 * fftLen
        var i = audioObject.circInIdx - 2 * fftLen
        if i < 0 { i += circBuffSize }
        for j in 0 ..< fftLen {
            if i < 0 {
                gTmp0 = 0
            }
            if i >= circBuffSize {
                gTmp0 = 0
            }
            fcAudioU0[j] = audioObject.circBuffer[i]
            i += 2 ; if i >= circBuffSize { i -= circBuffSize } // circular buffer
        }
        
        vDSP_vmul(fcAudioU0, 1, auBWindow, 1, &fcAudioU0, 1, vDSP_Length(fftLen/2))
        
        var fcAudioUV = DSPSplitComplex(realp: &fcAudioU0,  imagp: &fcAudioV0 )
        vDSP_fft_zip(fftSetup!, &fcAudioUV, 1, log2N, Int32(FFT_FORWARD)); //  FFT()
        
        var tmpAuSpectrum = [Float](repeating: 0.0, count: fftLen)
        vDSP_zvmags(&fcAudioUV, 1, &tmpAuSpectrum, 1, vDSP_Length(fftLen/2))  // abs()
        
        var scale = 1024.0 / Float(fftLen)
        vDSP_vsmul(&tmpAuSpectrum, 1, &scale, &output, 1, vDSP_Length(fftLen/2))
        
        return (output)
    }

    static func makeSpectrumFromAudio(_ audioObject: RecordAudio) {
        
        var magnitudeArray = doFFT_OnAudioBuffer(audioObject)
        
        for i in 0 ..< bitmapWidth {
            if i < magnitudeArray.count {
                var x = (1024.0 + 64.0 * Float(i)) * magnitudeArray[i]
                if x > maxx { maxx = x }
                if x < minx { minx = x }
                var y : Float = 0.0
                if (x > minx) {
                    if (x < 1.0) { x = 1.0 }
                    let r = (logf(maxx - minx) - logf(1.0)) * 1.0
                    let u = (logf(x    - minx) - logf(1.0))
                    y = u / r
                }
                spectrumArray[i] = y
            }
        }
    }
}
