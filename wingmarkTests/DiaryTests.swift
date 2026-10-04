import CoreLocation
import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import wingmark

enum DiaryFixtures {
    static func logJSON(id: String, observedAt: String, speciesId: String? = nil, gender: String = "UNKNOWN") -> String {
        """
        {"id":"\(id)","userId":"3f2504e0-4f89-11d3-9a0c-0305e82c3301",
         "speciesId":\(speciesId.map { "\"\($0)\"" } ?? "null"),"speciesCommonName":\(speciesId == nil ? "null" : "\"Kızılgerdan\""),
         "speciesStatus":\(speciesId == nil ? "null" : "\"CONFIDENT\""),"pet":false,"customName":null,
         "lifeStage":"ADULT","gender":"\(gender)","photoUrl":"/uploads/a.jpg","note":null,
         "latitude":41.01,"longitude":28.97,"locationName":"Kadıköy","observedAt":"\(observedAt)",
         "visibility":"PRIVATE","createdAt":"2026-09-30T08:00:00.123456789Z"}
        """
    }
}

@MainActor
struct BirdLogCodingTests {
    @Test func decodesBackendLog() throws {
        let json = DiaryFixtures.logJSON(
            id: "11111111-1111-1111-1111-111111111111", observedAt: "2026-09-29T07:30:00Z",
            speciesId: "a1cafd6d-cc70-4c13-9439-d9ab987fb30e"
        )
        let log = try JSONCoding.makeDecoder().decode(BirdLog.self, from: Data(json.utf8))
        #expect(log.displayName == "Kızılgerdan")
        #expect(log.speciesStatus == .confident)
        #expect(log.photoUrl == "/uploads/a.jpg")
    }

    @Test func unidentifiedLogHasFallbackName() throws {
        let json = DiaryFixtures.logJSON(id: "11111111-1111-1111-1111-111111111111", observedAt: "2026-09-29T07:30:00Z")
        let log = try JSONCoding.makeDecoder().decode(BirdLog.self, from: Data(json.utf8))
        #expect(log.speciesId == nil)
        #expect(!log.displayName.isEmpty)
    }

    @Test func inputOmitsObservedAtWhenNilAndDropsStatusWithoutSpecies() throws {
        let input = BirdLogInput(speciesId: nil, speciesStatus: .guess, latitude: 1, longitude: 2, observedAt: nil)
        let object = try #require(JSONSerialization.jsonObject(with: JSONCoding.makeEncoder().encode(input)) as? [String: Any])
        #expect(object["observedAt"] == nil)
        #expect(object["speciesStatus"] is NSNull)
        #expect(object["speciesId"] is NSNull)
        #expect(object["lifeStage"] as? String == "UNKNOWN")
        #expect(object["latitude"] as? Double == 1)
    }

    @Test func inputEncodesObservedAtAsISO8601() throws {
        let date = try #require(JSONCoding.parseDate("2026-09-29T07:30:00Z"))
        let input = BirdLogInput(speciesId: UUID(), speciesStatus: .guess, latitude: 1, longitude: 2, observedAt: date)
        let object = try #require(JSONSerialization.jsonObject(with: JSONCoding.makeEncoder().encode(input)) as? [String: Any])
        #expect(object["observedAt"] as? String == "2026-09-29T07:30:00Z")
        #expect(object["speciesStatus"] as? String == "GUESS")
    }

    @Test func filterQueryItems() {
        var filter = DiaryFilter()
        #expect(filter.queryItems.isEmpty)
        filter.identification = .unidentified
        filter.gender = .female
        filter.lifeStage = .baby
        #expect(filter.queryItems == [
            URLQueryItem(name: "hasSpecies", value: "false"),
            URLQueryItem(name: "gender", value: "FEMALE"),
            URLQueryItem(name: "lifeStage", value: "BABY"),
        ])
    }

    @Test func speciesDecodesLocalizedNames() throws {
        let json = #"{"id":"a1cafd6d-cc70-4c13-9439-d9ab987fb30e","commonName":{"en":"European Robin","tr":"Kızılgerdan"},"scientificName":"Erithacus rubecula","family":null,"order":null,"description":{"en":"Small bird"},"lifespan":null,"diet":null,"habitat":null,"sizeDescription":null,"conservationStatus":null,"nativeRange":null,"images":[]}"#
        let species = try JSONCoding.makeDecoder().decode(Species.self, from: Data(json.utf8))
        #expect(species.commonName.resolved("tr") == "Kızılgerdan")
        #expect(species.description?.resolved("tr") == "Small bird")
    }

    @Test func uploadIsMultipartWithFilePart() throws {
        let endpoint = UploadAPI.photo(jpeg: Data([0xFF, 0xD8, 0xFF]))
        guard case .raw(let body, let contentType) = endpoint.body else {
            Issue.record("Expected a raw body")
            return
        }
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))
        let text = String(decoding: body, as: UTF8.self)
        #expect(text.contains(#"name="file"; filename="photo.jpg""#))
        #expect(text.contains("Content-Type: image/jpeg"))
    }
}

