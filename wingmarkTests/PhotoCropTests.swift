import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import wingmark

struct CropGeometryTests {
    private let frame = CGRect(x: 100, y: 100, width: 200, height: 100)

    @Test func cornersWinOverEdgesAndEdgesOverTheInside() {
        #expect(CropGeometry.hitTest(CGPoint(x: 102, y: 98), rect: frame) == .topLeft)
        #expect(CropGeometry.hitTest(CGPoint(x: 298, y: 202), rect: frame) == .bottomRight)
        #expect(CropGeometry.hitTest(CGPoint(x: 200, y: 101), rect: frame) == .top)
        #expect(CropGeometry.hitTest(CGPoint(x: 299, y: 150), rect: frame) == .right)
        #expect(CropGeometry.hitTest(CGPoint(x: 200, y: 150), rect: frame) == .move)
        #expect(CropGeometry.hitTest(CGPoint(x: 10, y: 10), rect: frame) == nil)
    }

    @Test func movingKeepsTheSizeAndStaysInsideThePhoto() {
        let start = CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.4)
        let moved = CropGeometry.drag(.move, from: start, by: CGSize(width: 0.1, height: 0.1))
        #expect(abs(moved.minX - 0.3) < 0.0001 && abs(moved.minY - 0.3) < 0.0001)
        #expect(moved.width == 0.5 && moved.height == 0.4)
        let pushed = CropGeometry.drag(.move, from: start, by: CGSize(width: 5, height: -5))
        #expect(abs(pushed.minX - 0.5) < 0.0001 && pushed.minY == 0)
    }

    @Test func anEdgeChangesOnlyItsOwnSideAndAnyRatioIsAllowed() {
        let start = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        let result = CropGeometry.drag(.right, from: start, by: CGSize(width: -0.3, height: 0.2))
        #expect(abs(result.minX - 0.1) < 0.0001 && abs(result.maxX - 0.6) < 0.0001)
        #expect(abs(result.minY - 0.1) < 0.0001 && abs(result.maxY - 0.9) < 0.0001)
    }

    @Test func aCornerChangesTwoSides() {
        let start = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        let result = CropGeometry.drag(.topLeft, from: start, by: CGSize(width: 0.2, height: 0.3))
        #expect(abs(result.minX - 0.3) < 0.0001 && abs(result.minY - 0.4) < 0.0001)
        #expect(abs(result.maxX - 0.9) < 0.0001 && abs(result.maxY - 0.9) < 0.0001)
    }

    @Test func theFrameCantGoBelowTheMinimumOrOutsideThePhoto() {
        let start = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        let squeezed = CropGeometry.drag(.right, from: start, by: CGSize(width: -5, height: 0))
        #expect(abs(squeezed.width - CropGeometry.minSide) < 0.0001)
        let pulled = CropGeometry.drag(.topLeft, from: start, by: CGSize(width: -5, height: -5))
        #expect(pulled.minX == 0 && pulled.minY == 0)
        let stretched = CropGeometry.drag(.bottomRight, from: start, by: CGSize(width: 5, height: 5))
        #expect(stretched.maxX == 1 && stretched.maxY == 1)
    }

    @Test func recognisesTheWholePhoto() {
        #expect(CropGeometry.isFull(CropGeometry.full))
        #expect(!CropGeometry.isFull(CGRect(x: 0, y: 0, width: 0.9, height: 1)))
    }
}

struct PhotoCropTests {
    private func photo(width: CGFloat, height: CGFloat) -> ProcessedPhoto {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
            UIColor.blue.setFill()
            context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))
        }
        let metadata = PhotoMetadata(coordinate: .init(latitude: 41, longitude: 29), capturedAt: Date(timeIntervalSince1970: 1_000))
        return PhotoProcessing.process(image, metadata: metadata)!
    }

    /// Reads one pixel by drawing the image into a known RGBA layout, so the byte order of the source doesn't matter.
    private func pixelColor(_ image: UIImage, x: Int, y: Int) -> (r: Int, b: Int) {
        let cg = image.cgImage!
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(cg, in: CGRect(x: -x, y: -(cg.height - 1 - y), width: cg.width, height: cg.height))
        return (Int(pixel[0]), Int(pixel[2]))
    }

    @Test func cropsAnyRatioAndKeepsOnlyThatPart() throws {
        let original = photo(width: 200, height: 100)
        let cropped = try #require(PhotoProcessing.crop(original, to: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)))
        #expect(cropped.preview.size == CGSize(width: 100, height: 50))
        let decoded = try #require(UIImage(data: cropped.jpeg))
        #expect(decoded.size == CGSize(width: 100, height: 50))
        let color = pixelColor(cropped.preview, x: 50, y: 25)
        #expect(color.b > 200 && color.r < 60)
    }

    @Test func keepsTheDateAndPlaceOfThePhoto() throws {
        let original = photo(width: 100, height: 100)
        let cropped = try #require(PhotoProcessing.crop(original, to: CGRect(x: 0, y: 0, width: 0.5, height: 1)))
        #expect(cropped.metadata == original.metadata)
    }

    @Test func croppingAgainStartsFromTheWholePhoto() throws {
        let original = photo(width: 200, height: 100)
        let first = try #require(PhotoProcessing.crop(original, to: CGRect(x: 0, y: 0, width: 0.25, height: 1)))
        let again = try #require(PhotoProcessing.crop(original, to: CGRect(x: 0, y: 0, width: 0.75, height: 1)))
        #expect(first.preview.size.width == 50)
        #expect(again.preview.size.width == 150)
    }

    @Test func aFrameOutsideThePhotoGivesNothing() {
        let original = photo(width: 100, height: 100)
        #expect(PhotoProcessing.crop(original, to: CGRect(x: 2, y: 2, width: 0.5, height: 0.5)) == nil)
    }
}
