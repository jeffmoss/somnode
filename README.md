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
