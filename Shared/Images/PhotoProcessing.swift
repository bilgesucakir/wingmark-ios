import CoreLocation
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

struct PhotoMetadata: Equatable, Sendable {
    var coordinate: CLLocationCoordinate2D?
    var capturedAt: Date?

    static func == (lhs: PhotoMetadata, rhs: PhotoMetadata) -> Bool {
        lhs.capturedAt == rhs.capturedAt
            && lhs.coordinate?.latitude == rhs.coordinate?.latitude
            && lhs.coordinate?.longitude == rhs.coordinate?.longitude
    }
}

struct ProcessedPhoto: Sendable {
    let jpeg: Data
    let preview: UIImage
    let metadata: PhotoMetadata
}

nonisolated enum PhotoProcessing {
    static let maxPixelSize = 2048

    /// Reads EXIF on device (the server strips it), then re-encodes as a downscaled JPEG.
    static func process(_ data: Data) -> ProcessedPhoto? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let metadata = self.metadata(from: source)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return encode(UIImage(cgImage: cgImage), metadata: metadata)
    }

    static func process(_ image: UIImage, metadata: PhotoMetadata = PhotoMetadata()) -> ProcessedPhoto? {
        let longest = max(image.size.width, image.size.height) * image.scale
        guard longest > CGFloat(maxPixelSize) else { return encode(image, metadata: metadata) }
        let scale = CGFloat(maxPixelSize) / longest
        let size = CGSize(width: image.size.width * image.scale * scale, height: image.size.height * image.scale * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return encode(resized, metadata: metadata)
    }

    static func metadata(from source: CGImageSource) -> PhotoMetadata {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return PhotoMetadata()
        }
        var result = PhotoMetadata()
        if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
           let longitude = gps[kCGImagePropertyGPSLongitude] as? Double {
            let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String
            let lngRef = gps[kCGImagePropertyGPSLongitudeRef] as? String
            let coordinate = CLLocationCoordinate2D(
                latitude: latRef == "S" ? -latitude : latitude,
                longitude: lngRef == "W" ? -longitude : longitude
            )
            if CLLocationCoordinate2DIsValid(coordinate) { result.coordinate = coordinate }
        }
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            result.capturedAt = parseExifDate(original, offset: exif[kCGImagePropertyExifOffsetTimeOriginal] as? String)
        }
        return result
    }

    /// EXIF dates look like `2026:09:30 14:05:11`, with the zone in a separate `+03:00` field (else device time).
    static func parseExifDate(_ value: String, offset: String?) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = offset == nil ? "yyyy:MM:dd HH:mm:ss" : "yyyy:MM:dd HH:mm:ssZZZZZ"
        formatter.timeZone = .current
        return formatter.date(from: value + (offset ?? ""))
    }

    private static func encode(_ image: UIImage, metadata: PhotoMetadata) -> ProcessedPhoto? {
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return nil }
        return ProcessedPhoto(jpeg: jpeg, preview: image, metadata: metadata)
    }
}