@MainActor
struct PhotoProcessingTests {
    private func jpegWithMetadata(latitude: Double, longitude: Double, date: String, offset: String?) throws -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4000, height: 3000)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4000, height: 3000))
        }
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        var exif: [CFString: Any] = [kCGImagePropertyExifDateTimeOriginal: date]
        if let offset { exif[kCGImagePropertyExifOffsetTimeOriginal] = offset }
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: abs(latitude),
                kCGImagePropertyGPSLatitudeRef: latitude < 0 ? "S" : "N",
                kCGImagePropertyGPSLongitude: abs(longitude),
                kCGImagePropertyGPSLongitudeRef: longitude < 0 ? "W" : "E",
            ],
            kCGImagePropertyExifDictionary: exif,
        ]
        CGImageDestinationAddImage(destination, try #require(image.cgImage), properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func readsGPSAndDateThenDownscales() throws {
        let data = try jpegWithMetadata(latitude: -33.86, longitude: -151.2, date: "2026:09:28 14:05:11", offset: "+03:00")
        let processed = try #require(PhotoProcessing.process(data))

        let coordinate = try #require(processed.metadata.coordinate)
        #expect(abs(coordinate.latitude - -33.86) < 0.0001)
        #expect(abs(coordinate.longitude - -151.2) < 0.0001)
        #expect(processed.metadata.capturedAt == JSONCoding.parseDate("2026-09-28T11:05:11Z"))

        let source = try #require(CGImageSourceCreateWithData(processed.jpeg as CFData, nil))
        let props = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(props[kCGImagePropertyPixelWidth] as? Int == 2048)
        #expect(CGImageSourceGetType(source) as String? == UTType.jpeg.identifier)
    }

    @Test func missingMetadataIsEmpty() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }
        let processed = try #require(PhotoProcessing.process(image))
        #expect(processed.metadata == PhotoMetadata())
    }
}

@MainActor
struct DiaryStoreTests {
    private func makeStore(
        handler: @escaping (URLRequest) async throws -> MockTransport.Reply
    ) async -> (DiaryStore, MockTransport) {
        let transport = MockTransport(handler: handler)
        let client = APIClient(
            baseURL: URL(string: "https://api.test")!, tokenStore: InMemoryTokenStore(Fixtures.tokens("a")),
            transport: transport
        )
        let session = AuthSession(client: client)
        await session.restore()
        return (DiaryStore(session: session), transport)
    }

    @Test func loadsWithFilterAndSort() async throws {
        let (store, transport) = await makeStore { request in
            if request.url?.path.hasPrefix("/api/users") == true { return .init(status: 200, body: Fixtures.userJSON) }
            return .init(status: 200, body: "[\(DiaryFixtures.logJSON(id: "11111111-1111-1111-1111-111111111111", observedAt: "2026-09-29T07:30:00Z"))]")
        }
        await store.load()

        #expect(store.logs.count == 1)
        #expect(store.hasLoaded)
        let url = try #require(transport.requests.last?.url)
        #expect(url.path == "/api/bird-logs/user/3f2504e0-4f89-11d3-9a0c-0305e82c3301")
        #expect(url.query?.contains("sortDirection=DESC") == true)
    }

