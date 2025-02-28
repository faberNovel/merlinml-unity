//
//  FaceShapeStaticFramework.swift
//  FaceShapeStaticFramework
//
//  Created by Anil Karagoz on 21/02/2025.
//

import Foundation
import CoreML
import UIKit

// MARK: - MerlinML Framework

class MerlinML {
    static var model: Merlin?
    
    static func loadModel() {
        do {
            // Try to find the model using various approaches
            if let modelURL = Bundle.main.url(forResource: "Merlin", withExtension: "mlmodelc") {
                // Standard .mlmodel compiled path
                let config = MLModelConfiguration()
                model = try Merlin(contentsOf: modelURL, configuration: config)
                print("MerlinML: Model loaded from .mlmodelc")
            } else if let modelURL = Bundle.main.url(forResource: "Merlin", withExtension: "mlpackage") {
                // For .mlpackage files
                let config = MLModelConfiguration()
                model = try Merlin(contentsOf: modelURL, configuration: config)
                print("MerlinML: Model loaded from .mlpackage")
            } else {
                // Attempt to use the default initializer as fallback
                let config = MLModelConfiguration()
                model = try Merlin(configuration: config)
                print("MerlinML: Model loaded using default initializer")
            }
        } catch {
            print("MerlinML: Error loading model: \(error)")
        }
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    func resized(to newSize: CGSize, scale: CGFloat = 1) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let image = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
        return image
    }
    
    func normalized() -> [Float32]? {
        guard let cgImage = self.cgImage else { return nil }
        
        let w = cgImage.width
        let h = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * w
        let bitsPerComponent = 8
        
        var rawBytes: [UInt8] = [UInt8](repeating: 0, count: w * h * 4)
        
        rawBytes.withUnsafeMutableBytes { ptr in
            if let cgImage = self.cgImage,
               let context = CGContext(data: ptr.baseAddress,
                                     width: w,
                                     height: h,
                                     bitsPerComponent: bitsPerComponent,
                                     bytesPerRow: bytesPerRow,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                let rect = CGRect(x: 0, y: 0, width: w, height: h)
                context.draw(cgImage, in: rect)
            }
        }
        
        var normalizedBuffer: [Float32] = [Float32](repeating: 0, count: w * h * 3)
        
        for i in 0 ..< w * h {
            // Apply ImageNet normalization
            normalizedBuffer[i] = (Float32(rawBytes[i * 4 + 0]) / 255.0 - 0.485) / 0.229 // R
            normalizedBuffer[w * h + i] = (Float32(rawBytes[i * 4 + 1]) / 255.0 - 0.456) / 0.224 // G
            normalizedBuffer[w * h * 2 + i] = (Float32(rawBytes[i * 4 + 2]) / 255.0 - 0.406) / 0.225 // B
        }
        
        return normalizedBuffer
    }
    
    func preprocessedForInference(width: Int = 224, height: Int = 224) -> MLMultiArray? {
        // 1. Resize image
        let resizedImage = self.resized(to: CGSize(width: width, height: height))
        
        // 2. Get normalized values
        guard let normalizedBuffer = resizedImage.normalized() else { return nil }
        
        // 3. Create MLMultiArray
        let shape: [NSNumber] = [NSNumber(value: 1), NSNumber(value: 3),
                                NSNumber(value: height), NSNumber(value: width)]
        guard let mlArray = try? MLMultiArray(shape: shape, dataType: .float32) else { return nil }
        
        // 4. Copy normalized values to MLMultiArray
        for i in 0..<normalizedBuffer.count {
            mlArray[i] = NSNumber(value: normalizedBuffer[i])
        }
        
        return mlArray
    }
}

// MARK: - C Interface

@_cdecl("MerlinML_loadModel")
public func MerlinML_loadModel() {
    MerlinML.loadModel()
}

@_cdecl("MerlinML_processImage")
public func MerlinML_processImage(bytes: UnsafePointer<UInt8>?, length: Int, results: UnsafeMutablePointer<Float>) -> Bool {
    guard let bytes = bytes else { return false }
    let data = Data(bytes: bytes, count: length)
    
    guard let model = MerlinML.model else {
        print("MerlinML: Model not loaded")
        return false
    }
    
    guard let image = UIImage(data: data) else {
        print("MerlinML: Failed to create image from data")
        return false
    }
    
    do {
        let input = image.preprocessedForInference()!
        let modelInput = MerlinInput(x_1: input)
        let output = try model.prediction(input: modelInput)
        
        // Copy the 5 prediction values directly to the provided results array
        for i in 0..<5 {
            results[i] = output.var_2241[i].floatValue
        }
        
        return true
    } catch {
        print("MerlinML: Prediction error: \(error)")
        return false
    }
}
