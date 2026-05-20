import Foundation
import Network

public enum FramingError: Error {
    case messageTooLarge(Int)
    case truncated
    case invalidLength
}

public struct LengthPrefixedFraming {
    public init() {}

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let body = try encoder.encode(value)
        guard body.count <= HealthSyncService.maxMessageBytes else {
            throw FramingError.messageTooLarge(body.count)
        }
        var length = UInt32(body.count).bigEndian
        var data = Data(capacity: 4 + body.count)
        withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
        data.append(body)
        return data
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}

public actor FrameReader {
    private var buffer = Data()
    private let framing = LengthPrefixedFraming()

    public init() {}

    public func append(_ chunk: Data) {
        buffer.append(chunk)
    }

    public func nextFrame() throws -> Data? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer.prefix(4).withUnsafeBytes { raw -> UInt32 in
            raw.load(as: UInt32.self)
        }.bigEndian
        guard length <= UInt32(HealthSyncService.maxMessageBytes) else {
            throw FramingError.invalidLength
        }
        let total = 4 + Int(length)
        guard buffer.count >= total else { return nil }
        let body = buffer.subdata(in: 4..<total)
        buffer.removeSubrange(0..<total)
        return body
    }

    public func decodeAll<T: Decodable>(_ type: T.Type) throws -> [T] {
        var results: [T] = []
        while let frame = try nextFrame() {
            results.append(try framing.decode(type, from: frame))
        }
        return results
    }
}