    @Test func saveUploadsPhotoThenCreates() async throws {
        let created = DiaryFixtures.logJSON(id: "22222222-2222-2222-2222-222222222222", observedAt: "2026-09-29T09:00:00Z")
        let (store, transport) = await makeStore { request in
            switch request.url?.path {
            case "/api/uploads/photo": return .init(status: 201, body: #"{"url":"/uploads/new.jpg"}"#)
            case "/api/bird-logs": return .init(status: 201, body: created)
            default: return .init(status: 200, body: Fixtures.userJSON)
            }
        }
        let photo = try #require(PhotoProcessing.process(UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }))

        _ = try await store.save(BirdLogInput(latitude: 41, longitude: 29), editing: nil, newPhoto: photo)

        let createBody = try #require(transport.requests(to: "/api/bird-logs").first?.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: createBody) as? [String: Any])
        #expect(object["photoUrl"] as? String == "/uploads/new.jpg")
        #expect(store.logs.map(\.id) == [UUID(uuidString: "22222222-2222-2222-2222-222222222222")])
        #expect(store.revision == 1)
    }

    @Test func savedLogOutsideFilterIsNotListed() async throws {
        let created = DiaryFixtures.logJSON(id: "22222222-2222-2222-2222-222222222222", observedAt: "2026-09-29T09:00:00Z", gender: "MALE")
        let (store, _) = await makeStore { request in
            request.url?.path == "/api/bird-logs" ? .init(status: 201, body: created) : .init(status: 200, body: "[]")
        }
        store.filter.gender = .female
        _ = try await store.save(BirdLogInput(latitude: 41, longitude: 29), editing: nil, newPhoto: nil)
        #expect(store.logs.isEmpty)
    }

    @Test func deleteTreatsNotFoundAsDeleted() async throws {
        let id = "11111111-1111-1111-1111-111111111111"
        let (store, _) = await makeStore { request in
            switch request.httpMethod {
            case "DELETE": return Fixtures.error(status: 404, code: "NOT_FOUND")
            default:
                return request.url?.path.hasPrefix("/api/users") == true
                    ? .init(status: 200, body: Fixtures.userJSON)
                    : .init(status: 200, body: "[\(DiaryFixtures.logJSON(id: id, observedAt: "2026-09-29T07:30:00Z"))]")
            }
        }
        await store.load()
        let log = try #require(store.logs.first)

        try await store.delete(log)

        #expect(store.logs.isEmpty)
    }
}

@MainActor
struct LegacyBirdLogTests {
    @Test func toleratesNullDatesCoordinatesAndEnums() throws {
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","userId":"3f2504e0-4f89-11d3-9a0c-0305e82c3301","speciesId":null,"speciesCommonName":null,"speciesStatus":null,"pet":false,"customName":null,"lifeStage":null,"gender":null,"photoUrl":null,"note":null,"latitude":null,"longitude":null,"locationName":null,"observedAt":null,"visibility":"PRIVATE","createdAt":"2026-09-01T10:00:00Z"}"#
        let log = try JSONCoding.makeDecoder().decode(BirdLog.self, from: Data(json.utf8))
        #expect(log.observedAt == JSONCoding.parseDate("2026-09-01T10:00:00Z"))
        #expect(!log.hasLocation)
        #expect(log.lifeStage == .unknown && log.gender == .unknown)
    }

    @Test func toleratesNullCreatedAt() throws {
        let json = DiaryFixtures.logJSON(id: "11111111-1111-1111-1111-111111111111", observedAt: "2026-09-29T07:30:00Z")
            .replacingOccurrences(of: #""createdAt":"2026-09-30T08:00:00.123456789Z""#, with: #""createdAt":null"#)
        let log = try JSONCoding.makeDecoder().decode(BirdLog.self, from: Data(json.utf8))
        #expect(log.createdAt == log.observedAt)
        #expect(log.hasLocation)
    }
}

@MainActor
struct TraitTests {
    @Test func summaryHidesUnknownValues() throws {
        var log = try JSONCoding.makeDecoder().decode(BirdLog.self, from: Data(
            DiaryFixtures.logJSON(id: "11111111-1111-1111-1111-111111111111", observedAt: "2026-09-29T07:30:00Z", gender: "FEMALE").utf8
        ))
        #expect(log.traitsSummary == "\(LifeStage.adult.title) · \(Gender.female.title)")
        log.gender = .unknown
        #expect(log.traitsSummary == LifeStage.adult.title)
        log.lifeStage = .unknown
        #expect(log.traitsSummary == nil)
    }

    @Test func speciesImageNotApplicableGenderIsHidden() throws {
        let image = try JSONCoding.makeDecoder().decode(SpeciesImage.self, from: Data(
            #"{"id":"00000000-0000-0000-0000-000000000001","lifeStage":"BABY","gender":"NOT_APPLICABLE","imageUrl":"https://x/y.jpg","caption":null}"#.utf8
        ))
        #expect(image.lifeStageValue == .baby)
        #expect(image.genderValue == nil)
    }
}
