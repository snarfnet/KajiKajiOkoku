import Vision
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct BackgroundRemover {
    static func removeBackground(from image: UIImage) async -> UIImage? {
        guard let cgImage = image.cgImage else { return image }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let result = request.results?.first else { return image }
            let maskBuffer = try result.generateScaledMaskForImage(
                forInstances: result.allInstances, from: handler
            )
            return applyMask(maskBuffer, to: cgImage, orientation: image.imageOrientation)
        } catch {
            print("BackgroundRemover error:", error)
            return image
        }
    }

    private static func applyMask(
        _ mask: CVPixelBuffer,
        to cgImage: CGImage,
        orientation: UIImage.Orientation
    ) -> UIImage? {
        let ciInput = CIImage(cgImage: cgImage)
        let ciMask = CIImage(cvPixelBuffer: mask)

        let filter = CIFilter.blendWithMask()
        filter.inputImage = ciInput
        filter.backgroundImage = CIImage.empty()
        filter.maskImage = ciMask

        let context = CIContext()
        guard let output = filter.outputImage,
              let result = context.createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: result, scale: 1.0, orientation: orientation)
    }
}
