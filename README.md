# Somnode Firmware for ESP32 architecture

This repository contains ESP32 firmware with support for LIS3DH accellerometer and the SPH0645 MEMS microphone.

This code is meant to function as a digital stethoscope, connected to an iPhone for signal processing.

## Supporting apps

### viewer-ios

An iOS app to stream audio and accelerometer data and running signal processing code. (FFT)

### audio-segmentation

A python script that performs audio feature extraction.

## Next Steps

* Implement audio-segmentation algorithm from audio-segmentation into viewer-ios in Objective-C.

## License (MIT)

Copyright 2018 Jeff Moss

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
